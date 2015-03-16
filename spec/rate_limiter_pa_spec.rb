require 'timecop'
require 'rack/test'
require 'spec_helper'

describe Rack::RateLimiterPa do
  let(:app) { lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']]} }
  let(:stack) { Rack::Lint.new(Rack::RateLimiterPa.new(app)) }
  let(:request) { Rack::MockRequest.new(stack) }
  let(:response) { request.get('/') }

  it 'response should be okay' do
    expect(response).to be_ok
  end

  describe 'X-RateLimit-Limit header' do
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

  describe 'X-RateLimit-Remaining header' do
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
      61.times { request.get('/') }

      expect(response).not_to be_ok
      expect(response.status).to eq(429)
      expect(response.body).to eq('Too many requests')
    end

    it 'resets after an hour after first request' do
      # this test fails if REMOTE_ADDR not given
      3.times { request.get('/', { "REMOTE_ADDR" => "10.0.0.1" }) }
      Timecop.freeze(3650)
      request.get('/', { "REMOTE_ADDR" => "10.0.0.1" })


      expect(response.headers['X-RateLimit-Remaining'].to_i).to eq(59)
    end

    it 'TESTS' do
      response = request.get('/', { "REMOTE_ADDR" => "10.0.0.1" })
      3.times { request.get('/', { "REMOTE_ADDR" => "10.0.0.1" }) }
      response = request.get('/', { "REMOTE_ADDR" => "10.0.0.2" })
      response = request.get('/', { "REMOTE_ADDR" => "10.0.0.2" })
      response = request.get('/', { "REMOTE_ADDR" => "10.0.0.2" })
      # this needs improvements...

      expect(response.headers['X-RateLimit-Remaining'].to_i).to eq(57)
    end
  end

  describe 'X-RateLimit-Reset' do
    it 'is present' do
      expect(response.headers['X-RateLimit-Reset']).to be_truthy
    end

    context 'shows the correct reset time' do
      let(:stack) { Rack::Lint.new(Rack::RateLimiterPa.new(app)) }
      let(:request) { Rack::MockRequest.new(stack) }
      let(:response) { request.get('/') }

      before do
        request.get('/')
      end

      it 'right after the initial request' do
        expect(response.headers['X-RateLimit-Reset'].to_f).to be_within(0.01).of(3600)
      end

      it 'after some time passed' do
        Timecop.freeze(1800)
        request.get('/')

        expect(response.headers['X-RateLimit-Reset'].to_f).to be_within(0.01).of(1800)
      end

      it 'resets after an hour passed' do
        Timecop.freeze(3650)
        request.get('/')

        expect(response.headers['X-RateLimit-Reset'].to_f).to be_within(0.01).of(3550)
      end

      it 'works with other than default passed values' do
        stack = Rack::Lint.new(Rack::RateLimiterPa.new(app, { reset_in: '1800' }))
        request = Rack::MockRequest.new(stack)
        response = request.get('/')

        expect(response.headers['X-RateLimit-Reset'].to_f).to be_within(0.01).of(1800)
      end
    end
  end
end
