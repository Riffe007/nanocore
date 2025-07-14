import React from 'react'
import { Play, Pause, RotateCcw, StepForward, Cpu } from './Icons'

interface ControlPanelProps {
  onAssemble: () => void
  onRun: () => void
  onStep: () => void
  onReset: () => void
  isRunning: boolean
}

export const ControlPanel: React.FC<ControlPanelProps> = ({
  onAssemble,
  onRun,
  onStep,
  onReset,
  isRunning
}) => {
  return (
    <div className="flex items-center space-x-2">
      <button
        onClick={onAssemble}
        className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-md transition-colors flex items-center space-x-2"
        title="Assemble code"
      >
        <Cpu className="w-4 h-4" />
        <span>Assemble</span>
      </button>

      <div className="w-px h-6 bg-gray-600" />

      <button
        onClick={onRun}
        disabled={isRunning}
        className="px-4 py-2 bg-green-600 hover:bg-green-700 disabled:bg-gray-600 disabled:cursor-not-allowed rounded-md transition-colors flex items-center space-x-2"
        title="Run program"
      >
        {isRunning ? (
          <>
            <Pause className="w-4 h-4" />
            <span>Pause</span>
          </>
        ) : (
          <>
            <Play className="w-4 h-4" />
            <span>Run</span>
          </>
        )}
      </button>

      <button
        onClick={onStep}
        disabled={isRunning}
        className="px-4 py-2 bg-yellow-600 hover:bg-yellow-700 disabled:bg-gray-600 disabled:cursor-not-allowed rounded-md transition-colors flex items-center space-x-2"
        title="Step one instruction"
      >
        <StepForward className="w-4 h-4" />
        <span>Step</span>
      </button>

      <button
        onClick={onReset}
        className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded-md transition-colors flex items-center space-x-2"
        title="Reset VM"
      >
        <RotateCcw className="w-4 h-4" />
        <span>Reset</span>
      </button>
    </div>
  )
}