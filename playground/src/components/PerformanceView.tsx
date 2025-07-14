import React from 'react';
import { BarChart } from 'lucide-react';

interface PerformanceViewProps {
  performance: {
    instructions: number;
    cycles: number;
    cacheHits: number;
    cacheMisses: number;
  };
}

export function PerformanceView({ performance }: PerformanceViewProps) {
  const ipc = performance.cycles > 0 
    ? (performance.instructions / performance.cycles).toFixed(2)
    : '0.00';
    
  const cacheHitRate = performance.cacheHits + performance.cacheMisses > 0
    ? ((performance.cacheHits / (performance.cacheHits + performance.cacheMisses)) * 100).toFixed(1)
    : '0.0';

  const metrics = [
    { label: 'Instructions', value: performance.instructions.toLocaleString() },
    { label: 'Cycles', value: performance.cycles.toLocaleString() },
    { label: 'IPC', value: ipc },
    { label: 'Cache Hits', value: performance.cacheHits.toLocaleString() },
    { label: 'Cache Misses', value: performance.cacheMisses.toLocaleString() },
    { label: 'Hit Rate', value: `${cacheHitRate}%` },
  ];

  return (
    <div className="grid grid-cols-3 gap-3">
      {metrics.map((metric, i) => (
        <div key={i} className="bg-gray-800 p-3 rounded">
          <div className="text-gray-400 text-xs">{metric.label}</div>
          <div className="text-lg font-mono text-blue-400">{metric.value}</div>
        </div>
      ))}
    </div>
  );
}