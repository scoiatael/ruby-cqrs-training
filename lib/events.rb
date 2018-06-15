require_relative 'result'

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
    Result.success
  end

  def each(id, &block)
    @events[id].each(&block)
  end

  def materialize(&block)
    @listeners << block
  end
end
