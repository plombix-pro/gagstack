require "test_helper"

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 5

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900] do |options|
    options.add_argument("no-sandbox")
    options.add_argument("disable-dev-shm-usage")
    options.add_argument("disable-gpu")
  end

  def verification_url(token)
    server = Capybara.current_session.server
    "http://#{server.host}:#{server.port}/verify/#{token}"
  end

  def sign_in_as(user)
    visit new_session_path
    if page.has_no_css?("input[name='email_address']", wait: 0)
      Capybara.reset_sessions!
      visit new_session_path
    end
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    find("form[action='/session'] input[type='submit']").click
    assert_text user.username, wait: 3
  rescue Capybara::ExpectationNotMet
    puts "DEBUG: sign_in_as failed for #{user.email_address} (role=#{user.role})"
    puts "DEBUG: Current page: #{page.current_path}"
    puts "DEBUG: Page text: #{page.text[0..500]}"
    raise
  end

  def verify_age
    # Clear any leftover session from previous tests (cookies persist in Capybara)
    Capybara.reset_sessions!

    # Age verification sets session[:age_verified] via manual DOB method
    # We use the manual fallback since it doesn't need a camera
    visit new_age_verification_path
    # If already verified (session), we'll be redirected
    return if current_path == sign_up_path

    click_on "Or verify manually"

    year = Date.today.year - 25
    page.execute_script("var root = document.querySelector('[data-controller=\"age-verification\"]'); root.querySelector('[data-age-verification-target=\"day\"]').value = '15'; root.querySelector('[data-age-verification-target=\"month\"]').value = '1'; root.querySelector('[data-age-verification-target=\"year\"]').value = '#{year}';")

    page.execute_script("var root = document.querySelector('[data-controller=\"age-verification\"]'); root.querySelector('[data-action=\"age-verification#verifyManual\"]').click();")

    assert_text "Age verified"
    click_on "Continue to sign up"
    assert_current_path sign_up_path
  end
end

Capybara.configure do |config|
  config.default_driver = :selenium_headless
end
