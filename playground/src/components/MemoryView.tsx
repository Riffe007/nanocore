import React from 'react';

interface MemoryViewProps {
  memory: Uint8Array;
  startAddress: number;
  highlightPC?: number;
}

export function MemoryView({ memory, startAddress, highlightPC }: MemoryViewProps) {
  const bytesPerRow = 16;
  const rows = Math.ceil(memory.length / bytesPerRow);

  const formatAddress = (addr: number) => {
    return `0x${addr.toString(16).padStart(8, '0').toUpperCase()}`;
  };

  const formatByte = (byte: number) => {
    return byte.toString(16).padStart(2, '0').toUpperCase();
  };

  const getAscii = (byte: number) => {
    return byte >= 32 && byte <= 126 ? String.fromCharCode(byte) : '.';
  };

  return (
    <div className="memory-grid">
      {Array.from({ length: rows }).map((_, rowIndex) => {
        const rowAddress = startAddress + rowIndex * bytesPerRow;
        const rowBytes = memory.slice(
          rowIndex * bytesPerRow,
          (rowIndex + 1) * bytesPerRow
        );

        return (
          <div key={rowIndex} className="flex mb-1">
            <span className="memory-address">{formatAddress(rowAddress)}</span>
            
            <span className="memory-hex">
              {Array.from(rowBytes).map((byte, i) => {
                const address = rowAddress + i;
                const isPC = highlightPC && address >= highlightPC && address < highlightPC + 4;
                return (
                  <span
                    key={i}
                    className={`mr-1 ${isPC ? 'bg-blue-600' : ''}`}
                  >
                    {formatByte(byte)}
                  </span>
                );
              })}
            </span>
            
            <span className="memory-ascii">
              {Array.from(rowBytes).map((byte, i) => getAscii(byte)).join('')}
            </span>
          </div>
        );
      })}
    </div>
  );
}