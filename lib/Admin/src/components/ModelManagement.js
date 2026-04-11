import React, { useState, useEffect, useCallback } from 'react';

const API_URL = 'http://127.0.0.1:8000/api';

function ModelManagement() {
    const [models, setModels] = useState([]);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState(null);

    const fetchModels = useCallback(() => {
        setIsLoading(true);
        setError(null);
        fetch(`${API_URL}/mlflow/models`)
            .then(res => res.json())
            .then(data => {
                if (data.error) {
                    setError(data.error);
                    setModels([]);
                } else {
                    setModels(data);
                }
            })
            .catch(err => {
                console.error("Failed to fetch models", err);
                setError("Failed to fetch models. Is the backend running?");
            })
            .finally(() => setIsLoading(false));
    }, []);

    useEffect(() => {
        fetchModels();
    }, [fetchModels]);

    return (
        <div className="card">
            <h2>Model Management</h2>
            <p>This section shows details for deployed models.</p>
            <h3>Deployed Model Details</h3>
            {isLoading && models.length === 0 && <p className="loading-message">Loading models...</p>}
            {error && <p className="error-message">{error}</p>}
            {!isLoading && !error && models.length === 0 && <p>No models found.</p>}
            {models.length > 0 && (
                <table>
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Version</th>
                            <th>Stage</th>
                        </tr>
                    </thead>
                    <tbody>
                        {models.map(m => (
                            <tr key={m.name}>
                                <td>{m.name}</td>
                                <td>{m.version}</td>
                                <td>{m.stage}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            )}
        </div>
    );
}
export default ModelManagement;