class FeedBuilder
  PER_PAGE = 20

  def initialize(category: nil, sort: "fresh", cursor: nil)
    @category = category
    @sort = sort
    @cursor = cursor
  end

  def call
    posts = Post.approved.includes(:user, :category, :thumbnail_attachment)
    posts = posts.where(category: @category) if @category

    posts = case @sort
    when "hot" then posts.hot
    when "trending" then posts.order(trending_score: :desc)
    else posts.fresh
    end

    posts = posts.where("created_at < ?", Time.zone.parse(@cursor)) if @cursor.present?
    posts.limit(PER_PAGE)
  end
end
