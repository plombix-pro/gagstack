module Api
  module V1
    class PostsController < BaseController
      def index
        posts = Post.approved.includes(:user, :category).order(created_at: :desc).limit(20)
        render json: posts.map { |p|
          {
            id: p.id,
            title: p.title,
            media_url: url_for(p.media),
            thumbnail_url: p.thumbnail.attached? ? url_for(p.thumbnail) : nil,
            media_type: p.media_type,
            upvotes: p.upvotes_count,
            downvotes: p.downvotes_count,
            comments_count: p.comments_count,
            username: p.user.username,
            category: p.category.name,
            created_at: p.created_at
          }
        }
      end

      def show
        post = Post.find(params[:id])
        render json: {
          id: post.id,
          title: post.title,
          media_url: url_for(post.media),
          thumbnail_url: post.thumbnail.attached? ? url_for(post.thumbnail) : nil,
          media_type: post.media_type,
          upvotes: post.upvotes_count,
          downvotes: post.downvotes_count,
          comments_count: post.comments_count,
          username: post.user.username,
          category: post.category.name,
          created_at: post.created_at
        }
      end

      def create
        # Mobile uploads - future implementation
        render json: { error: "Not implemented" }, status: :not_implemented
      end
    end
  end
end
