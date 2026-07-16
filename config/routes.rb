Rails.application.routes.draw do
  root "posts#index"

  resource :session, only: [:new, :create, :destroy]
  resource :search, only: [:show]
  resources :passwords, param: :token
  resources :registrations, only: [:new, :create]

  get "sign_in", to: "sessions#new", as: :sign_in
  get "sign_up", to: "registrations#new", as: :sign_up
  get "verify/:token", to: "verifications#show", as: :verify_email
  resource :age_verification, only: %i[ new create ], controller: "age_verification"
  resource :profile, only: [:edit, :update], controller: "profiles" do
    post :cancel_email_change, on: :member
  end
  get "profile/:username", to: "profiles#show", as: :public_profile
  get "verify_email_change/:token", to: "email_changes#show", as: :verify_email_change

  resources :categories, only: [:index, :show] do
    resources :posts, only: [:index], controller: "posts"
  end

  resources :posts do
    member do
      post :vote
    end
    resources :comments, only: [:create, :destroy] do
      member do
        post :vote
      end
    end
    resources :flags, only: [:create]
  end

  resources :flags, only: [:create]

  namespace :mod do
    root to: "dashboard#index"
    resources :flags, only: [:index, :update] do
      collection do
        get :content
      end
    end
    resources :posts, only: [:index, :update]
    get "watermark", to: "watermark#index"
    post "watermark/extract", to: "watermark#extract"
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [:index, :show, :update]
    resources :categories, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :reputation_thresholds, only: [:index, :edit, :update]
    resources :moderation_logs, only: [:index]
    resources :flags, only: [:index] do
      collection do
        get :content
      end
    end
    resources :announcements, only: [:index, :new, :create, :edit, :update, :destroy]
  end

  namespace :api do
    namespace :v1 do
      resources :posts, only: [:index, :show, :create]
      resources :categories, only: [:index]
      post "auth/login", to: "auth#login"
      resource :profile, only: [:show, :update]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
