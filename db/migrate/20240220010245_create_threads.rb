class CreateThreads < ActiveRecord::Migration[7.1]
  def change
    create_table :chat_threads do |t|
      t.string :title

      t.timestamps
    end
  end
end
