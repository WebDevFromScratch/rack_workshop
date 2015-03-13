require "rate_limiter_pa/version"

class RateLimiterPa
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    headers.merge! 'X-RateLimit-Limit' => 60
    [status, headers, response]
  end
end
