import { useState, useEffect } from 'react';
import type { Message, Conversation } from '../types';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

export const useChat = () => {
    const [messages, setMessages] = useState<Message[]>([]);
    const [conversations, setConversations] = useState<Conversation[]>([]);
    const [currentConversationId, setCurrentConversationId] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Fetch conversations
    useEffect(() => {
        const fetchConversations = async () => {
            try {
                const response = await fetch(`${API_URL}/api/v1/conversations`);
                if (!response.ok) throw new Error('Failed to fetch conversations');

                const data = await response.json();
                setConversations(data.conversations);

                // Set the most recent conversation as current if none selected
                if (!currentConversationId && data.conversations.length > 0) {
                    setCurrentConversationId(data.conversations[0].id);
                }
            } catch (err) {
                console.error('Failed to fetch conversations:', err);
                setError('Failed to load conversations');
            }
        };

        fetchConversations();
    }, []);

    // Fetch messages for current conversation
    useEffect(() => {
        const fetchMessages = async () => {
            if (!currentConversationId) return;

            try {
                const response = await fetch(
                    `${API_URL}/api/v1/conversations/${currentConversationId}/messages`
                );
                if (!response.ok) throw new Error('Failed to fetch messages');

                const data = await response.json();
                setMessages(data.messages);
            } catch (err) {
                console.error('Failed to fetch messages:', err);
                setError('Failed to load messages');
            }
        };

        fetchMessages();
    }, [currentConversationId]);

    const createConversation = async () => {
        try {
            const response = await fetch(`${API_URL}/api/v1/conversations`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
            });

            if (!response.ok) throw new Error('Failed to create conversation');

            const data = await response.json();
            setConversations(prev => [data.conversation, ...prev]);
            setCurrentConversationId(data.conversation.id);
        } catch (err) {
            console.error('Failed to create conversation:', err);
            setError('Failed to create new conversation');
        }
    };

    const selectConversation = (conversationId: string) => {
        setCurrentConversationId(conversationId);
    };

    const sendMessage = async (content: string) => {
        if (!currentConversationId) return;

        const messageId = Date.now().toString();

        try {
            // Set loading state BEFORE making the API call
            setIsLoading(true);
            setError(null);

            // Add user message immediately with 'sending' status
            const userMessage: Message = {
                id: messageId,
                content,
                isUser: true,
                timestamp: Date.now(),
                status: 'sending',
                type: 'text',
                conversationId: currentConversationId
            };

            setMessages(prev => [...prev, userMessage]);

            // Send to backend
            const response = await fetch(
                `${API_URL}/api/v1/conversations/${currentConversationId}/messages`,
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        message: {
                            content,
                            message_type: 'text'
                        }
                    }),
                    credentials: 'include'
                }
            );

            if (!response.ok) {
                throw new Error('Network response was not ok');
            }

            const data = await response.json();

            // Update messages with both user message and bot response
            setMessages(prev => [
                ...prev.filter(msg => msg.id !== messageId),
                data.message,    // Add confirmed user message
                data.response   // Add bot response
            ]);

            // Update conversation list
            setConversations(prev =>
                prev.map(conv =>
                    conv.id === currentConversationId
                        ? { ...conv, last_message: content }
                        : conv
                )
            );

        } catch (err) {
            console.error('Chat API Error:', err);
            setError('Failed to send message');

            // Update message status to 'failed'
            setMessages(prev =>
                prev.map(msg =>
                    msg.id === messageId
                        ? { ...msg, status: 'failed' as const }
                        : msg
                )
            );

            // Add system error message
            const errorMessage: Message = {
                id: (Date.now() + 2).toString(),
                content: 'Sorry, there was an error processing your message. Please try again.',
                isUser: false,
                timestamp: Date.now(),
                status: 'sent',
                type: 'error',
                conversationId: currentConversationId
            };

            setMessages(prev => [...prev, errorMessage]);
        } finally {
            // Make sure to set loading state to false after everything is done
            setIsLoading(false);
        }
    };

    return {
        messages,
        conversations,
        currentConversationId,
        isLoading,
        error,
        sendMessage,
        createConversation,
        selectConversation,
    };
};

export default useChat;