require "rate_limiter_pa/version"

module Rack
  class RateLimiterPa
    def initialize(app, options={ limit: '0' })
      @app = app
      @limit_total = options[:limit]
      @limit_remaining = @limit_total
    end

    def call(env)
      status, headers, response = @app.call(env)
      headers.merge! 'X-RateLimit-Limit' => @limit_total

      @limit_remaining = @limit_remaining.to_i
      @limit_remaining -= 1
      headers.merge! 'X-RateLimit-Remaining' => @limit_remaining.to_s

      [status, headers, response]
    end
  end
end
