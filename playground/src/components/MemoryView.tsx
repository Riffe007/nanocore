import React, { useState, useCallback, useEffect } from 'react';
import { NanoCoreVM } from '../services/vm';

interface MemoryViewProps {
  vm: NanoCoreVM | null;
  state: any;
}

export const MemoryView: React.FC<MemoryViewProps> = ({ vm, state }) => {
  const [startAddress, setStartAddress] = useState(0x10000);
  const [memory, setMemory] = useState<Uint8Array | null>(null);
  const bytesPerRow = 16;
  const rowsToShow = 16;

  useEffect(() => {
    if (vm && state) {
      loadMemory();
    }
  }, [vm, state, startAddress]);

  const loadMemory = useCallback(async () => {
    if (!vm) return;
    
    try {
      const size = bytesPerRow * rowsToShow;
      const data = await vm.readMemory(startAddress, size);
      setMemory(data);
    } catch (err) {
      console.error('Failed to read memory:', err);
      setMemory(null);
    }
  }, [vm, startAddress]);

  const formatAddress = (addr: number) => {
    return addr.toString(16).padStart(8, '0').toUpperCase();
  };

  const formatByte = (byte: number) => {
    return byte.toString(16).padStart(2, '0').toUpperCase();
  };

  const getAscii = (byte: number) => {
    return byte >= 32 && byte <= 126 ? String.fromCharCode(byte) : '.';
  };

  const handleAddressChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    const addr = parseInt(value, 16);
    if (!isNaN(addr) && addr >= 0) {
      setStartAddress(addr);
    }
  };

  if (!vm || !state) {
    return (
      <div className="h-full flex items-center justify-center text-gray-500">
        <div className="text-center">
          <p>No memory to display</p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col bg-gray-800">
      <div className="p-3 border-b border-gray-700">
        <div className="flex items-center space-x-2">
          <label className="text-sm text-gray-400">Address:</label>
          <input
            type="text"
            value={formatAddress(startAddress)}
            onChange={handleAddressChange}
            className="px-2 py-1 bg-gray-700 text-gray-100 rounded text-sm font-mono w-32"
            placeholder="00000000"
          />
          <button
            onClick={() => setStartAddress(Number(state.pc))}
            className="px-2 py-1 bg-blue-600 hover:bg-blue-700 rounded text-sm"
          >
            Go to PC
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-auto p-3 font-mono text-xs">
        {memory && Array.from({ length: rowsToShow }).map((_, rowIndex) => {
          const rowAddress = startAddress + rowIndex * bytesPerRow;
          const rowBytes = memory.slice(
            rowIndex * bytesPerRow,
            (rowIndex + 1) * bytesPerRow
          );

          const isCurrentPC = state && rowAddress <= Number(state.pc) && Number(state.pc) < rowAddress + bytesPerRow;

          return (
            <div key={rowIndex} className={`flex space-x-3 py-1 ${isCurrentPC ? 'bg-blue-900 bg-opacity-30' : ''}`}>
              <span className="text-gray-500 w-20">{formatAddress(rowAddress)}</span>
              
              <span className="flex space-x-1">
                {Array.from(rowBytes).map((byte, i) => {
                  const address = rowAddress + i;
                  const isPC = state && address >= Number(state.pc) && address < Number(state.pc) + 4;
                  return (
                    <span
                      key={i}
                      className={`${isPC ? 'bg-blue-600 text-white px-1 rounded' : 'text-blue-400'}`}
                    >
                      {formatByte(byte)}
                    </span>
                  );
                })}
              </span>
              
              <span className="text-gray-600 border-l border-gray-700 pl-3">
                {Array.from(rowBytes).map((byte, i) => getAscii(byte)).join('')}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};