import React from 'react'
import { FileCode } from './Icons'

interface ExampleSelectorProps {
  value: string
  onChange: (value: string) => void
}

export const ExampleSelector: React.FC<ExampleSelectorProps> = ({ value, onChange }) => {
  return (
    <div className="flex items-center space-x-2">
      <FileCode className="w-4 h-4 text-gray-400" />
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="bg-gray-700 text-gray-100 px-3 py-1 rounded border border-gray-600 focus:border-blue-500 focus:outline-none"
      >
        <option value="hello">Hello World</option>
        <option value="fibonacci">Fibonacci</option>
        <option value="simd">SIMD Operations</option>
        <option value="loops">Loops & Branches</option>
        <option value="factorial">Factorial</option>
        <option value="bubble_sort">Bubble Sort</option>
      </select>
    </div>
  )
}