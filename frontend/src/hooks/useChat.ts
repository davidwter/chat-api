import { useState } from 'react';

interface Message {
    content: string;
    isUser: boolean;
}

interface ApiResponse {
    message: string;
    status: number;
}

const API_BASE_URL = 'http://localhost:3000'; // Rails backend URL

export const useChat = () => {
    const [messages, setMessages] = useState<Message[]>([
        { content: 'Hello! How can I help you with integration?', isUser: false }
    ]);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const sendMessage = async (content: string) => {
        try {
            setIsLoading(true);
            setError(null);

            // Add user message immediately
            const userMessage: Message = { content, isUser: true };
            setMessages(prev => [...prev, userMessage]);

            // Send message to Ruby API using the correct backend URL
            const response = await fetch(`${API_BASE_URL}/api/v1/chat`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                body: JSON.stringify({
                    message: content
                })
            });

            if (!response.ok) {
                throw new Error('Network response was not ok');
            }

            const data: ApiResponse = await response.json();

            // Add bot response
            const botMessage: Message = {
                content: data.message,
                isUser: false
            };
            setMessages(prev => [...prev, botMessage]);

        } catch (err) {
            setError('Failed to send message');
            console.error('Chat API Error:', err);

            // Add error message to chat
            const errorMessage: Message = {
                content: 'Sorry, there was an error processing your message. Please try again.',
                isUser: false
            };
            setMessages(prev => [...prev, errorMessage]);
        } finally {
            setIsLoading(false);
        }
    };

    return {
        messages,
        isLoading,
        error,
        sendMessage,
    };
};

export default useChat;