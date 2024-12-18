import { useState, useEffect } from 'react';

interface Message {
    id: string;
    content: string;
    isUser: boolean;
    timestamp: number;
    status: 'sending' | 'sent' | 'failed';
    type: 'text' | 'system' | 'error';
}

export const useChat = () => {
    // Load initial messages from localStorage if they exist
    const [messages, setMessages] = useState<Message[]>(() => {
        const saved = localStorage.getItem('chatMessages');
        return saved ? JSON.parse(saved) : [{
            id: '1',
            content: 'Hello! How can I help you with integration?',
            isUser: false,
            timestamp: Date.now(),
            status: 'sent',
            type: 'text'
        }];
    });

    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Save messages to localStorage whenever they change
    useEffect(() => {
        localStorage.setItem('chatMessages', JSON.stringify(messages));
    }, [messages]);

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
            const response = await fetch('http://localhost:3000/api/v1/chat', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ message: content })
            });

            if (!response.ok) {
                throw new Error('Network response was not ok');
            }

            const data = await response.json();

            // Update user message status to 'sent'
            setMessages(prev =>
                prev.map(msg =>
                    msg.id === messageId
                        ? { ...msg, status: 'sent' as const }
                        : msg
                )
            );

            // Add bot response
            const botMessage: Message = {
                id: (Date.now() + 1).toString(),
                content: data.message,
                isUser: false,
                timestamp: Date.now(),
                status: 'sent',
                type: 'text'
            };

            setMessages(prev => [...prev, botMessage]);

        } catch (err) {
            setError('Failed to send message');
            console.error('Chat API Error:', err);

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

    const clearHistory = () => {
        setMessages([{
            id: Date.now().toString(),
            content: 'Hello! How can I help you with integration?',
            isUser: false,
            timestamp: Date.now(),
            status: 'sent',
            type: 'text'
        }]);
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