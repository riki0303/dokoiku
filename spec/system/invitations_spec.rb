require "rails_helper"

RSpec.describe "Invitations", type: :system do
  let(:user) { create(:user) }

  before do
    sign_in user
    # headless Chrome ではクリップボードの読み書きに権限が要るため、テスト中のサーバーの origin に許可を与える
    page.driver.browser.execute_cdp(
      "Browser.grantPermissions",
      origin: Capybara.current_session.server.base_url,
      permissions: %w[clipboardReadWrite clipboardSanitizedWrite]
    )
  end

  # 発行と表示の流れは JavaScript を使わないため request spec で担保する。
  # ここではコピーボタン（Stimulus）だけを確認する。
  describe "コピー" do
    let(:invitation) { create(:invitation, inviter: user) }

    before { visit invitation_path(invitation) }

    it "コピーボタンを押すと、招待リンクがクリップボードに入り「コピーしました」になること", :aggregate_failures do
      click_button "コピー"

      expect(page).to have_button("コピーしました")
      clipboard = page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
      expect(clipboard).to eq("#{Capybara.current_session.server.base_url}#{invitation_acceptance_path(invitation.token)}")
    end
  end
end
