module Portfolio
  # Builds the portfolio dashboard payload: every asset (with its share of its asset type) and the
  # asset type labels. The frontend computes the allocation by type from the assets.
  class Dashboard
    def self.call
      new.call
    end

    def call
      assets = Asset.order(:id).to_a
      totals_by_type = assets.group_by(&:asset_type).transform_values { |group| group.sum { |asset| asset.current_value || 0 } }

      {
        assets: assets.map { |asset| AssetPresenter.new(asset, total_by_type: totals_by_type[asset.asset_type]).as_json },
        asset_types: Asset::ASSET_TYPES
      }
    end
  end
end
