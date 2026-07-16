module ApplicationHelper
  def grouped_categories
    top = Category.ordered
      .left_joins(:posts)
      .group(:id)
      .order(Arel.sql("COALESCE(SUM(posts.trending_score), 0) DESC"))
      .limit(3)

    remaining = Category.ordered.where.not(id: top.pluck(:id))
    [top, remaining]
  end
end
