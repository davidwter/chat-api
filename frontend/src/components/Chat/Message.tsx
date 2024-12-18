import React from 'react';
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
                return '⚪';
            case 'sent':
                return '✓';
            case 'failed':
                return '⚠';
            default:
                return '';
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
        <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
            <div className="max-w-[80%] group">
                <div
                    className={`px-4 py-2.5 rounded-2xl shadow-sm
                        ${getMessageStyle()}
                        ${isUser ? 'rounded-br-md' : 'rounded-bl-md'}
                    `}
                >
                    <p className="whitespace-pre-wrap break-words text-[15px]">{content}</p>
                </div>
                <div className={`flex items-center gap-2 mt-1 text-xs text-gray-400
                    ${isUser ? 'justify-end' : 'justify-start'}`
                }>
                    <span>{formatTime(timestamp)}</span>
                    {isUser && status && (
                        <span className={`
                            ${status === 'failed' ? 'text-red-500' : ''}
                            ${status === 'sending' ? 'animate-pulse' : ''}
                        `}>
                            {getStatusIcon()}
                        </span>
                    )}
                </div>
            </div>
        </div>
    );
};

export default Message;