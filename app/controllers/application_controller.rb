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

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end

  # Devise hook (called by Devise internally, not via routes)
  def after_sign_out_path_for(_scope) # rails_best_practices:disable RemoveUnusedMethodsInControllersCheck
    new_user_session_path
  end

  private

  def user_not_authorized
    flash[:alert] = "この操作を行う権限がありません。"
    redirect_back_or_to root_path, status: :see_other
  end
end
