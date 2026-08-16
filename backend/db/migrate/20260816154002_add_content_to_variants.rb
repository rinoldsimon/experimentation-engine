class AddContentToVariants < ActiveRecord::Migration[7.2]
  def change
    # Optional variant copy (e.g. a headline) + its provenance -- see
    # VariantContentGenerator. content_source: manual | llm | llm_fallback.
    add_column :variants, :content, :text
    add_column :variants, :content_source, :string, default: "manual", null: false
  end
end
