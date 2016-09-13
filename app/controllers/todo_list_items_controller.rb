require 'date'
class TodoListItemsController < ApplicationController
	before_filter :authenticate_user!
	
	def index 
		unless user_signed_in?
			redirect_to new_user_session_path
		end
		@todo_list_items = current_user.todo_list_items
	end

	def new
		@todo_list_item = TodoListItem.new
	end

	def create
  	@todo_list_item = TodoListItem.new(todo_list_item_params)
		@todo_list_item.user = current_user
    if @todo_list_item.save
    	redirect_to todo_list_item_path(@todo_list_item)
    else
    	render 'new'
    end
	end

	def show
		@todo_list_item = TodoListItem.find(params[:id])
	end

	def edit
		@todo_list_item = TodoListItem.find(params[:id])
	end

	def update
	  @todo_list_item = TodoListItem.find(params[:id])
	 
	  if @todo_list_item.update(todo_list_item_params)
	    redirect_to @todo_list_item
	  else
	    render 'edit'
	  end
	end
	 
	def destroy
		@todo_list_item = TodoListItem.find(params[:id])
		@todo_list_item.destroy
		redirect_to todo_list_items_path
	end

	def tweet_for_me
		client = Twitter::REST::Client.new do |config|
		  config.consumer_key = Rails.application.config.twitter_key
		  config.consumer_secret =  Rails.application.config.twitter_secret
		  config.access_token = current_user.access_token
		  config.access_token_secret = current_user.access_token_secret
		end
		@tweet = client.update(params[:tweet_content])
		@todo_item = TodoListItem.new(user_id: current_user.id, title: "New twitter todo item-#{@tweet.id}", content: @tweet.full_text)
		if @todo_item.save
    	redirect_to @todo_item
  	else
    	redirect_to root_path, error: 'Your todo_item cannot be created.'
  	end
	end

	def search_items_by_date
		if params["start_date"].present? && params["end_date"].present?
			@redis_key = current_user.id.to_s+params["start_date"]+params["end_date"]
			@stored_data = $redis.smembers(@redis_key)
			if @stored_data.present? && !@stored_data.blank?
				@records = decorate_view_data(@stored_data, true)
			else
				@records = search_by_date(params["start_date"], params["end_date"], @redis_key)
			end	
			@todo_list_items = @records	
		else
			flash[:error] = "Please enter start and end dates to search items"
		end
		render "index"
	end

	def search_items_by_text
		if params["q"].present?
			@redis_key = current_user.id.to_s+params["q"]
			@stored_data = $redis.smembers(@redis_key)
			if @stored_data.present? && !@stored_data.blank?
				@records = decorate_view_data(@stored_data, true)
			else
				@records = search_by_text(params["q"], @redis_key)
			end
			@todo_list_items = @records
		else
			flash[:error] = "Please enter a keyword to search items"
		end
		render "index"
	end


	def search_by_date(start_date, end_date, redis_key)
		@results = elastic_search_by_date(start_date, end_date)
		if @results.present? && !@results.blank?
			$redis.sadd(redis_key, @results)
			$redis.expire(redis_key, 172800) #172800 seconds = 2 days
		end
		return decorate_view_data(@results, false)
	end

	def search_by_text(query, redis_key)
		@results = elastic_search_by_text(query)
		if @results.present? && !@results.blank?
			$redis.sadd(redis_key, @results)
			$redis.expire(redis_key, 172800) #172800 seconds = 2 days
		end
		return decorate_view_data(@results, false)
	end


	def decorate_view_data(todo_list_items_results, flag)
		@results = []
		todo_list_items_results.each do |search_item|
			if flag == true
				hash_item = eval(search_item)
			else
				hash_item = search_item
			end
			@results << TodoListItem.new(id: hash_item[:id], 
				title: hash_item[:title],
				content: hash_item[:content],
				deadline: hash_item[:deadline], 
		 		created_at: hash_item[:created_at]
		 		)
		end
		@results
	end


	def elastic_search_by_date(start_date, end_date)
		@results = []
		# DateTime formatting:
		@deadline_bottom = start_date.split(" ") #=> ["09/17/2016", "1:34", "PM"]
		@date_part_1_array = @deadline_bottom.first.split("/") #=> ["09", "17", "2016"]
		@date_part_1 = @date_part_1_array.last+"-"+@date_part_1_array.first+"-"+@date_part_1_array.second #=> "2016-09-17"
		@date_part_2 = "#{@deadline_bottom.second}:00" #=> "1:34:00"
		
		@deadline_format1 = DateTime.parse("#{@date_part_1} #{@date_part_2}")

		@deadline_top = end_date.split(" ") #=> ["09/17/2016", "1:34", "PM"]
		@date_part_1_array = @deadline_top.first.split("/") #=> ["09", "17", "2016"]
		@date_part_1 = @date_part_1_array.last+"-"+@date_part_1_array.first+"-"+@date_part_1_array.second #=> "2016-09-17"
		@date_part_2 = "#{@deadline_top.second}:00" #=> "1:34:00"
			
		@deadline_format2 = DateTime.parse("#{@date_part_1} #{@date_part_2}")

		@greater_than_equal_to = @deadline_format1.strftime("%Y/%m/%d %H:%M:%S")
		@less_than_equal_to = @deadline_format2.strftime("%Y/%m/%d %H:%M:%S")
		
		@todo_list_items_results =  TodoListItem.search(
			{
				filter: {
          bool: {
            must: [
              {
                term: {
                  user_id: current_user.id
                }
              },

              {
								range: {
									deadline: {
										gte: @greater_than_equal_to,
										lte: @less_than_equal_to,
										format: "yyyy/MM/dd HH:mm:SS"
									}
								}
              }
            ]
          }
				}
			}
		).results
		@todo_list_items_results.each do |search_item|
			@results << {id: search_item._source.id,
				title: search_item._source.title,
				content: search_item._source.content,
				deadline: search_item._source.deadline,
				created_at: search_item._source.created_at
			}
		end
		return @results
		

	end

	def elastic_search_by_text(query)
		@term = query
		@results = []
		@todo_list_items_results =  TodoListItem.search(
			{
				query: {
		      multi_match: {
	          query: @term,
	          fields: ['title', 'content']
	      	}
				},
				filter: {
	        term: {
	          user_id: current_user.id
	        }
	      }
			}
		).results
		@todo_list_items_results.each do |search_item|
			@results << {id: search_item._source.id,
				title: search_item._source.title,
				content: search_item._source.content,
				deadline: search_item._source.deadline,
				created_at: search_item._source.created_at
			}
		end
		return @results
	end


	private
  def todo_list_item_params
    params.require(:todo_list_item).permit(:title, :content, :deadline)
  end
end