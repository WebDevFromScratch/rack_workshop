require 'rubygems'
require 'active_support/core_ext/numeric/time'
require 'rate_limiter_pa/version'
require 'pry'

module Rack
  class RateLimiterPa
    def initialize(app, options = {}, &block)
      if block_given?
        @block_given = true
      end

      options = { limit: '20', reset_in: '3600' }.merge(options)
      @app = app
      @limit_total = options[:limit].to_i
      @limit_remaining = @limit_total
      @reset_in = options[:reset_in].to_i
      @limit_reset = Time.now + @reset_in
      @ids = []
      @block = block
    end

    def call(env)
      if limit_reached?
        return [429, {}, ['Too many requests']]
      else
        status, headers, response = @app.call(env)
      end

      if @block_given
        if @block.call == nil
          return [status, headers, response]
        else
          set_id_as_token(env)
          set_id_variables(env)
        end
      else
        set_id_as_ip(env)
        set_id_variables(env)
      end

      adjust_limit_remaining
      adjust_limit_reset_left

      if reset_time_reached?
        @limit_reset = @limit_reset + @reset_in
        @limit_remaining = @limit_total
        adjust_limit_remaining
        adjust_limit_reset_left
      end

      add_headers(headers)

      [status, headers, response]
    end

    def set_id_as_token(env)
      @id = @block.call
    end

    def set_id_as_ip(env)
      @id = env['REMOTE_ADDR']
    end

    def set_id_variables(env)
      if @ids.any? { |id| id[:id] == @id }
        @current_id = @ids.find { |id| id[:id] == @id }
      else
        id_vars = { id: @id, limit_remaining: @limit_total, limit_reset: @limit_reset }
        @ids << id_vars
        @current_id = id_vars
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

    def adjust_limit_remaining
      @limit_remaining -= 1
      @current_id[:limit_remaining] = @limit_remaining if @current_id
    end

    def adjust_limit_reset_left
      @limit_reset_left = @limit_reset - Time.now
      @current_id[:limit_reset] = @limit_reset if @current_id
    end

    def limit_reached?
      @limit_remaining < 0
    end

    def reset_time_reached?
      @limit_reset_left <= 0
    end
  end
end
