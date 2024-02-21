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
      finish_reason = response['finish_reason']
      @assistant_response += content_of_response if content_of_response
      block.call(content_of_response, finish_reason, index)
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
    prompt = "You are a helpful assistant \n"
    # TODO
    #prompt + get_results
  end

  def generate_follow_up_system_prompt
    prompt = "Use these additional resources to help you answer the customer's question, if needed:\n"
    # TODO
    #prompt + get_results
  end

  def get_results
    results = langchain.similarity_search(query: message, k: 3)
    results.as_json.join("\n")
  end

  def langchain
    database_url = ENV['VECTOR_DATABASE_URL'] || { host: db_configuration["host"], port: 5432, adapter: :postgres, database: db_configuration["database"] }
    @langchain ||= Langchain::Vectorsearch::Pgvector.new(url: database_url, index_name: 'blog_index', llm: llm)
  end

  def llm
    @llm ||= Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_KEY'])
  end

  def db_configuration
    Rails.configuration.database_configuration[Rails.env]["vector_db"]
  end
end
