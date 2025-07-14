import React from 'react';

interface RegisterViewProps {
  state: {
    pc: number;
    sp: number;
    flags: number;
    registers: number[];
    vectorRegisters: number[][];
  };
}

export function RegisterView({ state }: RegisterViewProps) {
  const formatHex = (value: number, width: number = 16) => {
    return `0x${value.toString(16).padStart(width, '0').toUpperCase()}`;
  };

  const formatFlags = (flags: number) => {
    const flagNames = ['Z', 'C', 'V', 'N', 'IE', 'UM', '', 'HALT'];
    return flagNames
      .map((name, i) => (flags & (1 << i)) ? name : '')
      .filter(Boolean)
      .join(' ');
  };

  return (
    <div>
      {/* Special Registers */}
      <div className="mb-6">
        <h3 className="font-semibold mb-2">Special Registers</h3>
        <div className="space-y-1">
          <div className="flex justify-between">
            <span className="text-gray-400">PC:</span>
            <span className="font-mono text-green-400">{formatHex(state.pc)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-400">SP:</span>
            <span className="font-mono text-green-400">{formatHex(state.sp)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-400">FLAGS:</span>
            <span className="font-mono text-green-400">
              {formatHex(state.flags, 8)} [{formatFlags(state.flags)}]
            </span>
          </div>
        </div>
      </div>

      {/* General Purpose Registers */}
      <div className="mb-6">
        <h3 className="font-semibold mb-2">General Purpose Registers</h3>
        <div className="register-grid">
          {state.registers.slice(0, 32).map((value, i) => (
            <div key={i} className="register-item">
              <div className="register-name">R{i}</div>
              <div className="register-value">{formatHex(value, 16)}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Vector Registers */}
      <div>
        <h3 className="font-semibold mb-2">Vector Registers (SIMD)</h3>
        <div className="space-y-2">
          {state.vectorRegisters.slice(0, 4).map((vec, i) => (
            <div key={i} className="bg-gray-800 p-2 rounded">
              <div className="text-gray-400 text-xs mb-1">V{i}</div>
              <div className="font-mono text-xs text-blue-400">
                {vec.map(v => formatHex(v, 16)).join(' ')}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}