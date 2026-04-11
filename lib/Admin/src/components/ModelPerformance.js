import React, { useState, useEffect } from 'react';
import { Pie } from 'react-chartjs-2';
import { Chart as ChartJS, ArcElement, Tooltip, Legend } from 'chart.js';

ChartJS.register(ArcElement, Tooltip, Legend);

const API_URL = 'http://127.0.0.1:8000/api';

const generateChartData = (breakdownData) => {
    if (!breakdownData || breakdownData.length === 0) {
        return { labels: [], datasets: [] };
    }
    const labels = breakdownData.map(d => d.label);
    const data = breakdownData.map(d => d.count);
    return {
        labels,
        datasets: [
            {
                label: '# of Items',
                data,
                backgroundColor: [
                    'rgba(255, 99, 132, 0.7)',
                    'rgba(54, 162, 235, 0.7)',
                    'rgba(255, 206, 86, 0.7)',
                    'rgba(75, 192, 192, 0.7)',
                    'rgba(153, 102, 255, 0.7)',
                    'rgba(255, 159, 64, 0.7)',
                ],
                borderColor: [
                    'rgba(255, 99, 132, 1)',
                    'rgba(54, 162, 235, 1)',
                    'rgba(255, 206, 86, 1)',
                    'rgba(75, 192, 192, 1)',
                    'rgba(153, 102, 255, 1)',
                    'rgba(255, 159, 64, 1)',
                ],
                borderWidth: 1,
            },
        ],
    };
};

function ModelPerformance() {
    const [performanceData, setPerformanceData] = useState(null);
    const [error, setError] = useState(null);

    useEffect(() => {
        fetch(`${API_URL}/model-performance`)
            .then(res => res.json())
            .then(data => {
                if (data.error) {
                    setError(data.error);
                } else {
                    setPerformanceData(data);
                }
            })
            .catch(err => setError('Failed to fetch data from server.'));
    }, []);

    if (error) {
        return <div className="card"><h2>Model Performance</h2><p className="error-message">{error}</p></div>;
    }

    if (!performanceData) {
        return <div className="card"><h2>Model Performance</h2><p className="loading-message">Loading model performance data...</p></div>;
    }

    const { correctionRate, translationsBreakdown, correctionsBreakdown } = performanceData;
    const translationsChartData = generateChartData(translationsBreakdown);
    const correctionsChartData = generateChartData(correctionsBreakdown);

    return (
        <div className="card">
            <h2>Model Performance</h2>
            <div className="stat-card">
                <p>Accuracy: {(100-correctionRate).toFixed(2)}%</p>
                <small>({performanceData.totalCorrections} corrections / {performanceData.totalTranslations} translations)</small>
            </div>
            <div className="dashboard-grid chart-grid">
                <div>
                    <h3>Original Predictions Distribution</h3>
                    {translationsBreakdown?.length > 0 ? 
                        <Pie data={translationsChartData} /> : <p>No translation data yet.</p>
                    }
                </div>
                <div>
                    <h3>User Corrections Distribution</h3>
                     {correctionsBreakdown?.length > 0 ? 
                        <Pie data={correctionsChartData} /> : <p>No correction data yet.</p>
                    }
                </div>
            </div>
        </div>
    );
}

export default ModelPerformance;