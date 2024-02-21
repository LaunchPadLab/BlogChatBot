import React, { useState, useRef, useEffect } from "react"
import PropTypes from "prop-types"
import ActionCable from "actioncable";
import axios from 'axios';

function Chat({ chat_threads }) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
  axios.defaults.headers.common['X-CSRF-Token'] = csrfToken;

  const [messages, setMessages] = useState([])
  const [chatThreads, setChatThreads] = useState(chat_threads)
  const [currentChatThread, setCurrentChatThread] = useState(null)
  const chatboxRef = useRef(null)
  const [assistantMessage, setAssistantMessage] = useState('')
  const cableRef = useRef(null);
  const [isAssistantTyping, setIsAssistantTyping] = useState(false)

  useEffect(() => {
    cableRef.current = ActionCable.createConsumer()

    return () => {
      if (cableRef.current) {
        cableRef.current.disconnect();
      }
    };
  }, []);

  useEffect(() => {
    if (!isAssistantTyping && assistantMessage) {
      setMessages(prevMessages => [...prevMessages, { sender: 'assistant', content: assistantMessage }])
      setAssistantMessage('')
    }
  }, [isAssistantTyping, assistantMessage])

  function createSubscription(channel, room, onReceived) {
    return new Promise((resolve, reject) => {
      const subscription = cableRef.current.subscriptions.create({ channel, room }, {
        connected() {
          console.log('connected')
          resolve(subscription);
        },
        received(data) {
          onReceived(data);
        }
      });
    });
  }

  async function sendMessage() {
    const value = chatboxRef.current.value
    if (!value) return
    setMessages(prevMessages => [...prevMessages, { sender: 'user', content: value }])
    chatboxRef.current.value = '';
    const uuid = Math.random().toString(36).substring(5)
    setIsAssistantTyping(true)

    const messageBuffer = {}
    let expectedIndex = 1;

    const subscription = await createSubscription('ChatChannel', uuid, (data) => {
      if (!data?.content) return
      const { index, content } = data;
      messageBuffer[index] = content;
      handleAssistantChunk();
    });

    const response = await axios.post('/send_message', {
      content: value,
      room: uuid,
      chat_thread_id: currentChatThread?.id
    })

    setCurrentChatThread(response.data)
    setIsAssistantTyping(false)

    function handleAssistantChunk() {
      let message = '';
      let currentExpectedIndex = expectedIndex;
      while (messageBuffer.hasOwnProperty(currentExpectedIndex)) {
        message += messageBuffer[currentExpectedIndex];
        delete messageBuffer[currentExpectedIndex];
        currentExpectedIndex++;
      }

      if (message) {
        setAssistantMessage(prevSummary => prevSummary + message);
      }

      expectedIndex = currentExpectedIndex;
    }
  }



  async function getMessages(chatThreadId) {
    // fetch messages from the server
    const messages = await axios.get(`/get_messages?chat_thread_id=${chatThreadId}`)
    console.log(messages)
    setMessages(messages)
  }

  function onChatThreadClick(chatThread) {
    setCurrentChatThread(chatThread)
    getMessages(chatThread.id)
  }

  return (
    <div className="flex h-screen">
      <div className="w-1/4 bg-gray-800 text-white overflow-auto">
        {chatThreads.map((chatThread, index) => (
          <div
            key={index}
            onClick={() => onChatThreadClick(chatThread)}
            className="p-4 hover:bg-gray-700 cursor-pointer"
          >
            <p>{chatThread.title}</p>
          </div>
        ))}
      </div>
      <div className="flex-1 flex flex-col">
        <div className="flex-1 overflow-auto">
          {messages.map((message, index) => (
            <div
              key={index}
              className={`p-4 m-2 rounded-lg ${
                message.sender === 'assistant' ? 'bg-blue-500 text-white' : 'bg-gray-200 text-gray-800'
              }`}
            >
              <p>{message.content}</p>
            </div>
          ))}
          {
            assistantMessage && (
              <div className="p-4 m-2 rounded-lg bg-blue-500 text-white">
                <p>{assistantMessage}</p>
              </div>
            )
          }
        </div>
        <div className="p-4 flex items-center">
          <textarea
            className="w-full mr-2 p-2 rounded border border-gray-300"
            placeholder="Type your message here"
            ref={chatboxRef}
          />
          <button
            onClick={sendMessage}
            className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
          >
            Send
          </button>
        </div>
      </div>
    </div>
  );
}


export default Chat
