module ApiTokenAuthentication
  extend ActiveSupport::Concern

  private

  def authenticate_api!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Unauthorized" }, status: :unauthorized unless token

    digest = Digest::SHA256.hexdigest(token)
    api_token = ApiToken.find_by(token_hash: digest)

    if api_token && BCrypt::Password.new(api_token.token_digest).is_password?(token)
      Current.user = api_token.user
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
