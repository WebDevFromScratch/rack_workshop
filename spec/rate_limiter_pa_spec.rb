require 'rack/test'
require 'spec_helper'

describe RateLimiterPa do
  let(:app) { lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']]} }
  let(:stack) { RateLimiterPa.new(app, {}) }
  let(:request) { Rack::MockRequest.new(stack) }

  context 'issue a request' do
    let(:response) { request.get('/') }

    it 'response should be okay' do
      expect(response).to be_ok
    end
  end

  context 'X-RateLimit-Limit header' do
    it 'is a nil if not set' do
      response = request.get('/')

      expect(response.headers['X-RateLimit-Limit']).to be(nil)
    end

    it 'is equal to a passed value if set' do
      stack = RateLimiterPa.new(app, { limit: 60 })
      request = Rack::MockRequest.new(stack)
      response = request.get('/')

      expect(response.headers['X-RateLimit-Limit']).to eq(60)
    end
  end
end
