require 'sinatra'
require 'pry'

class Events
  def initialize
    @events = Hash.new { |s, k| s[k] = [] }
    @listeners = []
  end

  def emit!(name:, aggregate_id:, params:)
    @events[aggregate_id] << {
      name: name,
      params: params
    }
    @listeners.each do |block|
      block.call(name, aggregate_id, params)
    end
    Result::SUCCESS
  end

  def each(id, &block)
    @events[id].each(&block)
  end

  def materialize(&block)
    @listeners << block
  end
end

class Shipping
  def self.start!(user_id, items)
    OpenStruct.new(ok?: true, address: 'Privet Drive 7, London')
  end
end

$DB = Hash.new { |k,v| k[v] = [] }
$EVENTS = Events.new
class Result < Struct.new(:ok?, :error)
  SUCCESS = new(true, nil)

  def to_json
    h = {}
    h[:status] = (ok? ? 'ok' : 'error')
    h[:error] = error if error
    h.to_json
  end

  def self.failure(error)
    new false, error
  end
end

class Guest
  def initialize(id:)
    @id = id
    @site_opened = false
    @items = []
  end

  def apply(name:, params:)
    puts "appling #{name.inspect} to #{self.class.name}"
    case name
    when :SiteOpened
      @site_opened = true
    when :ItemAdded
      @items << params[:item_id]
    end
  end

  def handle!(command:, params:)
    case command
    when :CheckoutCart
      if not @site_opened
        Result.failure("Site is not opened.")
      elsif @items.none?
        Result.failure("Empty cart")
      else
        result = Shipping.start!(@id, @items)
        if result.ok?
          $EVENTS.emit!(name: :CartCheckedout, aggregate_id: @id, params: {
                          items: @items,
                          address: result.address
                        })
        else
          $EVENTS.emit!(name: :CartCheckoutFailed, aggregate_id: @id, params: {
                          items: @items
                        })
        end
      end
    when :AddItem
      if @site_opened
        $EVENTS.emit!(name: :ItemAdded, aggregate_id: @id, params: {
                        guest_id: @id,
                        # TODO: Validate item exists
                        item_id: params.fetch(:item_id)
                      })
        Result::SUCCESS
      else
        Result.failure("Guest haven't opened site yet.")
      end
    else
      raise RuntimeError, "#{self.class.name} can't handle #{command}"
    end
  end
end

def aggregate!(name, id)
  fresh = Object.const_get(name).new(id: id)
  $EVENTS.each(id) do |event|
    fresh.apply(
      name: event[:name],
      params: event[:params]
    )
  end
  fresh
end

def dispatch(command:, params:)
  puts "dispatching #{command}"
  case command
  when :AddItemForSale
    item_name = params.fetch(:name)
    res = $EVENTS.emit!(name: :ItemAddedForSale,
                  aggregate_id: item_name, # this should be some kind of id
                  params: {name: item_name})
  when :OpenSite
    guest_id = params.fetch(:guest_id)
    $EVENTS.emit!(name: :SiteOpened,
                  aggregate_id: guest_id,
                  params: {
                    guest_id: guest_id
                  })
  when :AddItem, :CheckoutCart
    guest_id = params.fetch(:guest_id)
    guest = aggregate!(:Guest, guest_id)
    guest.handle!(command: command, params: params)
  else
    Result.failure('Unknown command')
  end
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

def query(query:, params:)
  {
    query => $DB[query].select { |row| params.all? { |k,v| row[k] == v } }
  }
end

$EVENTS.materialize do |name, aggregate_id, params|
  puts "materializing #{name.inspect}"
  case name
  when :ItemAdded
    $DB[:Cart] << params.merge(guest_id: aggregate_id)
  when :ItemAddedForSale
    $DB[:Items] << params
  end
end

get '/cart/:guest_id' do
  query(
    query: :Cart,
    params: {
      guest_id: params.fetch(:guest_id)
    }
  )
end

before do
  content_type :json
end

after do
  response.body = response.body.to_json
end

get '/items' do
  query(
    query: :Items,
    params: {}
  )
end

def dispatch!(*args)
  response = dispatch(*args)
  raise RuntimeError, 'response is nil' if response.nil?
  response.ok? || raise("dispatch failed for #{args.to_json}")
  response
rescue => e
  STDERR.puts "#{e.class.name} #{e.message}"
  e.backtrace.each { |l| STDERR.puts l }
  raise
end

dispatch!(command: :AddItemForSale, params: { name: 'Gameboy' })
dispatch!(command: :AddItemForSale, params: { name: 'AA Battery' })
dispatch!(command: :AddItemForSale, params: { name: 'Toothbrush' })
dispatch!(command: :OpenSite, params: { guest_id: 'Foobert' })
puts query(query: :Items, params: {})
puts query(query: :GuestCart, params: { guest_id: 'Foobert' })
dispatch!(command: :AddItem, params: { item_id: 'Gameboy', guest_id: 'Foobert' })
dispatch!(command: :AddItem, params: { item_id: 'AA Battery', guest_id: 'Foobert' })
dispatch!(command: :AddItem, params: { item_id: 'AA Battery', guest_id: 'Foobert' })
dispatch!(command: :CheckoutCart, params: { guest_id: 'Foobert' })

