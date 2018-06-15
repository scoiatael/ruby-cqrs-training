class Result
  attr_reader :ok
  alias ok? ok

  def initialize(ok = true, inner = nil)
    @ok = ok
    @inner = inner
  end

  def error
    ok? ? nil : @inner
  end

  def value
    ok? ? @inner : nil
  end

  def to_json
    {
      status: (ok? ? 'ok' : 'error'),
      error: error,
      value: value
    }.to_json
  end

  def self.success(value = nil)
    new(true, value)
  end

  def self.failure(error)
    new(false, error)
  end
end
