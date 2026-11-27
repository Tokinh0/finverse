module Api::V1
  class SubcategoriesController < ApplicationController
    before_action :set_subcategory, only: %i[ show update destroy ]

    def index
      subcategories = Subcategory.all.includes(:category)
      render json: subcategories.map { |s| SubcategoryPresenter.new(s) }
    end

    def show
      render json: SubcategoryPresenter.new(@subcategory)
    end

    def create
      subcategory = Subcategory.new(subcategory_params)

      if subcategory.save
        render json: SubcategoryPresenter.new(subcategory), status: :created
      else
        render json: subcategory.errors, status: :unprocessable_content
      end
    end

    def update
      if @subcategory.update(subcategory_params)
        render json: SubcategoryPresenter.new(@subcategory)
      else
        render json: @subcategory.errors, status: :unprocessable_content
      end
    end

    def destroy
      if @subcategory.destroy
        head :no_content
      else
        render json: { errors: @subcategory.errors.full_messages }, status: :unprocessable_content
      end
    end

    private
      def set_subcategory
        @subcategory = Subcategory.find(params[:id])
      end

      def subcategory_params
        params.require(:subcategory).permit(:name, :category_id, :color_code, :subcategory_type)
      end
  end
end
