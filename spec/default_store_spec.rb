require 'rate_limiter_pa/default_store'

describe DefaultStore do
  let(:store) { DefaultStore.new() }

  it 'correctly sets and retrieves data' do
    store.set(:attr, '2')

    expect(store.get(:attr)).to eq('2')
  end
end
