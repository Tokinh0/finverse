module Profiles
  # Fills the current profile with the starting categories, subcategories (with their type and
  # color) and keyword rules from the seed file's `categories` (db/seed_data/defaults.jsonc).
  # Idempotent: what already exists (by parsed name) is kept as it is. It always makes sure the
  # "Outros"/"Outros" fallback exists, because imports need it.
  module DefaultData
    module_function

    def apply(data = JsonUtils.load_initial_data)
      categories = data["categories"]
      raise ArgumentError, "The seed file has no \"categories\" (see db/seed_data/defaults.jsonc)" if categories.blank?

      categories.each do |category_data|
        category = find_or_create(Category.all, category_data["name"], color_code: category_data["color_code"])
        (category_data["subcategories"] || []).each do |subcategory_data|
          subcategory = find_or_create(category.subcategories, subcategory_data["name"],
                                       color_code: subcategory_data["color_code"],
                                       subcategory_type: subcategory_data["type"] || "expense")
          (subcategory_data["keywords"] || []).each { |name| find_or_create(subcategory.keywords, name) }
        end
      end
      ensure_fallback
    end

    def ensure_fallback
      category = Category.other_category || Category.create!(name: "Outros")
      return if category.subcategories.exists?(parsed_name: Subcategory::FALLBACK_NAME)

      category.subcategories.create!(name: "Outros", subcategory_type: "expense")
    end

    def find_or_create(scope, name, **attributes)
      scope.find_by(parsed_name: StringUtils.default_string_parse(name)) || scope.create!(name: name, **attributes)
    end
  end
end
