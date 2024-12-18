const API_URL = import.meta.env.VITE_API_URL;

export const api = {
  get: async (endpoint: string) => {
    const response = await fetch(`${API_URL}${endpoint}`);
    return response.json();
  },

  post: async (endpoint: string, data: any) => {
    const response = await fetch(`${API_URL}${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    });
    return response.json();
  },

  // Add chat endpoint to existing api object
  chat: {
    sendMessage: async (message: string) => {
      return api.post('/chat', { message });
    }
  }
};