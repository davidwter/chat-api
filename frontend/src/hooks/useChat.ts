// hooks/useChat.ts
import { useState, useEffect } from 'react';
import type { Message } from '../types';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

export const useChat = () => {
    const [messages, setMessages] = useState<Message[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Fetch initial messages
    useEffect(() => {
        const fetchMessages = async () => {
            try {
                const response = await fetch(`${API_URL}/api/v1/messages`);
                if (!response.ok) throw new Error('Failed to fetch messages');

                const data = await response.json();
                setMessages(data.messages);
            } catch (err) {
                console.error('Failed to fetch messages:', err);
                setError('Failed to load message history');
            }
        };

        fetchMessages();
    }, []);

    const sendMessage = async (content: string) => {
        const messageId = Date.now().toString();

        try {
            setIsLoading(true);
            setError(null);

            // Add user message immediately with 'sending' status
            const userMessage: Message = {
                id: messageId,
                content,
                isUser: true,
                timestamp: Date.now(),
                status: 'sending',
                type: 'text'
            };

            setMessages(prev => [...prev, userMessage]);

            // Send to backend
            const response = await fetch(`${API_URL}/api/v1/messages`, {
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
            });

            if (!response.ok) {
                throw new Error('Network response was not ok');
            }

            const data = await response.json();

            // Update messages with both user message and bot response
            setMessages(prev => [
                ...prev.filter(msg => msg.id !== messageId), // Remove temporary message
                data.message,    // Add confirmed user message
                data.response   // Add bot response
            ]);

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
                type: 'error'
            };

            setMessages(prev => [...prev, errorMessage]);
        } finally {
            setIsLoading(false);
        }
    };

    const clearHistory = async () => {
        setMessages([]);
        try {
            await fetch(`${API_URL}/api/v1/messages`);
        } catch (err) {
            console.error('Failed to clear history:', err);
        }
    };

    return {
        messages,
        isLoading,
        error,
        sendMessage,
        clearHistory,
    };
};

export default useChat;