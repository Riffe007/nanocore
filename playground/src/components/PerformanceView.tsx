import React from 'react';
import { BarChart, Zap, Database, Cpu } from './Icons';

interface PerformanceViewProps {
  state: any;
}

export const PerformanceView: React.FC<PerformanceViewProps> = ({ state }) => {
  if (!state || !state.perfCounters) {
    return (
      <div className="h-full flex items-center justify-center text-gray-500">
        <div className="text-center">
          <BarChart className="w-12 h-12 mx-auto mb-2" />
          <p>No performance data</p>
        </div>
      </div>
    );
  }

  const instructions = Number(state.perfCounters[0] || 0n);
  const cycles = Number(state.perfCounters[1] || 0n);
  const l1Miss = Number(state.perfCounters[2] || 0n);
  const l2Miss = Number(state.perfCounters[3] || 0n);
  const branchMiss = Number(state.perfCounters[4] || 0n);
  const stalls = Number(state.perfCounters[5] || 0n);

  const ipc = cycles > 0 ? (instructions / cycles).toFixed(3) : '0.000';
  const l1HitRate = instructions > 0 ? ((1 - l1Miss / instructions) * 100).toFixed(1) : '100.0';
  const l2HitRate = l1Miss > 0 ? ((1 - l2Miss / l1Miss) * 100).toFixed(1) : '100.0';

  const metrics = [
    { 
      icon: <Cpu className="w-4 h-4" />, 
      label: 'Instructions', 
      value: instructions.toLocaleString(),
      color: 'text-blue-400'
    },
    { 
      icon: <Zap className="w-4 h-4" />, 
      label: 'Cycles', 
      value: cycles.toLocaleString(),
      color: 'text-green-400'
    },
    { 
      icon: <BarChart className="w-4 h-4" />, 
      label: 'IPC', 
      value: ipc,
      color: 'text-purple-400'
    },
    { 
      icon: <Database className="w-4 h-4" />, 
      label: 'L1 Hit Rate', 
      value: `${l1HitRate}%`,
      color: 'text-yellow-400'
    },
    { 
      icon: <Database className="w-4 h-4" />, 
      label: 'L2 Hit Rate', 
      value: `${l2HitRate}%`,
      color: 'text-orange-400'
    },
    { 
      icon: <Zap className="w-4 h-4" />, 
      label: 'Pipeline Stalls', 
      value: stalls.toLocaleString(),
      color: 'text-red-400'
    },
  ];

  return (
    <div className="h-full p-4 bg-gray-800">
      <h3 className="text-sm font-semibold text-gray-400 mb-3">Performance Metrics</h3>
      <div className="grid grid-cols-2 gap-3">
        {metrics.map((metric, i) => (
          <div key={i} className="bg-gray-700 p-3 rounded">
            <div className="flex items-center space-x-2 text-gray-400 text-xs mb-1">
              {metric.icon}
              <span>{metric.label}</span>
            </div>
            <div className={`text-lg font-mono ${metric.color}`}>
              {metric.value}
            </div>
          </div>
        ))}
      </div>

      {/* IPC Graph (simplified) */}
      <div className="mt-4 p-3 bg-gray-700 rounded">
        <div className="text-xs text-gray-400 mb-2">IPC Trend</div>
        <div className="h-16 flex items-end space-x-1">
          {[0.5, 0.7, 0.9, 1.0, 0.8, 0.95, 1.1].map((val, i) => (
            <div
              key={i}
              className="flex-1 bg-blue-500 rounded-t"
              style={{ height: `${val * 50}%` }}
            />
          ))}
        </div>
      </div>
    </div>
  );
};