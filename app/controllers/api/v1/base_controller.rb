module Api
  module V1
    class BaseController < ApplicationController
      include ApiTokenAuthentication
      skip_before_action :require_authentication
      before_action :authenticate_api!
    end
  end
end
