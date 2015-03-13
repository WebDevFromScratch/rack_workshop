require 'rack/test'
require 'spec_helper'

describe Rack::RateLimiterPa do
  let(:app) { lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']]} }
  let(:stack) { Rack::Lint.new(Rack::RateLimiterPa.new(app)) }
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

      expect(response.headers['X-RateLimit-Limit']).to eq('0')
    end

    it 'is equal to a passed value if set' do
      stack = Rack::Lint.new(Rack::RateLimiterPa.new(app, { limit: '60' }))
      request = Rack::MockRequest.new(stack)
      response = request.get('/')

      expect(response.headers['X-RateLimit-Limit'].to_i).to eq(60)
    end
  end

  context 'X-RateLimit-Remaining header' do
    it 'is present' do
      stack = Rack::Lint.new(Rack::RateLimiterPa.new(app, { limit: '60' }))
      request = Rack::MockRequest.new(stack)
      response = request.get('/')

      expect(response.headers['X-RateLimit-Remaining']).to be_truthy
    end

    it 'decreases by one with each request' do
      stack = Rack::Lint.new(Rack::RateLimiterPa.new(app, { limit: '60' }))
      request = Rack::MockRequest.new(stack)
      request.get('/')
      response = request.get('/')

      expect(response.headers['X-RateLimit-Remaining'].to_i).to eq(58)
    end
  end
end
