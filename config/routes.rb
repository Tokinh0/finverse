Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :profiles, only: %i[index create]
      resource :profile, only: %i[show update], controller: "current_profile"
      resource :session, only: %i[show create destroy]
      resources :assets
      resources :transactions, only: %i[index update] do
        member do
          post :unknown, action: :mark_unknown
          delete :unknown, action: :unmark_unknown
        end
      end
      resources :alerts, only: :index do
        collection do
          post :dismiss
          delete :dismiss, action: :restore
        end
      end
      get "keywords/health", to: "keyword_health#index"
      resources :keywords
      resources :monthly_statements, only: %i[index show create destroy]
      resources :subcategories
      resources :categories
      namespace :reports do
        get :monthly_by_category
        get :monthly_by_subcategory
        get :financial_health
        get :categorization_progress
      end
      get :portfolio_dashboard, to: "portfolio_dashboard#index"
      get "suggestions/summary", to: "suggestions#summary"
      resources :suggestion_runs, only: %i[index create]
      resources :rule_suggestions, only: :index do
        member do
          post :accept
          post :reject
        end
      end
      resources :category_suggestions, only: :index do
        member do
          post :accept
          post :reject
          post :dont_know
        end
        collection { post :bulk_accept }
      end
      namespace :settings do
        resource :claude, only: %i[show update destroy], controller: "claude"
        resource :preferences, only: %i[show update]
      end
    end
  end
end
