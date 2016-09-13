class AddUserIdToTodoListItems < ActiveRecord::Migration
  def change
    add_reference :todo_list_items, :user, index: true, foreign_key: true
  end
end
