class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  # 暫定: root_path が未定義のため fallback は "/" 固定。root を定義したら root_path に差し替える
  def user_not_authorized
    flash[:alert] = "この操作を行う権限がありません。"
    redirect_back_or_to "/", status: :see_other
  end
end
