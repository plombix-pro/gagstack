module ApplicationHelper
  def grouped_categories
    cats = Category.ordered
    cats = cats.where.not("LOWER(name) LIKE ?", "%nsfw%") unless authenticated?

    top = cats
      .left_joins(:posts)
      .group(:id)
      .order(Arel.sql("COALESCE(SUM(posts.trending_score), 0) DESC"))
      .limit(3)

    remaining = cats.where.not(id: top.pluck(:id))
    [top, remaining]
  end
end
