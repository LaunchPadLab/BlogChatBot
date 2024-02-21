Rails.application.routes.draw do
  root to: 'chats#chat'

  get 'chat', to: 'chats#chat'
  get 'get_chat_threads', to: 'chats#get_chat_threads'
  get 'get_messages', to: 'chats#get_messages'
  post 'send_message', to: 'chats#send_message'
  delete 'delete_chat_thread', to: 'chats#delete_chat_thread'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  mount ActionCable.server => '/cable'
end
