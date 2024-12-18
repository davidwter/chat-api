import React from 'react';
import { Check, AlertCircle } from 'lucide-react';
import { Message as MessageType } from '../types';

const Message: React.FC<MessageType> = ({ content, isUser, timestamp, status, type }) => {
    const getMessageStyle = () => {
        if (isUser) {
            return 'bg-blue-600 text-white';
        }
        switch (type) {
            case 'error':
                return 'bg-red-50 text-red-600 border border-red-100';
            case 'system':
                return 'bg-gray-100 text-gray-600 border border-gray-200';
            default:
                return 'bg-white text-gray-800 border border-gray-200';
        }
    };

    const getStatusIcon = () => {
        switch (status) {
            case 'sending':
                return <div className="w-3 h-3 bg-gray-400 rounded-full animate-pulse" />;
            case 'sent':
                return <Check className="w-4 h-4 text-gray-400" />;
            case 'failed':
                return <AlertCircle className="w-4 h-4 text-red-500" />;
            default:
                return null;
        }
    };

    const formatTime = (timestamp: number) => {
        const date = new Date(timestamp);
        return date.toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
        });
    };

    return (
        <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} group`}>
            <div className="max-w-[80%]">
                <div
                    className={`px-4 py-2.5 rounded-2xl shadow-sm
                        ${getMessageStyle()}
                        ${isUser ? 'rounded-br-md' : 'rounded-bl-md'}
                    `}
                >
                    <p className="whitespace-pre-wrap break-words text-[15px] leading-relaxed">
                        {content}
                    </p>
                </div>
                <div className={`flex items-center gap-2 mt-1 px-1
                    ${isUser ? 'justify-end' : 'justify-start'}`
                }>
                    <span className="text-xs text-gray-400">
                        {formatTime(timestamp)}
                    </span>
                    {isUser && status && (
                        <span className="opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                            {getStatusIcon()}
                        </span>
                    )}
                </div>
            </div>
        </div>
    );
};

export default Message;