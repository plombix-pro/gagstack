class FeedBuilder
  PER_PAGE = 20
  CURSOR_FIELDS = {
    "hot" => "hotness",
    "trending" => "trending_score",
  }.freeze
  DEFAULT_CURSOR_FIELD = "created_at"

  attr_reader :cursor_field

  def initialize(category: nil, sort: "fresh", cursor: nil, exclude_nsfw: false)
    @category = category
    @sort = sort
    @cursor = cursor
    @exclude_nsfw = exclude_nsfw
    @cursor_field = DEFAULT_CURSOR_FIELD
  end

  def call
    posts = Post.approved.includes(:user, :category, :thumbnail_attachment)
    posts = posts.where(category: @category) if @category
    posts = posts.joins(:category).where.not("LOWER(categories.name) LIKE ?", "%nsfw%") if @exclude_nsfw

    @cursor_field = CURSOR_FIELDS[@sort] || DEFAULT_CURSOR_FIELD

    posts = case @sort
    when "hot" then posts.hot
    when "trending" then posts.order(trending_score: :desc, id: :desc)
    else posts.fresh
    end

    if @cursor.present?
      value = case @cursor_field
      when DEFAULT_CURSOR_FIELD then Time.zone.parse(@cursor)
      else @cursor.to_f
      end
      posts = posts.where("#{@cursor_field} < ?", value)
    end
    posts.limit(PER_PAGE)
  end

  def cursor_value(post)
    value = post.send(@cursor_field)
    case value
    when Time then value.iso8601(6)
    else value.to_s
    end
  end
end
