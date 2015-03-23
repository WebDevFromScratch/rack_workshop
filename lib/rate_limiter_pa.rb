require 'rubygems'
require 'active_support/core_ext/numeric/time'
require 'rate_limiter_pa/version'
require 'rate_limiter_pa/default_store'

module Rack
  class RateLimiterPa
    def initialize(app, options = {}, &block)
      @block_given = true if block_given?

      options = { limit: 20, reset_in: 3600, store: DefaultStore.new }.merge(options)
      @app = app
      @limit_total = options[:limit].to_i
      @limit_remaining = @limit_total
      @reset_in = options[:reset_in].to_i
      @limit_reset = Time.now + @reset_in
      @ids = []
      @block = block
      @store = options[:store]
    end

    def call(env)
      return [429, {}, ['Too many requests']] if limit_reached?
      status, headers, response = @app.call(env)

      if @block_given && @block.call == nil
        return [status, headers, response]
      elsif @block_given
        set_id_as_token(env)
      else
        set_id_as_ip(env)
      end

      get_or_set_id_variables(env)
      reset_limits if reset_time_reached?
      adjust_limit_remaining
      add_headers(headers)

      [status, headers, response]
    end

    def set_id_as_token(env)
      @id = @block.call
    end

    def set_id_as_ip(env)
      @id = env['REMOTE_ADDR'] || 0
    end

    def get_or_set_id_variables(env)
      if @store.get(@id)
        @current_id = @store.get(@id)
      else
        id_vars = { limit_remaining: @limit_total, limit_reset: @limit_reset }
        @store.set(@id, id_vars)
        @current_id = @store.get(@id)
      end

      @limit_remaining = @current_id[:limit_remaining]
      @limit_reset = @current_id[:limit_reset]
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

    def reset_limits
      @limit_reset = Time.now + @reset_in
      @limit_remaining = @limit_total
      adjust_limit_reset_left
    end

    def adjust_limit_remaining
      @limit_remaining -= 1
      @current_id[:limit_remaining] = @limit_remaining
    end

    def adjust_limit_reset_left
      @limit_reset_left = @limit_reset - Time.now
      @current_id[:limit_reset] = @limit_reset
    end

    def limit_reached?
      @limit_remaining <= 0
    end

    def reset_time_reached?
      @limit_reset_left = @limit_reset - Time.now
      @limit_reset_left <= 0
    end
  end
end
