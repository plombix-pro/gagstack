module Api
  module V1
    class ProfilesController < BaseController
      def show
        render json: user_json(Current.user)
      end

      def update
        if Current.user.update(profile_params)
          render json: user_json(Current.user)
        else
          render json: { errors: Current.user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def profile_params
        params.permit(:username, :email_address)
      end

      def user_json(user)
        {
          id: user.id,
          username: user.username,
          email: user.email_address,
          reputation: user.reputation,
          role: user.role,
          created_at: user.created_at
        }
      end
    end
  end
end
