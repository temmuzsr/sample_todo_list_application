require 'elasticsearch/model'

class TodoListItem < ActiveRecord::Base
	belongs_to :user
	validates :title, presence: true

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  
end
