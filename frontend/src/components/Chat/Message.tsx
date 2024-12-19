import React from 'react';
import { Check, AlertCircle, Link } from 'lucide-react';

const Message = ({ content, isUser, timestamp, status, type, connectors = [] }) => {
    console.log('Message props:', { content, isUser, connectors }); // Debug log

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

    const formatContent = (text) => {
        if (!text) return '';
        console.log('Formatting text:', text); // Debug log

        // Replace markdown with HTML
        const parts = text.split(/(\*\*[^*]+\*\*)/g);
        return parts.map((part, index) => {
            if (part.startsWith('**') && part.endsWith('**')) {
                const connectorName = part.slice(2, -2);
                return (
                    <strong
                        key={index}
                        className={isUser ? 'text-white' : 'text-blue-600'}
                    >
                        {connectorName}
                    </strong>
                );
            }
            return <span key={index}>{part}</span>;
        });
    };

    const formatTime = (timestamp) => {
        return new Date(timestamp).toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
        });
    };

    return (
        <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} group`}>
            <div className="max-w-[80%]">
                <div className={`px-4 py-2.5 rounded-2xl shadow-sm ${getMessageStyle()} 
                    ${isUser ? 'rounded-br-md' : 'rounded-bl-md'}`}
                >
                    <div className="whitespace-pre-wrap break-words text-[15px] leading-relaxed">
                        {formatContent(content)}
                    </div>

                    {/* Connector Mentions */}
                    {connectors && connectors.length > 0 && (
                        <div className={`mt-2 pt-2 border-t ${
                            isUser ? 'border-white/20' : 'border-gray-200'
                        }`}>
                            <div className="flex items-center gap-1 text-sm">
                                <Link className={`w-4 h-4 ${
                                    isUser ? 'text-white/70' : 'text-gray-600'
                                }`} />
                                <span className={`font-medium ${
                                    isUser ? 'text-white/70' : 'text-gray-600'
                                }`}>
                                    Connected Apps:
                                </span>
                            </div>
                            <div className="mt-1 flex flex-wrap gap-2">
                                {connectors.map((connector, index) => (
                                    <div
                                        key={index}
                                        className={`inline-flex items-center rounded-full px-2 py-1 text-xs font-medium
                                            ${isUser
                                            ? 'bg-white/20 text-white'
                                            : 'bg-blue-50 text-blue-700'
                                        }`}
                                    >
                                        {connector.name}
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}
                </div>

                <div className={`flex items-center gap-2 mt-1 px-1 ${
                    isUser ? 'justify-end' : 'justify-start'
                }`}>
                    <span className="text-xs text-gray-400">
                        {formatTime(timestamp)}
                    </span>
                    {isUser && status && (
                        <span className="opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                            {status === 'sending' && (
                                <div className="w-3 h-3 bg-gray-400 rounded-full animate-pulse" />
                            )}
                            {status === 'sent' && <Check className="w-4 h-4 text-gray-400" />}
                            {status === 'failed' && <AlertCircle className="w-4 h-4 text-red-500" />}
                        </span>
                    )}
                </div>
            </div>
        </div>
    );
};

export default Message;