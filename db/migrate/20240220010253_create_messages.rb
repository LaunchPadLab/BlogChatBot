class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.string :content
      t.references :chat_thread, null: false, foreign_key: true
      t.integer :sender

      t.timestamps
    end
  end
end
