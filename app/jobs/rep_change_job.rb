class RepChangeJob < ApplicationJob
  queue_as :default

  def perform(user:, delta:)
    user.update!(reputation: [user.reputation + delta, 0].max)
  end
end
