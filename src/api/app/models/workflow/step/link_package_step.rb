# rubocop:disable Metrics/ClassLength
# This class will be refactored to use a ActiveModel::Validator
class Workflow
  module Step
    class LinkPackageStep
      include ActiveModel::Model

      validates :source_project_name, :source_package_name, presence: true

      attr_accessor :scm_extractor_payload, :step_instructions, :token

      # Overwriting the initializer is needed to set `with_indifferent_access`
      def initialize(scm_extractor_payload:, step_instructions:, token:)
        @step_instructions = step_instructions&.with_indifferent_access || {}
        @scm_extractor_payload = scm_extractor_payload&.with_indifferent_access || {}
        @token = token
      end

      def call(options = {})
        return unless valid?

        linked_package = find_or_create_linked_package

        # add_or_update_branch_request_file(package: linked_package)

        workflow_filters = options.fetch(:workflow_filters, {})
        create_or_update_subscriptions(linked_package, workflow_filters)

        workflow_repositories(target_project_name, workflow_filters).each do |repository|
          # TODO: Fix n+1 queries
          workflow_architectures(repository, workflow_filters).each do |architecture|
            # We cannot report multibuild flavors here... so they will be missing from the initial report
            SCMStatusReporter.new({ project: target_project_name, package: target_package_name, repository: repository.name, arch: architecture.name },
                                  scm_extractor_payload, @token.scm_token).call
          end
        end

        linked_package
      end

      def source_project_name
        step_instructions['source_project']
      end

      def source_package_name
        step_instructions['source_package']
      end

      def target_package_name
        return step_instructions['target_package'] if step_instructions['target_package'].present?

        source_package_name
      end

      def target_project_name
        "home:#{@token.user.login}:#{source_project_name}:PR-#{scm_extractor_payload[:pr_number]}"
      end

      private

      def target_package
        Package.find_by_project_and_name(target_project_name, target_package_name)
      end

      def target_project
        Project.find_by(name: target_project_name)
      end

      def source_package
        Package.find_by_project_and_name(source_project_name, source_package_name)
      end

      def create_project_and_package
        if target_project.nil?
          project = Project.create!(name: target_project_name)
          project.commit_user = User.session
          project.relationships.create!(user: User.session, role: Role.find_by_title('maintainer'))
          project.store
        end
        if target_package.nil?
          target_project.packages.create(name: target_package_name)
        end
      end

      def find_or_create_linked_package
        return target_package if WorkflowEventAndActionValidator.new(scm_extractor_payload: scm_extractor_payload).updated_pull_request? && target_package.present?

        create_project_and_package
        link
      end

      def remote_source?
        return true if Project.find_remote_project(source_project_name)

        false
      end

      def check_source_access
        return if remote_source?

        options = { use_source: false, follow_project_links: true, follow_multibuild: true }

        begin
          src_package = Package.get_by_project_and_name(source_project_name, source_package_name, options)
        rescue Package::UnknownObjectError
          raise BranchPackage::Errors::CanNotBranchPackageNotFound, "Package #{source_project_name}/#{source_package_name} not found, it could not be branched."
        end

        Pundit.authorize(@token.user, src_package, :create_branch?)
      end

      def link
        # request_data = { name: target_package.name, project: target_project.name, title: target_package.title, description: target_package.description }
        xml = Xmlhash.parse(target_package.render_xml)
        target_package.update_from_xml(xml)
        binding.pry
        Package.verify_file!(target_package, '_link', target_package.render_xml)

        path = "/source/#{target_project_name}/#{target_package_name}/_link?user=#{@token.user}"
        pass_to_backend(path)
        target_package.sources_changed(wait_for_update: '_link')
      end

      def add_or_update_branch_request_file(package:)
        branch_request_file = case scm_extractor_payload[:scm]
                              when 'github'
                                branch_request_content_github
                              when 'gitlab'
                                branch_request_content_gitlab
                              end

        package.save_file({ file: branch_request_file, filename: '_branch_request' })
      end

      def branch_request_content_github
        {
          # TODO: change to @scm_extractor_payload[:action]
          # when check_for_branch_request method in obs-service-tar_scm accepts other actions than 'opened'
          # https://github.com/openSUSE/obs-service-tar_scm/blob/2319f50e741e058ad599a6890ac5c710112d5e48/TarSCM/tasks.py#L145
          action: 'opened',
          pull_request: {
            head: {
              repo: { full_name: scm_extractor_payload[:source_repository_full_name] },
              sha: scm_extractor_payload[:commit_sha]
            }
          }
        }.to_json
      end

      def branch_request_content_gitlab
        { object_kind: scm_extractor_payload[:object_kind],
          project: { http_url: scm_extractor_payload[:http_url] },
          object_attributes: { source: { default_branch: scm_extractor_payload[:commit_sha] } } }.to_json
      end

      def create_or_update_subscriptions(linked_package, workflow_filters)
        ['Event::BuildFail', 'Event::BuildSuccess'].each do |build_event|
          subscription = EventSubscription.find_or_create_by!(eventtype: build_event,
                                                              receiver_role: 'reader', # We pass a valid value, but we don't need this.
                                                              user: @token.user,
                                                              channel: 'scm',
                                                              enabled: true,
                                                              token: @token,
                                                              package: linked_package)
          subscription.update!(payload: scm_extractor_payload.merge({ workflow_filters: workflow_filters }))
        end
      end

      # TODO: Move to a query object.
      def workflow_repositories(target_project_name, filters)
        repositories = Project.get_by_name(target_project_name).repositories
        return repositories if filters.blank?

        return repositories.where(name: filters[:repositories][:only]) if filters[:repositories][:only]

        return repositories.where.not(name: filters[:repositories][:ignore]) if filters[:repositories][:ignore]

        repositories
      end

      # TODO: Move to a query object.
      def workflow_architectures(repository, filters)
        architectures = repository.architectures
        return architectures if filters.blank?

        return architectures.where(name: filters[:architectures][:only]) if filters[:architectures][:only]

        return architectures.where.not(name: filters[:architectures][:ignore]) if filters[:architectures][:ignore]

        architectures
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
