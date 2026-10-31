class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      # user_id 単独の index は複合ユニーク index [:user_id, :group_id] で代替できるため作らない
      t.references :user, null: false, foreign_key: true, index: false
      t.references :group, null: false, foreign_key: true

      t.timestamps
    end
    add_index :memberships, [ :user_id, :group_id ], unique: true
  end
end
