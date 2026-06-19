class WorkflowRunHeaderComponent < WorkflowRunRowComponent
  def initialize(workflow_run:, token_id:)
    super

    @workflow_run = workflow_run
  end

  def status_class
    case status
    when 'fail'
      'text-bg-danger'
    when 'success'
      'text-bg-primary'
    else
      'text-bg-warning'
    end
  end

  def event_source_link(label_prefix: nil)
    return 'Unknown source' if event_source_name.blank?

    label = "#{label_prefix}#{event_source_name}"
    return label if event_source_url.blank?

    link_to(label, event_source_url)
  end
end
