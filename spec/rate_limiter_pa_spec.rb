require 'rack/test'
require 'spec_helper'

describe RateLimiterPa do
  let(:app) { lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']]} }
  let(:stack) { RateLimiterPa.new(app) }
  let(:request) { Rack::MockRequest.new(stack) }

  context 'issue a request' do
    let(:response) { request.get('/') }

    it 'response should be okay' do
      expect(response).to be_ok
    end

    it 'has a header present' do
      puts response.headers
      expect(response.headers['X-RateLimit-Limit']).to eq(60)
    end
  end
end
