import React from 'react';

interface MessageProps {
    content: string;
    isUser: boolean;
}

const Message: React.FC<MessageProps> = ({ content, isUser }) => (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} mb-4`}>
        <div
            className={`max-w-3/4 p-3 rounded-lg ${
                isUser
                    ? 'bg-blue-500 text-white rounded-br-none'
                    : 'bg-gray-200 text-gray-800 rounded-bl-none'
            }`}
        >
            {content}
        </div>
    </div>
);

export default Message;