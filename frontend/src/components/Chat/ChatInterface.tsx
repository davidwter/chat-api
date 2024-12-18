import React from 'react';
import Message from './Message';
import ChatInput from './ChatInput';
import { useChat } from '../../hooks/useChat';

const ChatInterface: React.FC = () => {
    const { messages, isLoading, error, sendMessage } = useChat();

    return (
        <div className="flex flex-col h-screen max-w-2xl mx-auto">
            {/* Chat header */}
            <div className="bg-white border-b p-4">
                <h1 className="text-xl font-semibold text-gray-800">Integration Assistant</h1>
                {error && (
                    <div className="mt-2 text-sm text-red-500">
                        {error}
                    </div>
                )}
            </div>

            {/* Messages container */}
            <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50">
                {messages.map((message, index) => (
                    <Message key={index} {...message} />
                ))}
                {isLoading && (
                    <div className="flex justify-start">
                        <div className="bg-gray-200 p-3 rounded-lg rounded-bl-none">
                            <span className="flex space-x-1">
                                <span className="animate-pulse">•</span>
                                <span className="animate-pulse delay-100">•</span>
                                <span className="animate-pulse delay-200">•</span>
                            </span>
                        </div>
                    </div>
                )}
            </div>

            {/* Input form */}
            <ChatInput onSendMessage={sendMessage} isLoading={isLoading} />
        </div>
    );
};

export default ChatInterface;