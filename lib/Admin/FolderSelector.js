import React, { useState, useEffect } from 'react';

const FolderSelector = ({ onSelect }) => {
    const [currentPath, setCurrentPath] = useState('.');
    const [data, setData] = useState({ items: [], parent: null, path: '.' });
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const fetchDirectory = async (path) => {
        setLoading(true);
        setError(null);
        try {
            const response = await fetch(`http://localhost:8000/api/file-explorer?path=${encodeURIComponent(path)}`);
            if (!response.ok) {
                throw new Error(`Error: ${response.statusText}`);
            }
            const result = await response.json();
            if (result.error) {
                throw new Error(result.error);
            }
            setData(result);
            setCurrentPath(result.path);
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchDirectory(currentPath);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const handleNavigate = (path) => {
        if (path !== null) {
            fetchDirectory(path);
        }
    };

    return (
        <div className="folder-selector-container" style={{ border: '1px solid #ddd', padding: '15px', borderRadius: '8px', backgroundColor: '#f9f9f9', marginTop: '20px' }}>
            <h4>Select Training Dataset</h4>
            
            <div className="navigation-controls" style={{ marginBottom: '15px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                <button 
                    onClick={() => handleNavigate(data.parent)} 
                    disabled={data.parent === null}
                    style={{ padding: '5px 10px', cursor: 'pointer' }}
                >
                    ⬆ Up Level
                </button>
                <span style={{ fontFamily: 'monospace', backgroundColor: '#eee', padding: '5px', borderRadius: '4px' }}>
                    /{data.path}
                </span>
            </div>

            {error && <div style={{ color: 'red', marginBottom: '10px' }}>{error}</div>}
            
            {loading ? (
                <div>Loading directories...</div>
            ) : (
                <div className="directory-list">
                    {data.items.length === 0 ? (
                        <p>No directories found.</p>
                    ) : (
                        <ul style={{ listStyleType: 'none', padding: 0 }}>
                            {data.items.map((item) => (
                                <li key={item.name} style={{ 
                                    padding: '10px', 
                                    borderBottom: '1px solid #eee', 
                                    display: 'flex', 
                                    justifyContent: 'space-between', 
                                    alignItems: 'center',
                                    backgroundColor: 'white'
                                }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                        <span role="img" aria-label="folder">📁</span>
                                        <a 
                                            href="#!" 
                                            onClick={(e) => { e.preventDefault(); handleNavigate(item.path); }}
                                            style={{ textDecoration: 'none', color: '#007bff', fontWeight: '500' }}
                                        >
                                            {item.name}
                                        </a>
                                    </div>

                                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                        {item.isValidDataset ? (
                                            <>
                                                <span style={{ fontSize: '0.85em', color: '#28a745', border: '1px solid #28a745', padding: '2px 6px', borderRadius: '4px' }}>
                                                    Valid Dataset
                                                </span>
                                                <span style={{ fontSize: '0.8em', color: '#666' }}>
                                                    ({item.classNames.length} classes)
                                                </span>
                                                <button 
                                                    onClick={() => onSelect(item.path)}
                                                    style={{ 
                                                        backgroundColor: '#007bff', 
                                                        color: 'white', 
                                                        border: 'none', 
                                                        padding: '6px 12px', 
                                                        borderRadius: '4px', 
                                                        cursor: 'pointer' 
                                                    }}
                                                >
                                                    Select
                                                </button>
                                            </>
                                        ) : (
                                            <span style={{ fontSize: '0.8em', color: '#999', fontStyle: 'italic' }}>
                                                Not a dataset
                                            </span>
                                        )}
                                    </div>
                                </li>
                            ))}
                        </ul>
                    )}
                </div>
            )}
        </div>
    );
};

export default FolderSelector;