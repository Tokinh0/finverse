Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :assets
      resources :transactions, only: %i[index update]
      resources :keywords
      resources :monthly_statements, only: %i[index show create destroy]
      resources :subcategories
      resources :categories
      namespace :reports do
        get :monthly_by_category
        get :monthly_by_subcategory
      end
      get :portfolio_dashboard, to: 'portfolio_dashboard#index'
    end
  end
end
