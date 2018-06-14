require 'sinatra'

class Events
  def initialize
    @events = Hash.new { |s, k| s[k] == [] }
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
  end

  def each(id, &block)
    @events[id].each(&block)
  end

  def materialize(&block)
    @listeners << block
  end
end

$EVENTS = Events.new
Result = Struct.new(:ok?, :error)


class Guest
  def initialize(id:)
    @id = id
    @site_opened = false
    @items = []
  end

  def apply(name:, params:)
    case name
    when :SiteOpened
      @site_opened = true
    when :ItemAdded
      @items << params[:item_id]
    end
  end

  def handle!(command:, params:)
    case command
    when :CartCheckout
      if @items.present?
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
      else
        Result.new(false, "Empty cart")
      end
    when :AddItem
      if @site_opened
        $EVENTS.emit!(name: :ItemAdded, aggregate_id: @id, params: {
                        guest_id: @id,
                        # TODO: Validate item exists
                        item_id: params.fetch(:item_id)
                      })
        Result.new(true, nil)
      else
        Result.new(false, "Guest haven't opened site yet.")
      end
    else
      raise RuntimeError, "#{self.class.name} can't handle #{command}"
    end
  end
end

def aggregate!(name, id)
  fresh = const_get(name).new(id)
  $EVENTS.each(id) { |event| fresh.apply(event[:name], event[:params]) }
  fresh
end

def dispatch(command:, params:)
  case command
  when :OpenSite
    $EVENTS.emit!(name: :SiteOpened, params: {
                    guest_id: params.fetch(:guest_id)
                  })
  when :AddItem
    guest_id = params.fetch(:guest_id)
    guest = aggregate!(:Guest, guest_id)
    guest.handle!(command: command, params: params)
  else
    Result.new(false, 'Unknown command')
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

  {
    status: result.ok?,
    error: result.error
  }
end

post '/guest/:guest_id' do
  guest_id = params[:guest_id]
  result = dispatch(
    command: :OpenSite,
    params: {
      guest_id: guest_id
    }
  )

  {
    status: result.ok?,
    error: result.error
  }
end

def query(query:, params:)
  DB[query].select(params)
end


$EVENTS.materialize do |name, aggregate_id, params|
  case name
  when :ItemAdded
    DB[:Cart].insert params.merge(guest_id: aggregate_id)
  end
end

get '/cart/:guest_id' do
  query!(
    query: :Cart,
    params: {
      guest_id: params.fetch(:guest_id)
    }
  )
end
