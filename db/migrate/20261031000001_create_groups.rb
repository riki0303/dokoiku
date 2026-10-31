class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups, &:timestamps
  end
end
