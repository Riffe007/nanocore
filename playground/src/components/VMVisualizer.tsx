import React from 'react'
import { Activity, Cpu, Memory, Zap } from './Icons'

interface VMVisualizerProps {
  state: any
}

export const VMVisualizer: React.FC<VMVisualizerProps> = ({ state }) => {
  if (!state) {
    return (
      <div className="h-full flex items-center justify-center text-gray-500">
        <div className="text-center">
          <Cpu className="w-12 h-12 mx-auto mb-2" />
          <p>VM not initialized</p>
        </div>
      </div>
    )
  }

  const isHalted = (state.flags & 0x80n) !== 0n
  const interruptsEnabled = (state.flags & 0x10n) !== 0n

  return (
    <div className="h-full p-4 bg-gray-800">
      <h3 className="text-sm font-semibold text-gray-400 mb-3">VM Status</h3>
      
      <div className="space-y-3">
        {/* Status Indicator */}
        <div className="flex items-center justify-between">
          <span className="text-gray-400">Status:</span>
          <div className="flex items-center space-x-2">
            <Activity className={`w-4 h-4 ${isHalted ? 'text-red-500' : 'text-green-500'}`} />
            <span className={isHalted ? 'text-red-400' : 'text-green-400'}>
              {isHalted ? 'HALTED' : 'RUNNING'}
            </span>
          </div>
        </div>

        {/* Program Counter */}
        <div className="flex items-center justify-between">
          <span className="text-gray-400">PC:</span>
          <span className="font-mono text-blue-400">
            0x{state.pc.toString(16).padStart(8, '0')}
          </span>
        </div>

        {/* Stack Pointer */}
        <div className="flex items-center justify-between">
          <span className="text-gray-400">SP:</span>
          <span className="font-mono text-purple-400">
            0x{state.sp.toString(16).padStart(8, '0')}
          </span>
        </div>

        {/* Flags */}
        <div className="flex items-center justify-between">
          <span className="text-gray-400">Flags:</span>
          <div className="flex space-x-1">
            <FlagIndicator name="Z" active={(state.flags & 0x01n) !== 0n} />
            <FlagIndicator name="C" active={(state.flags & 0x02n) !== 0n} />
            <FlagIndicator name="O" active={(state.flags & 0x04n) !== 0n} />
            <FlagIndicator name="N" active={(state.flags & 0x08n) !== 0n} />
            <FlagIndicator name="I" active={interruptsEnabled} />
          </div>
        </div>

        {/* Performance */}
        <div className="pt-3 border-t border-gray-700">
          <div className="flex items-center justify-between">
            <span className="text-gray-400 flex items-center">
              <Zap className="w-3 h-3 mr-1" />
              Instructions:
            </span>
            <span className="font-mono">
              {state.perfCounters[0].toString()}
            </span>
          </div>
          <div className="flex items-center justify-between mt-1">
            <span className="text-gray-400 flex items-center">
              <Memory className="w-3 h-3 mr-1" />
              Cycles:
            </span>
            <span className="font-mono">
              {state.perfCounters[1].toString()}
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}

const FlagIndicator: React.FC<{ name: string; active: boolean }> = ({ name, active }) => (
  <div
    className={`w-6 h-6 rounded text-xs font-bold flex items-center justify-center ${
      active
        ? 'bg-green-600 text-green-100'
        : 'bg-gray-700 text-gray-500'
    }`}
    title={`${name} flag`}
  >
    {name}
  </div>
)