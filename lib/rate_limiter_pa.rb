require "rate_limiter_pa/version"

module Rack
  class RateLimiterPa
    def initialize(app, options={ limit: '20' })
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

      if @limit_remaining < 0
        status = 429
      end

      [status, headers, response]
    end
  end
end
