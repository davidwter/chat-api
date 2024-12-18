const API_URL = import.meta.env.VITE_API_URL;

export const fetchData = async () => {
    try {
        const response = await fetch(`${API_URL}/api/v1/your-endpoint`);
        return await response.json();
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
};