class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :group, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      # 招待リンクの URL に入るランダムな文字列。リンクを開いたときにこれで招待を探すため一意にする
      t.string :token, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      # 参加に使われた日時（参加処理を作るまでは常に nil）。「1回使ったら無効」をこれで表す
      t.datetime :used_at

      t.timestamps
    end
  end
end
