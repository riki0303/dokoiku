RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      # ログイン後に Chrome のパスワード漏洩警告などが出ると、次のテストのクリックが効かなくなることがあるため止める
      options.add_preference("credentials_enable_service", false)
      options.add_preference("profile.password_manager_enabled", false)
      options.add_preference("profile.password_manager_leak_detection", false)
    end
  end
end
