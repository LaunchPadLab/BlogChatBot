class AiChatService
  attr_reader :message, :current_user_id, :previous_messages, :assistant_response

  def initialize(message:, previous_messages: [])
    @message = message
    @previous_messages = format_messages(previous_messages)
    @assistant_response = ''
  end

  def stream_response(&block)
    @system_prompt = previous_messages.empty? ? generate_initial_prompt : generate_follow_up_system_prompt

    new_messages = [
      {
        role: "system",
        content: @system_prompt
      },
      {
        role: "user",
        content: message
      }
    ]

    openai_messages = previous_messages.empty? ? new_messages : previous_messages.concat(new_messages)

    index = 0
    response_handler = Proc.new do |response|
      content_of_response = response['delta']['content']
      @assistant_response += content_of_response if content_of_response
      block.call(content_of_response, index)
      index += 1
    end

    llm.chat(model: 'gpt-3.5-turbo', messages: openai_messages) do |chunk|
      response_handler.call(chunk)
    end
  end

  def log_chat_messages(chat_thread)
    system = {
      sender: "system",
      content: @system_prompt
    }

    user = {
      sender: "user",
      content: message
    }

    assistant = {
      sender: "assistant",
      content: @assistant_response,
    }

    chat_thread.messages.create!([system, user, assistant])
  end

  def generate_chat_title(chat_thread)
    return if chat_thread.title.present?
    title_message = [{ role: "system", content: title_prompt }]
    title = llm.chat(model: 'gpt-3.5-turbo', messages: title_message).completion
    chat_thread.update(title: title.gsub(/\A"|"\Z/, ''))
  end

  def close_connections
    # Always be closing!
    langchain.db.disconnect
  end

  private

  def format_messages(messages)
    messages.map do |message|
      {
        role: message[:sender],
        content: message[:content]
      }
    end
  end

  def generate_initial_prompt
    <<~PROMPT
      You are a helpful assistant designed to provide employees of Launchpad Lab (LPL) information gathered from the company's blog posts. 
      Your answers should be as thorough as needed, accurate, and based on the information available in the blog posts. 
      You'll only answer questions relevant to the user topic.
      Use markdown to format your response.
      Please use these resources to help answer the user's question, any irrelevant resources should not be used to craft your answer:"
      #{get_results}
    PROMPT
  end

  def generate_follow_up_system_prompt
    <<~PROMPT
      Use these additional resources to help you answer the user's question, if needed:"
       #{get_results}
    PROMPT
  end

  def title_prompt
    <<~PROMPT
      Based on the following exchange between a user and an AI assistant, what would you title this conversation? Please keep it short.
      User: #{message}
      Assistant: #{@assistant_response}
      Title:
    PROMPT
  end

  def get_results
    results = langchain.similarity_search(query: message, k: 6)
    results.pluck(:content).join("\n\n")
  end

  def langchain
    database_url = Rails.configuration.database_configuration[Rails.env]
    @langchain ||= Langchain::Vectorsearch::Pgvector.new(url: database_url, index_name: 'blog_embeddings', llm: llm)
  end

  def llm
    @llm ||= Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_KEY'])
  end

  def db_configuration
    Rails.configuration.database_configuration[Rails.env]["vector_db"]
  end
end
