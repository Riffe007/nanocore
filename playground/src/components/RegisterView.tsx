import React from 'react';

interface RegisterViewProps {
  state: any
}

export const RegisterView: React.FC<RegisterViewProps> = ({ state }) => {
  if (!state || !state.registers) {
    return (
      <div className="h-full flex items-center justify-center text-gray-500">
        <div className="text-center">
          <p>No state available</p>
          <p className="text-sm">Load and run a program first</p>
        </div>
      </div>
    );
  }

  // Helper to format BigInt values
  const formatBigInt = (value: bigint) => {
    try {
      const str = value.toString(16);
      return str.padStart(16, '0');
    } catch {
      return '0000000000000000';
    }
  };

  const formatFlags = (flags: bigint) => {
    const flagNames = ['Z', 'C', 'V', 'N', 'IE', 'UM', '', 'HALT'];
    return flagNames
      .map((name, i) => (flags & (1n << BigInt(i))) ? name : '')
      .filter(Boolean)
      .join(' ');
  };

  return (
    <div className="h-full overflow-auto p-4 bg-gray-800">
      <h3 className="text-sm font-semibold text-gray-400 mb-3">General Purpose Registers</h3>
      <div className="space-y-1 font-mono text-sm">
        {state.registers.slice(0, 32).map((value: bigint, index: number) => (
          <div key={index} className="flex items-center justify-between hover:bg-gray-700 px-2 py-1 rounded">
            <span className="text-gray-400 w-12">R{index}</span>
            <span className="text-blue-400">0x{formatBigInt(value)}</span>
            <span className="text-gray-500 text-xs">({value.toString()})</span>
          </div>
        ))}
      </div>
      
      <h3 className="text-sm font-semibold text-gray-400 mt-4 mb-3">Special Registers</h3>
      <div className="space-y-1 font-mono text-sm">
        <div className="flex items-center justify-between hover:bg-gray-700 px-2 py-1 rounded">
          <span className="text-gray-400 w-12">PC</span>
          <span className="text-green-400">0x{formatBigInt(state.pc)}</span>
        </div>
        <div className="flex items-center justify-between hover:bg-gray-700 px-2 py-1 rounded">
          <span className="text-gray-400 w-12">SP</span>
          <span className="text-purple-400">0x{formatBigInt(state.sp)}</span>
        </div>
        <div className="flex items-center justify-between hover:bg-gray-700 px-2 py-1 rounded">
          <span className="text-gray-400 w-12">FLAGS</span>
          <span className="text-yellow-400">
            0x{formatBigInt(state.flags).slice(-8)} [{formatFlags(state.flags)}]
          </span>
        </div>
      </div>
    </div>
  );
};