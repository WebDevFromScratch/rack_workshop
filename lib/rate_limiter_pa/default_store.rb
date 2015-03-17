class DefaultStore
  def initialize
    @data = {}
  end

  def get(attr)
    @data[attr]
  end

  def set(attr, value)
    @data[attr] = value
  end
end
