class AddColumnChangeKey < ActiveRecord::Migration[6.0]
  def up
    add_column :posts, :change_key, :string
  end

  def down
    remove_column :posts, :change_key, :string
  end
end
