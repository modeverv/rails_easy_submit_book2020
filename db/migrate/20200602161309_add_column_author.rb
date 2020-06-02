class AddColumnAuthor < ActiveRecord::Migration[6.0]
  def up
    add_column :posts, :author, :string
  end

  def down
    remove_column :posts, :author, :string
  end
end
