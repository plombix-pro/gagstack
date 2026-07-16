class HotnessCalculator
  EPOCH = 1134028003

  def self.calculate(post)
    score = post.upvotes_count - post.downvotes_count
    return 0 if score <= 0
    order = Math.log10([score, 1].max)
    seconds = post.created_at.to_f - EPOCH
    (order + seconds / 45000.0).round(7)
  end

  def self.recalculate_all!
    Post.find_each do |post|
      post.update!(hotness: calculate(post))
    end
  end
end
