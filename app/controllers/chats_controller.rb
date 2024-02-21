class ChatsController < ApplicationController
  def chat
    @chat_threads = ChatThread.all
  end

  def get_chat_threads
    render json: ChatThread.all
  end

  def get_messages
    messages = ChatThread.find(params[:chat_thread_id]).messages.where(sender: [:user, :assistant])
    #TODO: Shape messages
    render json: messages
  end

  def send_message
    chat_thread = ChatThread.find_or_create_by(id: params[:chat_thread_id])
    previous_messages = chat_thread.messages.where(sender: [:user, :assistant])

    ai_service = AiChatService.new(message: params[:content], previous_messages: previous_messages)
    ai_service.stream_response do |chunk, finish_reason, index|
      ActionCable.server.broadcast "chat_#{params[:room]}", { content: chunk, index: index }
    end
    ai_service.log_chat_messages(chat_thread)

    render json: chat_thread
  end

  def delete_chat_thread
    chat_thread = ChatThread.find(params[:id])
    chat_thread.destroy
  end
end
