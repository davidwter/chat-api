import React from 'react';
import Message from './Message';
import ChatInput from './ChatInput';
import { useChat } from '../../hooks/useChat';
import { Message as MessageType } from '../types';

const ChatInterface: React.FC = () => {
    const { messages, isLoading, error, sendMessage } = useChat();

    return (
        <div className="flex flex-col h-screen bg-gray-50">
            {/* Chat container with max width and shadow */}
            <div className="flex flex-col max-w-4xl w-full mx-auto h-full bg-white shadow-xl">
                {/* Header */}
                <div className="bg-gradient-to-r from-blue-600 to-blue-700 px-6 py-4 shadow-md">
                    <h1 className="text-2xl font-bold text-white">Integration Assistant</h1>
                    {error && (
                        <div className="mt-2 px-4 py-2 bg-red-500 bg-opacity-20 border border-red-200 rounded-lg text-white text-sm">
                            {error}
                        </div>
                    )}
                </div>

                {/* Messages area with improved spacing */}
                <div className="flex-1 overflow-y-auto px-4 md:px-6 py-6 space-y-6">
                    {messages.map((message: MessageType) => (
                        <Message key={message.id} {...message} />
                    ))}
                    {isLoading && (
                        <div className="flex justify-start">
                            <div className="bg-gray-100 px-4 py-3 rounded-2xl rounded-bl-none shadow-sm">
                                <div className="flex space-x-2">
                                    <div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce"></div>
                                    <div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce delay-150"></div>
                                    <div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce delay-300"></div>
                                </div>
                            </div>
                        </div>
                    )}
                </div>

                {/* Input area with shadow separation */}
                <div className="border-t bg-white shadow-lg">
                    <ChatInput onSendMessage={sendMessage} isLoading={isLoading} />
                </div>
            </div>
        </div>
    );
};

export default ChatInterface;