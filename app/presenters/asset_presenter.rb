# app/presenters/category_presenter.rb
class AssetPresenter
  def initialize(asset)
    @asset = asset
  end

  def as_json(_options = {})
    {
      id:           @asset.id,
      asset_type:   @asset.asset_type,
      ticker:       @asset.ticker,
      description:  @asset.description,
      current_value: @asset.current_value.to_f,
      rating:       @asset.rating,
      quantity:     @asset.quantity,
      percent_by_type: percent_by_type,
      color_code:   @asset.color_code
    }
  end

  def percent_by_type
    total_by_type = Asset.where(asset_type: @asset.asset_type).sum(:current_value)
    return 0 if total_by_type <= 0 || total_by_type.nil?

    ((@asset.current_value / total_by_type) * 100).round(2)
  end
end
