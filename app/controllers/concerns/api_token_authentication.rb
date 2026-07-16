module ApiTokenAuthentication
  extend ActiveSupport::Concern

  private

  def authenticate_api!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Unauthorized" }, status: :unauthorized unless token

    api_token = ApiToken.all.find_each do |at|
      break at if BCrypt::Password.new(at.token_digest).is_password?(token)
    end

    if api_token
      Current.user = api_token.user
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
