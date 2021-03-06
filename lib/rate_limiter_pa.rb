require 'rate_limiter_pa/version'
require 'rate_limiter_pa/default_store'

module Rack
  class RateLimiterPa
    DEFAULT_BLOCK = Proc.new { |env| env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR'] }

    def initialize(app, options = {}, &block)
      options = { limit: 20, reset_in: 3600, store: DefaultStore.new }.merge(options)

      @app = app
      @limit_total = options[:limit].to_i
      @reset_in = options[:reset_in].to_i
      @limit_reset_at = Time.now + @reset_in
      @block = block || DEFAULT_BLOCK
      @store = options[:store]
    end

    def call(env)
      set_id(env)
      unless id_nil?
        set_limits
        reset_limits if reset_time_reached?
        adjust_limit_remaining
        store_client(@id, @limit_remaining)
        return [429, {}, ['Too many requests']] if limit_reached?
      end

      @app.call(env).tap { |status, headers, body| add_headers(headers) unless id_nil? }
    end

    def set_id(env)
      @id = @block.call(env)
    end

    def id_nil?
      @id.nil?
    end

    def client_already_stored?
      !!@store.get(@id)
    end

    def get_current_client
      @store.get(@id)
    end

    def store_client(id, limit_remaining)
      client = { limit_remaining: limit_remaining, limit_reset_at: @limit_reset_at }
      @store.set(id, client)
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
      headers.merge! 'X-RateLimit-Reset' => @limit_reset_at.to_i.to_s
    end

    def set_limits
      if client_already_stored?
        @limit_remaining = get_current_client[:limit_remaining]
        @limit_reset_at = get_current_client[:limit_reset_at]
      else
        reset_limits
      end
    end

    def reset_limits
      @limit_reset_at = Time.now + @reset_in
      @limit_remaining = @limit_total
    end

    def adjust_limit_remaining
      @limit_remaining -= 1
    end

    def limit_reset_left
      @limit_reset_at - Time.now
    end

    def limit_reached?
      @limit_remaining < 0
    end

    def reset_time_reached?
      limit_reset_left <= 0
    end
  end
end
