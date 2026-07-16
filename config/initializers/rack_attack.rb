class Rack::Attack
  throttle("uploads/ip", limit: 10, period: 60) do |req|
    req.ip if req.post? && req.path == "/posts"
  end

  throttle("votes/ip", limit: 60, period: 60) do |req|
    req.ip if req.path.match?(/\/posts\/\d+\/vote/)
  end

  throttle("comments/ip", limit: 20, period: 60) do |req|
    req.ip if req.path.match?(/\/posts\/\d+\/comments/) && req.post?
  end

  throttle("login/ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/session" && req.post?
  end
end
