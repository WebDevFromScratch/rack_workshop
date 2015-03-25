require 'rate_limiter_pa/version'
require 'rate_limiter_pa/default_store'

module Rack
  class RateLimiterPa
    DEFAULT_BLOCK = Proc.new { |env| env['REMOTE_ADDR'] }

    def initialize(app, options = {}, &block)
      options = { limit: 20, reset_in: 3600, store: DefaultStore.new }.merge(options)

      @app = app
      @limit_total = options[:limit].to_i
      @reset_in = options[:reset_in].to_i
      @limit_reset = Time.now + @reset_in
      @block = block || DEFAULT_BLOCK
      @store = options[:store]
    end

    def call(env)
      set_id(env)
      if @id
        get_or_create_stored_id(@id)
        reset_limits if reset_time_reached?
        adjust_limit_remaining
        update_stored_id(@id)
        return [429, {}, ['Too many requests']] if limit_reached?
      end

      @app.call(env).tap { |env| add_headers(env[1]) unless unlimited_calls? }
    end

    def set_id(env)
      @id = @block.call(env)
    end

    def unlimited_calls?
      true unless @id
    end

    def get_or_create_stored_id(id)
      if @store.get(id)
        @current_id = @store.get(id)
      else
        id_vars = { limit_remaining: @limit_total, limit_reset: @limit_reset }
        @store.set(id, id_vars)
        @current_id = @store.get(id)
      end

      set_limits
    end

    def update_stored_id(id)
      id_vars = { limit_remaining: @limit_remaining, limit_reset: @limit_reset }
      @store.set(id, id_vars)
    end

    def add_headers(headers)
      add_limit_total_header(headers)
      add_limit_remaining_header(headers)
      add_limit_reset_header(headers)
    end

    def add_limit_total_header(headers)
      headers.merge! 'X-RateLimit-Limit' => @limit_total.to_s
    end

    def add_limit_remaining_header(headers)
      headers.merge! 'X-RateLimit-Remaining' => @limit_remaining.to_s
    end

    def add_limit_reset_header(headers)
      headers.merge! 'X-RateLimit-Reset' => @limit_reset.to_i.to_s
    end

    def set_limits
      @limit_remaining = @current_id[:limit_remaining]
      @limit_reset = @current_id[:limit_reset]
    end

    def reset_limits
      @limit_reset = Time.now + @reset_in
      @limit_remaining = @limit_total
    end

    def adjust_limit_remaining
      @limit_remaining -= 1
    end

    def limit_reset_left
      @limit_reset - Time.now
    end

    def limit_reached?
      @limit_remaining < 0
    end

    def reset_time_reached?
      limit_reset_left <= 0
    end
  end
end
