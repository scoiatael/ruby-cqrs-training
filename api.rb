require 'sinatra'
require_relative 'lib'

before do
  content_type :json
end

after do
  response.body = response.body.to_json
end

get '/cart/:guest_id' do
  query(
    query: :Cart,
    params: {
      guest_id: params.fetch(:guest_id)
    }
  )
end

get '/items' do
  query(
    query: :Items,
    params: {}
  )
end

post '/guest/:guest_id/cart/item/:item_id' do
  guest_id = params[:guest_id]
  item_id = params[:item_id]

  result = dispatch(
    command: :AddItem,
    params: {
      guest_id: guest_id,
      item_id: item_id
    }
  )
end

post '/guest/:guest_id' do
  guest_id = params[:guest_id]
  result = dispatch(
    command: :OpenSite,
    params: {
      guest_id: guest_id
    }
  )
end
