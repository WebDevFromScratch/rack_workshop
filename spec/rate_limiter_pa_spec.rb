require 'timecop'
require 'rack/test'
require 'spec_helper'
require 'rate_limiter_pa/default_store'

describe Rack::RateLimiterPa do
  include Rack::Test::Methods

  let(:inner_app) { lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']]} }
  let(:app) { Rack::Lint.new(Rack::RateLimiterPa.new(inner_app)) }
  before { get '/' }

  it 'response should be okay' do
    expect(last_response).to be_ok
  end

  describe 'X-RateLimit-Limit header' do
    context 'if not specifically set' do
      it 'is a string "20"' do
        expect(last_response.headers['X-RateLimit-Limit']).to eq('20')
      end
    end

    context 'if specifically set' do
      let(:app) { Rack::Lint.new(Rack::RateLimiterPa.new(inner_app, { limit: 60 })) }

      it 'is equal to the set value' do
        expect(last_response.headers['X-RateLimit-Limit'].to_i).to eq(60)
      end
    end
  end

  describe 'X-RateLimit-Remaining header' do
    it 'is present' do
      expect(last_response.headers['X-RateLimit-Remaining']).to be_truthy
    end

    it 'decreases by one with each request' do
      2.times { get '/' }

      expect(last_response.headers['X-RateLimit-Remaining'].to_i).to eq(17)
    end

    it 'resets after an hour after the first request' do
      3.times { get '/' }
      Timecop.freeze(3650)
      get '/'

      expect(last_response.headers['X-RateLimit-Remaining'].to_i).to eq(19)
    end

    context 'if the limit has been exceeded' do
      before { 20.times { get '/' } }

      it 'does not call the app' do
        expect(inner_app).not_to receive(:call)
        get '/'
      end

      it 'response has a 429 status and an appropriate text in the body' do
        expect(last_response).not_to be_ok
        expect(last_response.status).to eq(429)
        expect(last_response.body).to eq('Too many requests')
      end
    end
  end

  describe 'X-RateLimit-Reset' do
    it 'is present' do
      expect(last_response.headers['X-RateLimit-Reset']).to be_truthy
    end

    context 'if not specifically set' do
      context 'it shows the correct reset time' do
        it 'right after the initial request' do
          expect(last_response.headers['X-RateLimit-Reset'].to_f).to be_within(0.1).of(3600)
        end

        it 'after some time passed' do
          Timecop.freeze(1800)
          get '/'

          expect(last_response.headers['X-RateLimit-Reset'].to_f).to be_within(0.1).of(1800)
        end

        it 'resets after an hour passed' do
          Timecop.freeze(3650)
          get '/'

          expect(last_response.headers['X-RateLimit-Reset'].to_f).to be_within(0.1).of(3600)
        end
      end
    end

    context 'if specifically set' do
      let(:app) { Rack::Lint.new(Rack::RateLimiterPa.new(inner_app, reset_in: 1800)) }

      it 'works correctly' do
        expect(last_response.headers['X-RateLimit-Reset'].to_f).to be_within(0.1).of(1800)
      end
    end
  end

  describe 'Client Detection' do
    context 'without a block' do
      it 'correctly uses IP for identification' do
        21.times { get '/', {}, "REMOTE_ADDR" => "10.0.0.1" }
        3.times { get '/', {}, "REMOTE_ADDR" => "10.0.0.2" }
        2.times { get '/', {}, "REMOTE_ADDR" => "10.0.0.3" }

        expect(last_response.headers['X-RateLimit-Remaining'].to_i).to eq(18)
      end
    end

    context 'with a block' do
      context 'that returns nil' do
        let(:app) { Rack::Lint.new(Rack::RateLimiterPa.new(inner_app) {}) }

        it 'does not use limit headers' do
          expect(last_response.headers['X-RateLimit-Limit']).to be(nil)
          expect(last_response.headers['X-RateLimit-Remaining']).to be(nil)
          expect(last_response.headers['X-RateLimit-Reset']).to be(nil)
        end
      end

      context 'that returns something' do
        let(:app) { Rack::Lint.new(Rack::RateLimiterPa.new(inner_app) { 'something' }) }

        it 'uses limit headers' do
          expect(last_response.headers['X-RateLimit-Limit']).to be_truthy
          expect(last_response.headers['X-RateLimit-Remaining']).to be_truthy
          expect(last_response.headers['X-RateLimit-Reset']).to be_truthy
        end

        it 'uses token given by the block for identification, even if the IP is given too' do
          5.times { get '/', {}, "REMOTE_ADDR" => "10.0.0.1" }
          2.times { get '/', {},  "REMOTE_ADDR" => "10.0.0.2" }

          expect(last_response.headers['X-RateLimit-Remaining'].to_i).to eq(12)
        end
      end
    end
  end

  describe 'Custom store' do
    let(:store) { double(:store, get: { limit_remaining: 10, limit_reset: Time.now + 1800 }) }
    let(:app) { Rack::Lint.new(Rack::RateLimiterPa.new(inner_app, { store: store }) { 'something' }) }

    it 'works correctly with custom store' do
      2.times { get '/' }

      expect(last_response.headers['X-RateLimit-Remaining'].to_i).to eq(7)
      expect(last_response.headers['X-RateLimit-Reset'].to_f).to be_within(0.1).of(1800)
    end
  end
end
