class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :verify_authorized, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_group

  protected

  # Group of the signed-in user; scopes places
  def current_group
    @current_group ||= current_user&.group
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end

  # Devise hook (called by Devise internally, not via routes)
  def after_sign_out_path_for(_scope) # rails_best_practices:disable RemoveUnusedMethodsInControllersCheck
    new_user_session_path
  end

  private

  # 認可エラーは「見つからない」扱いにし、存在しない ID を指定したときと同じ処理にする（他のグループのデータが存在するかどうかを推測させないため）。
  # 本番では public/404.html を 404 で返し、開発では元の Pundit::NotAuthorizedError が cause として見えるデバッグ画面になる
  def user_not_authorized
    raise ActiveRecord::RecordNotFound
  end
end
