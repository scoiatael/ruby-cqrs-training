require 'logger'
require_relative 'lib/result'
require_relative 'lib/events'

$LOGGER = Logger.new(STDERR)
$DB = Hash.new { |k, v| k[v] = [] }
$EVENTS = Events.new

class Shipping
  def self.start!(user_id, items)
    $LOGGER.info "Shipping #{items} to #{user_id}"

    Result.success(address: 'Privet Drive 7, London')
  end
end

class Guest
  def initialize(id:)
    @id = id
    @site_opened = false
    @items = []
  end

  def apply(name:, params:)
    $LOGGER.info "Applying #{name.inspect} to #{self.class.name}"
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
      return Result.failure('Site is not opened.') unless @site_opened
      return Result.failure('Empty cart') if @items.none?

      result = Shipping.start!(@id, @items)
      event = if result.ok?
                cart_checked_out(result.value[:address])
              else
                cart_checkout_failure
              end
      $EVENTS.emit!(**event)
      Result.success
    when :AddItem
      return Result.failure("Guest haven't opened site yet.") unless @site_opened
      $EVENTS.emit!(name: :ItemAdded, aggregate_id: @id, params: {
                      guest_id: @id,
                      # TODO: Validate item exists
                      item_id: params.fetch(:item_id)
                    })
      Result.success
    else
      raise RuntimeError, "#{self.class.name} can't handle #{command}"
    end
  end

  private

  def cart_checked_out(address)
    {
      name: :CartCheckedout, aggregate_id: @id, params: {
        items: @items,
        address: address
      }
    }
  end

  def cart_checkout_failure
    {
      name: :CartCheckoutFailed, aggregate_id: @id, params: {
        items: @items
      }
    }
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
  $LOGGER.info "Dispatching #{command}"
  case command
  when :AddItemForSale
    item_name = params.fetch(:name)
    $EVENTS.emit!(name: :ItemAddedForSale,
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

def query(query:, params:)
  {
    query => $DB[query].select { |row| params.all? { |k, v| row[k] == v } }
  }
end

$EVENTS.materialize do |name, aggregate_id, params|
  $LOGGER.info "Materializing #{name.inspect}"
  case name
  when :ItemAdded
    $DB[:Cart] << params.merge(guest_id: aggregate_id)
  when :ItemAddedForSale
    $DB[:Items] << params
  end
end

def dispatch!(*args)
  response = dispatch(*args)
  raise 'Response is nil' if response.nil?
  response.ok? || raise("dispatch failed for #{args.to_json}")
  response
rescue => e
  STDERR.puts "#{e.class.name} #{e.message}"
  e.backtrace.each { |l| STDERR.puts l }
  raise
end
