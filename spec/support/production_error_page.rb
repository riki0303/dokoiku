# test 環境では consider_all_requests_local = true のため、例外時の本文がデバッグ画面になる。
# :production_error_page を付けた example だけ、本番と同じく public/*.html のエラーページを返すようにする
RSpec.configure do |config|
  config.around(:each, :production_error_page) do |example|
    env_config = Rails.application.env_config
    key = "action_dispatch.show_detailed_exceptions"
    had_key = env_config.key?(key)
    original = env_config[key]
    env_config[key] = false
    example.run
  ensure
    had_key ? env_config[key] = original : env_config.delete(key)
  end
end
