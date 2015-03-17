class DefaultStore
  def initialize
    @store = {}
  end

  def get(attr)
    @store[attr]
  end

  def set(attr, value)
    @store[attr] = value
  end
end
