class CreateSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :summaries do |t|
      t.string :source_url, null: false
      t.string :status, null: false, default: "pending"
      t.text :error
      t.string :audio_path
      t.json :segments
      t.text :summary

      t.timestamps
    end
    add_index :summaries, :created_at
  end
end
