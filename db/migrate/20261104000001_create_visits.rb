class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      # 同じ場所に何度でも記録できるよう、place_id の index は unique にしない
      t.references :place, null: false, foreign_key: true
      t.date :visited_on, null: false
      t.boolean :want_again, null: false

      t.timestamps
    end
  end
end
