Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :keywords
      resources :monthly_statements
      resources :subcategories
      resources :categories
      namespace :reports do
        get :monthly_by_category
        get :monthly_by_subcategory
      end
    end
  end
end
