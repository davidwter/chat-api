import React from 'react';
import { Plus, MessageSquare } from 'lucide-react';
import type { Conversation } from '../types';

interface ConversationListProps {
    conversations: Conversation[];
    currentConversationId: string | null;
    onSelectConversation: (id: string) => void;
    onNewConversation: () => void;
}

const ConversationList: React.FC<ConversationListProps> = ({
                                                               conversations,
                                                               currentConversationId,
                                                               onSelectConversation,
                                                               onNewConversation,
                                                           }) => {
    return (
        <div className="w-64 bg-gray-50 border-r border-gray-200 h-full flex flex-col">
            <div className="p-4">
                <button
                    onClick={onNewConversation}
                    className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-blue-600
                   text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                    <Plus className="w-4 h-4" />
                    <span>New Chat</span>
                </button>
            </div>

            <div className="flex-1 overflow-y-auto">
                {conversations.map((conversation) => (
                    <button
                        key={conversation.id}
                        onClick={() => onSelectConversation(conversation.id)}
                        className={`w-full px-4 py-3 flex items-center gap-3 hover:bg-gray-100 
                     transition-colors text-left ${
                            currentConversationId === conversation.id ? 'bg-gray-100' : ''
                        }`}
                    >
                        <MessageSquare className="w-5 h-5 text-gray-500" />
                        <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium text-gray-900 truncate">
                                {conversation.title || 'New Conversation'}
                            </p>
                            <p className="text-xs text-gray-500 truncate">
                                {new Date(conversation.created_at).toLocaleDateString()}
                            </p>
                        </div>
                    </button>
                ))}
            </div>
        </div>
    );
};

export default ConversationList;