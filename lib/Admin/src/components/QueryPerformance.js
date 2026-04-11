import React, { useState, useEffect } from 'react';

const API_URL = 'http://127.0.0.1:8000/api';

function QueryPerformance() {
    const [performanceData, setPerformanceData] = useState([]);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        setIsLoading(true);
        fetch(`${API_URL}/query-performance`)
            .then(res => res.json())
            .then(data => {
                if (data.error) {
                    setError(data.error);
                } else {
                    setPerformanceData(data);
                }
            })
            .catch(err => setError('Failed to fetch data from server. Is the backend running?'))
            .finally(() => setIsLoading(false));
    }, []);

    if (isLoading) {
        return (
            <div className="card">
                <h2>Query Performance</h2>
                <p className="loading-message">Loading performance data...</p>
            </div>
        );
    }

    return (
        <div className="card">
            <h2>Query Performance</h2>
            {error && <p className="error-message">{error}</p>}
            <table>
                <thead>
                    <tr>
                        <th>Endpoint</th>
                        <th>Query Name</th>
                        <th>Calls</th>
                        <th>Avg. Time (ms)</th>
                    </tr>
                </thead>
                <tbody>
                    {performanceData.map((item) => (
                        <tr key={`${item.endpoint}-${item.query_name}`}>
                            <td>{item.endpoint}</td>
                            <td>{item.query_name}</td>
                            <td>{item.call_count}</td>
                            <td>{Number(item.avg_time).toFixed(2)}</td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
}

export default QueryPerformance;