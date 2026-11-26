class AssetPresenter
  # @param total_by_type [Numeric, nil] sum of current_value for the asset's type; pass it when
  #   presenting many assets to avoid one query per asset.
  def initialize(asset, total_by_type: nil)
    @asset = asset
    @total_by_type = total_by_type
  end

  def as_json(_options = {})
    {
      id:              @asset.id,
      asset_type:      @asset.asset_type,
      ticker:          @asset.ticker,
      description:     @asset.description,
      current_value:   @asset.current_value.to_f,
      rating:          @asset.rating,
      quantity:        @asset.quantity,
      percent_by_type: percent_by_type,
      color_code:      @asset.color_code
    }
  end

  def percent_by_type
    total = @total_by_type || Asset.where(asset_type: @asset.asset_type).sum(:current_value)
    return 0 if total.nil? || total <= 0 || @asset.current_value.nil?

    ((@asset.current_value / total) * 100).round(2).to_f
  end
end
