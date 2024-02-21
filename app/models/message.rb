class Message < ApplicationRecord
  belongs_to :chat_thread

  enum sender: {
    user: 0,
    assistant: 1,
    system: 2
  }


end
