class DefaultStore
  def initialize
    @data = {}
  end

  def get(attr)
    @data[attr].dup if @data.key?(attr)
  end

  def set(attr, value)
    @data[attr] = value
  end
end
