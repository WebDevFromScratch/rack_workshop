require 'rubygems'
require 'active_support/core_ext/numeric/time'
require 'rate_limiter_pa/version'
require 'pry'

module Rack
  class RateLimiterPa
    def initialize(app, options = {})
      options = { limit: '20', reset_in: '3600' }.merge(options)
      @app = app
      @limit_total = options[:limit]
      @limit_remaining = @limit_total
      @reset_in = options[:reset_in].to_i
      @limit_reset = Time.now + @reset_in
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

      @limit_reset_left = @limit_reset - Time.now
      headers.merge! 'X-RateLimit-Reset' => @limit_reset_left.to_s

      if @limit_reset_left <= 0
        @limit_reset = @limit_reset + @reset_in
        @limit_remaining = @limit_total
      end

      [status, headers, response]
    end
  end
end
