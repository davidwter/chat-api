import { useState } from 'react';
import { api } from '../services/api.ts'; // Add .ts extension explicitly

interface Message {
    content: string;
    isUser: boolean;
}

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

            // For testing without backend
            await new Promise(resolve => setTimeout(resolve, 1000));
            const botMessage: Message = {
                content: `Received your message: ${content}`,
                isUser: false
            };
            setMessages(prev => [...prev, botMessage]);

            /* Uncomment when backend is ready
            // Send message to API
            const response = await api.chat.sendMessage(content);

            // Add bot response
            const botMessage: Message = {
              content: response.message || response.content,
              isUser: false
            };
            setMessages(prev => [...prev, botMessage]);
            */

        } catch (err) {
            setError('Failed to send message');
            console.error(err);
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