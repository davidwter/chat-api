import React from 'react';

interface LoadingDotsProps {
    variant?: 'light' | 'dark';
}

const LoadingDots: React.FC<LoadingDotsProps> = ({ variant = 'dark' }) => {
    return (
        <div className="flex space-x-2 p-4">
            <div className={`w-2 h-2 rounded-full ${variant === 'light' ? 'bg-white' : 'bg-blue-600'} animate-bounce`} />
            <div className={`w-2 h-2 rounded-full ${variant === 'light' ? 'bg-white' : 'bg-blue-600'} animate-bounce [animation-delay:0.2s]`} />
            <div className={`w-2 h-2 rounded-full ${variant === 'light' ? 'bg-white' : 'bg-blue-600'} animate-bounce [animation-delay:0.4s]`} />
        </div>
    );
};

const LoadingMessage = () => {
    return (
        <div className="flex justify-start">
            <div className="bg-white rounded-2xl rounded-bl-none shadow-sm border border-gray-100">
                <LoadingDots />
            </div>
        </div>
    );
};

export default LoadingMessage;