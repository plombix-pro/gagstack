class RepCalculator
  DELTAS = {
    post_upvote: 10,
    post_downvote: -2,
    comment_upvote: 5,
    comment_downvote: -1,
    post_deleted_after_downvote: 3,
    flag_confirmed: -10,
    flag_dismissed: 1,
    ban: -100,
  }.freeze

  def initialize(user)
    @user = user
  end

  def apply(action)
    delta = DELTAS[action]
    return 0 unless delta
    new_rep = [@user.reputation + delta, 0].max
    @user.update!(reputation: new_rep)
    delta
  end
end
