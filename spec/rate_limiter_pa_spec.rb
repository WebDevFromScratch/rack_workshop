require 'rack/test'
require 'spec_helper'

describe RateLimiterPa do
  include Rack::Test::Methods

  let(:app) { lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']]} }
  subject { RateLimiterPa.new(app) }

  context 'issue a request' do
    before { get '/' }

    it 'response should be okay' do
      expect(last_response).to(be_ok)
    end
  end
end
