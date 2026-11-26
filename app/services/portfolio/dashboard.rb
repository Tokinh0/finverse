module Portfolio
  # Builds the portfolio dashboard payload: every asset plus its allocation by asset type.
  class Dashboard
    def self.call
      new.call
    end

    def call
      assets = Asset.order(:id).to_a
      totals_by_type = assets.group_by(&:asset_type).transform_values { |group| total(group) }

      {
        assets: assets.map { |asset| AssetPresenter.new(asset, total_by_type: totals_by_type[asset.asset_type]).as_json },
        asset_types: Asset::ASSET_TYPES,
        portfolioData: allocation(assets, totals_by_type)
      }
    end

    private

    def allocation(assets, totals_by_type)
      portfolio_total = totals_by_type.values.sum

      assets.group_by(&:asset_type).map do |asset_type, group|
        value = totals_by_type[asset_type]
        {
          name: asset_type,
          value: value.to_f,
          percentage: "#{percentage(value, portfolio_total)}%",
          color: group.first.color_code
        }
      end
    end

    def total(assets)
      assets.sum { |asset| asset.current_value || 0 }
    end

    def percentage(value, total)
      return 0 unless total.positive?

      ((value / total) * 100).round(2)
    end
  end
end
