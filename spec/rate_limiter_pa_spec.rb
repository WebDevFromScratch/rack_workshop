require 'rack/test'
require 'spec_helper'

describe Rack::RateLimiterPa do
  let(:app) { lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']]} }
  let(:stack) { Rack::Lint.new(Rack::RateLimiterPa.new(app)) }
  let(:request) { Rack::MockRequest.new(stack) }
  let(:response) { request.get('/') }

  context 'issue a request' do
    it 'response should be okay' do
      expect(response).to be_ok
    end
  end

  context 'X-RateLimit-Limit header' do
    it 'is a string "20" if not set' do
      expect(response.headers['X-RateLimit-Limit']).to eq('20')
    end

    it 'is equal to a passed value if set' do
      stack = Rack::Lint.new(Rack::RateLimiterPa.new(app, { limit: '60' }))
      request = Rack::MockRequest.new(stack)
      response = request.get('/')

      expect(response.headers['X-RateLimit-Limit'].to_i).to eq(60)
    end
  end

  context 'X-RateLimit-Remaining header' do
    let(:stack) { Rack::Lint.new(Rack::RateLimiterPa.new(app, { limit: '60' })) }
    let(:request) { Rack::MockRequest.new(stack) }
    let(:response) { request.get('/') }

    it 'is present' do
      expect(response.headers['X-RateLimit-Remaining']).to be_truthy
    end

    it 'decreases by one with each request' do
      2.times { request.get('/') }

      expect(response.headers['X-RateLimit-Remaining'].to_i).to eq(57)
    end

    it 'responds with "429 Too Many Requests" if limit is exceeded' do
      60.times { request.get('/') }

      expect(response).not_to be_ok
      expect(response.status).to eq(429)
    end
  end
end
