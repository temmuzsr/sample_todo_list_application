class CreateTodoListItems < ActiveRecord::Migration
  def change
    create_table :todo_list_items do |t|
      t.string :title
      t.text :content
      t.datetime :deadline

      t.timestamps null: false
    end
  end
end
