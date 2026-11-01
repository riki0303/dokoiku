class CreatePlaces < ActiveRecord::Migration[8.1]
  def change
    create_table :places do |t|
      t.references :group, null: false, foreign_key: true
      t.string :name, null: false
      t.string :note, null: false
      t.string :distance, null: false

      t.timestamps
    end
  end
end
