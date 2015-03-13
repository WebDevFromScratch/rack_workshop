require "rate_limiter_pa/version"

module Rack
  class RateLimiterPa
    def initialize(app, options={ limit: '0' })
      @app = app
      @options = options
    end

    def call(env)
      status, headers, response = @app.call(env)
      headers.merge! 'X-RateLimit-Limit' => @options[:limit]
      [status, headers, response]
    end
  end
end
