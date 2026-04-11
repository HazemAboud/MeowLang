import React from 'react';
import './App.css';
import ModelManagement from './components/ModelManagement';
import QueryPerformance from './components/QueryPerformance';
import ModelPerformance from './components/ModelPerformance';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <h1> MeowLang - Admin Dashboard</h1>
      </header>
      <main className="dashboard-grid">
        <ModelPerformance />
        <ModelManagement />
        <QueryPerformance />
      </main>
    </div>
  );
}


export default App;