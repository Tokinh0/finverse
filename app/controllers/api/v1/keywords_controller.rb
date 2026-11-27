module Api::V1
  class KeywordsController < ApplicationController
    before_action :set_keyword, only: %i[ show update destroy ]

    def index
      keywords = Keyword.includes(subcategory: :category).order(:subcategory_id)
      render json: keywords.map { |keyword| KeywordPresenter.new(keyword) }
    end

    def show
      render json: KeywordPresenter.new(@keyword)
    end

    def create
      keyword = Keyword.new(keyword_params)

      if keyword.save
        render json: KeywordPresenter.new(keyword), status: :created
      else
        render json: keyword.errors, status: :unprocessable_content
      end
    end

    def update
      if @keyword.update(keyword_params)
        render json: KeywordPresenter.new(@keyword)
      else
        render json: @keyword.errors, status: :unprocessable_content
      end
    end

    def destroy
      @keyword.destroy!
      head :no_content
    end

    private
      def set_keyword
        @keyword = Keyword.includes(subcategory: :category).find(params[:id])
      end

      def keyword_params
        params.require(:keyword).permit(:name, :subcategory_id, :description, :color_code, :keyword_type)
      end
  end
end
