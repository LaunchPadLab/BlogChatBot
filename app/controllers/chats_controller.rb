class ChatsController < ApplicationController
  def chat
    @chat_threads = ChatThread.all.order(created_at: :desc)
  end

  def get_chat_threads
    render json: ChatThread.all
  end

  def get_messages
    messages = ChatThread.find(params[:chat_thread_id]).messages.where(sender: [:user, :assistant]).order(created_at: :asc)
    render json: messages
  end

  def send_message
    chat_thread = ChatThread.find_or_create_by(id: params[:chat_thread_id])
    previous_messages = chat_thread.messages.where(sender: [:user, :assistant]) # Get previous messages from the database, if any

    ai_service = AiChatService.new(message: params[:content], previous_messages: previous_messages)

    #broadcast each chunk to the client
    ai_service.stream_response do |chunk, index|
      ActionCable.server.broadcast "chat_#{params[:room]}", { content: chunk, index: index }
    end

    ai_service.log_chat_messages(chat_thread) # Store chat messages in the database
    ai_service.generate_chat_title(chat_thread)
    ai_service.close_connections

    render json: chat_thread
  end

  def delete_chat_thread
    chat_thread = ChatThread.find(params[:id])
    chat_thread.destroy
  end
end
