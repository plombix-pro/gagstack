module Api
  module V1
    class AuthController < ApplicationController
      allow_unauthenticated_access
      skip_before_action :require_authentication

      def login
        user = User.find_by(email_address: params[:email]&.downcase)
        if user&.authenticate(params[:password])
          token = SecureRandom.hex(32)
          user.api_tokens.create!(
            token_digest: BCrypt::Password.create(token),
            token_hash: Digest::SHA256.hexdigest(token)
          )
          render json: { token: token, user: { id: user.id, username: user.username, email: user.email_address } }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end
    end
  end
end
