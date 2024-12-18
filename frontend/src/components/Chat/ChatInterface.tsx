import React, { useState } from 'react';
import Message from './Message';
import ChatInput from './ChatInput';
import ConversationList from './ConversationList';
import { useChat } from '../../hooks/useChat';
import { Message as MessageType, Conversation } from '../types';

const ChatInterface: React.FC = () => {
    const {
        messages,
        conversations,
        currentConversationId,
        isLoading,
        error,
        sendMessage,
        createConversation,
        selectConversation,
    } = useChat();

    const handleNewConversation = async () => {
        await createConversation();
    };

    return (
        <div className="flex h-screen overflow-hidden">
            {/* Fixed-width sidebar */}
            <div className="w-80 flex-shrink-0 border-r border-gray-200 bg-gray-50">
                {/* New Chat Button */}
                <div className="p-4 border-b border-gray-200">
                    <button
                        onClick={handleNewConversation}
                        className="w-full flex items-center justify-center gap-2 px-4 py-2.5
                                 bg-blue-600 text-white rounded-lg hover:bg-blue-700
                                 transition-colors duration-200"
                    >
                        <span className="text-lg">+</span>
                        <span className="font-medium">New Chat</span>
                    </button>
                </div>

                {/* Conversation List */}
                <div className="h-[calc(100vh-73px)] overflow-y-auto">
                    {conversations.map((conversation) => (
                        <button
                            key={conversation.id}
                            onClick={() => selectConversation(conversation.id)}
                            className={`w-full px-4 py-3 flex items-start gap-3 hover:bg-gray-100 
                                     transition-colors duration-200 border-b border-gray-100
                                     ${currentConversationId === conversation.id ? 'bg-white shadow-sm' : ''}`}
                        >
                            <div className="flex-shrink-0 w-8 h-8 flex items-center justify-center
                                          rounded-full bg-blue-100 text-blue-600">
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2"
                                          d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-4l-4 4-4-4z" />
                                </svg>
                            </div>
                            <div className="flex-1 min-w-0 text-left">
                                <h3 className="font-medium text-gray-900 truncate">
                                    {conversation.title || 'New Conversation'}
                                </h3>
                                <p className="text-sm text-gray-500 truncate mt-0.5">
                                    {new Date(conversation.created_at).toLocaleDateString()}
                                </p>
                            </div>
                        </button>
                    ))}
                </div>
            </div>

            {/* Main chat area */}
            <div className="flex-1 flex flex-col">
                {/* Header */}
                <div className="bg-white border-b border-gray-200 px-6 py-4">
                    <h1 className="text-xl font-semibold text-gray-900">
                        {currentConversationId
                            ? conversations.find(c => c.id === currentConversationId)?.title || 'New Conversation'
                            : 'Select or Start a Conversation'
                        }
                    </h1>
                    {error && (
                        <div className="mt-2 px-4 py-2 bg-red-50 border border-red-200
                                      rounded-lg text-red-600 text-sm">
                            {error}
                        </div>
                    )}
                </div>

                {/* Messages area */}
                <div className="flex-1 overflow-y-auto bg-gray-50 px-6 py-6">
                    {currentConversationId ? (
                        <div className="space-y-6 max-w-3xl mx-auto">
                            {messages
                                .filter(msg => msg.conversationId === currentConversationId)
                                .map((message: MessageType) => (
                                    <Message key={message.id} {...message} />
                                ))
                            }
                            {isLoading && (
                                <div className="flex justify-start">
                                    <div className="bg-white px-4 py-2 rounded-2xl rounded-bl-none
                                                  shadow-sm border border-gray-100">
                                        <div className="flex space-x-2">
                                            <div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce"></div>
                                            <div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce delay-150"></div>
                                            <div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce delay-300"></div>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>
                    ) : (
                        <div className="flex flex-col items-center justify-center h-full text-gray-500">
                            <svg className="w-16 h-16 mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2"
                                      d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                            </svg>
                            <p className="text-lg font-medium">Select a conversation or start a new one</p>
                        </div>
                    )}
                </div>

                {/* Input area */}
                <div className="bg-white border-t border-gray-200">
                    <div className="max-w-3xl mx-auto">
                        <ChatInput
                            onSendMessage={sendMessage}
                            isLoading={isLoading}
                            disabled={!currentConversationId}
                        />
                    </div>
                </div>
            </div>
        </div>
    );
};

export default ChatInterface;