import { useState, useEffect } from 'react'

function App() {
    const [health, setHealth] = useState(null)

    useEffect(() => {
        fetch('http://localhost:3000/api/v1/health/check')
            .then(res => res.json())
            .then(data => setHealth(data))
            .catch(err => console.error(err))
    }, [])

    return (
        <div>
            <h1>Health Check</h1>
            {health ? (
                <pre>{JSON.stringify(health, null, 2)}</pre>
            ) : (
                <p>Loading...</p>
            )}
        </div>
    )
}

export default App