module Api::V1
  class SubcategoriesController < ApplicationController
    before_action :set_subcategory, only: %i[ show update destroy ]

    def index
      subcategories = Subcategory.all.includes(:category)
      render json: subcategories.map { |s| SubcategoryPresenter.new(s) }
    end

    def show
      render json: @subcategory
    end

    # POST /subcategories
    def create
      subcategory = Subcategory.new(subcategory_params)

      if subcategory.save
        render json: SubcategoryPresenter.new(subcategory), status: :created
      else
        render json: subcategory.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /subcategories/1
    def update
      subcategory = Subcategory.find(params[:id])
      if subcategory.update(subcategory_params)
        render json: SubcategoryPresenter.new(subcategory)
      else
        render json: subcategory.errors, status: :unprocessable_entity
      end
    end

    # DELETE /subcategories/1
    def destroy
      @subcategory.destroy!
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_subcategory
        @subcategory = Subcategory.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def subcategory_params
        params.require(:subcategory).permit(:name, :category_id, :color_code, :subcategory_type)
      end
  end
end
