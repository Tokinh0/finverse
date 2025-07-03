module Api::V1
  class CategoriesController < ApplicationController
    before_action :set_category, only: %i[ show update destroy ]

    def index
      categories = Category.includes(:subcategories)
      render json: categories.map { |cat| CategoryPresenter.new(cat).as_json }
    end

    def show
      render json: @category
    end

    def update
      category = Category.find(params[:id])
      if category.update(category_params)
        render json: CategoryPresenter.new(category)
      else
        render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
      end
    end    

    def create
      category = Category.new(category_params)
      if category.save
        render json: CategoryPresenter.new(category), status: :created
      else
        render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @category.destroy!
    end

    private

      def set_category
        @category = Category.find(params[:id])
      end

      def category_params
        params.require(:category).permit(:name, :color_code)
      end
  end
end
