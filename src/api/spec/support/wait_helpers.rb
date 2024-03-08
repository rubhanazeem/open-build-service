# See https://thoughtbot.com/blog/automatically-wait-for-ajax-with-capybara
module WaitHelpers
  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until finished_all_ajax_requests?
    end
  end

  def wait_up_to(seconds)
    seconds_backup = Capybara.default_max_wait_time

    begin
      Capybara.default_max_wait_time = seconds
      yield
    ensure
      Capybara.default_max_wait_time = seconds_backup
    end
  end

  private

  def finished_all_ajax_requests?
    page.evaluate_script('jQuery.active').zero?
  end
end

RSpec.configure do |config|
  config.include WaitHelpers, type: :feature
end
