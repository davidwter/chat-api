// src/types/index.ts
export interface Message {
    id: string;
    content: string;
    isUser: boolean;
    timestamp: number;
    status: 'sending' | 'sent' | 'failed';
    type: 'text' | 'system' | 'error';
}