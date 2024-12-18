import React, { useState } from 'react';
import { Send } from 'lucide-react';

interface ChatInputProps {
    onSendMessage: (message: string) => void;
    isLoading: boolean;
}

const ChatInput: React.FC<ChatInputProps> = ({ onSendMessage, isLoading }) => {
    const [inputMessage, setInputMessage] = useState('');

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (inputMessage.trim() && !isLoading) {
            onSendMessage(inputMessage.trim());
            setInputMessage('');
        }
    };

    const handleKeyPress = (e: React.KeyboardEvent) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSubmit(e as unknown as React.FormEvent);
        }
    };

    return (
        <form onSubmit={handleSubmit} className="px-4 md:px-6 py-4">
            <div className="flex items-center gap-3">
                <input
                    type="text"
                    value={inputMessage}
                    onChange={(e) => setInputMessage(e.target.value)}
                    onKeyDown={handleKeyPress}
                    placeholder="Type your message..."
                    className="flex-1 px-4 py-3 bg-gray-50 rounded-xl border border-gray-200
                             focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent
                             placeholder:text-gray-400 text-gray-600"
                    disabled={isLoading}
                />
                <button
                    type="submit"
                    disabled={!inputMessage.trim() || isLoading}
                    className="p-3 rounded-xl bg-blue-600 text-white hover:bg-blue-700
                             disabled:bg-gray-200 disabled:text-gray-400 disabled:cursor-not-allowed
                             transition-colors duration-200"
                >
                    <Send className="w-5 h-5" />
                </button>
            </div>
        </form>
    );
};

export default ChatInput;