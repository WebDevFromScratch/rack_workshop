require "rate_limiter_pa/version"

class RateLimiterPa
  def initialize(app, options={})
    @app = app
    @options = options
  end

  def call(env)
    status, headers, response = @app.call(env)
    headers.merge! 'X-RateLimit-Limit' => @options[:limit]
    [status, headers, response]
  end
end
