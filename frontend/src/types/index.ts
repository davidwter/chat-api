export interface Message {
    id: string;
    content: string;
    isUser: boolean;
    timestamp: number;
    status: 'sending' | 'sent' | 'failed';
    type: 'text' | 'system' | 'error';
    conversationId: string;
    connectors?: Array<{
        name: string;
        categories?: string[];
        confidenceScore?: number;
    }>;
}

export interface Conversation {
    id: string;
    title: string;
    created_at: string;
    updated_at: string;
    status: 'active' | 'archived';
    last_message?: string;
}