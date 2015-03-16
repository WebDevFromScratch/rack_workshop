require 'rubygems'
require 'active_support/core_ext/numeric/time'
require 'rate_limiter_pa/version'
require 'pry'

module Rack
  class RateLimiterPa
    def initialize(app, options = {})
      options = { limit: '20', reset_in: '3600' }.merge(options)
      @app = app
      @limit_total = options[:limit].to_i
      @limit_remaining = @limit_total
      @reset_in = options[:reset_in].to_i
      @limit_reset = Time.now + @reset_in
      @ip_addresses = []
    end

    def call(env)
      set_ip_variables(env)

      adjust_limit_remaining
      adjust_limit_reset_left

      if limit_reached?
        status = 429
        headers = {}
        response = ['Too many requests']
      else
        status, headers, response = @app.call(env)
      end

      if reset_time_reached?
        @limit_reset = @limit_reset + @reset_in
        @limit_remaining = @limit_total
        adjust_limit_reset_left
      end

      add_headers(headers)

      [status, headers, response]
    end

    def set_ip_variables(env)
      @ip = env['REMOTE_ADDR']

      if @ip_addresses.any? { |ip| ip[:ip] == @ip }
        @current_ip = @ip_addresses.find { |ip| ip[:ip] == @ip }
      else
        ip_vars = { ip: @ip, limit_remaining: @limit_total, limit_reset: @limit_reset }
        @ip_addresses << ip_vars
        @current_ip = ip_vars
      end

      @limit_remaining = @current_ip[:limit_remaining]
      @limit_reset = @current_ip[:limit_reset]
    end

    def add_headers(headers)
      add_limit_total_header(headers)
      add_limit_remaining_header(headers)
      add_limit_reset_left_header(headers)
    end

    def add_limit_total_header(headers)
      headers.merge! 'X-RateLimit-Limit' => @limit_total.to_s
    end

    def add_limit_remaining_header(headers)
      headers.merge! 'X-RateLimit-Remaining' => @limit_remaining.to_s
    end

    def add_limit_reset_left_header(headers)
      headers.merge! 'X-RateLimit-Reset' => @limit_reset_left.to_s
    end

    def adjust_limit_remaining
      @limit_remaining -= 1
      @current_ip[:limit_remaining] = @limit_remaining
    end

    def adjust_limit_reset_left
      @limit_reset_left = @limit_reset - Time.now
      @current_ip[:limit_reset] = @limit_reset
    end

    def limit_reached?
      @limit_remaining < 0
    end

    def reset_time_reached?
      @limit_reset_left <= 0
    end
  end
end
