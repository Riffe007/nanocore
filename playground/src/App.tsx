import React, { useState, useEffect, useCallback } from 'react'
import { Toaster, toast } from 'react-hot-toast'

import { CodeEditor } from './components/CodeEditor'
import { RegisterView } from './components/RegisterView'
import { MemoryView } from './components/MemoryView'
import { PerformanceView } from './components/PerformanceView'
import { ControlPanel } from './components/ControlPanel'
import { ExampleSelector } from './components/ExampleSelector'
import { VMVisualizer } from './components/VMVisualizer'

import { NanoCoreVM } from './services/vm'
import { examples } from './examples'

function App() {
  const [code, setCode] = useState(examples[0].code)
  const [vm, setVM] = useState<NanoCoreVM | null>(null)
  const [isRunning, setIsRunning] = useState(false)
  const [vmState, setVmState] = useState<any>(null)
  const [selectedExample, setSelectedExample] = useState(examples[0].id)
  const [activeTab, setActiveTab] = useState<'registers' | 'memory' | 'performance'>('registers')

  // Initialize VM
  useEffect(() => {
    NanoCoreVM.create().then(newVM => {
      setVM(newVM)
      updateVMState(newVM)
      toast.success('VM initialized')
    }).catch(err => {
      console.error('Failed to initialize VM:', err)
      toast.error('Failed to initialize VM')
    })
  }, [])

  const updateVMState = useCallback(async (vm: NanoCoreVM) => {
    try {
      const state = await vm.getState()
      setVmState(state)
    } catch (err) {
      console.error('Failed to get VM state:', err)
    }
  }, [])

  const handleAssemble = useCallback(async () => {
    if (!vm) return
    
    try {
      // Simple assembly - convert hex string to bytes
      const lines = code.split('\n').filter(line => line.trim())
      const bytes: number[] = []
      
      for (const line of lines) {
        const trimmed = line.trim()
        if (trimmed.startsWith('//') || trimmed === '') continue
        
        // Extract hex bytes before comments
        const hexPart = trimmed.split('//')[0].trim()
        if (!hexPart) continue
        
        // Parse hex bytes (e.g., "3C 20 00 2A")
        const hexBytes = hexPart.split(/\s+/)
        for (const hex of hexBytes) {
          const byte = parseInt(hex, 16)
          if (!isNaN(byte) && byte >= 0 && byte <= 255) {
            bytes.push(byte)
          }
        }
      }
      
      if (bytes.length === 0) {
        toast.error('No valid instructions found')
        return
      }
      
      if (bytes.length % 4 !== 0) {
        toast('Instruction length not aligned to 4 bytes', {
          icon: '⚠️',
        })
      }
      
      await vm.loadProgram(new Uint8Array(bytes))
      await updateVMState(vm)
      toast.success(`Loaded ${bytes.length} bytes`)
    } catch (error) {
      console.error('Assembly error:', error)
      toast.error('Failed to assemble code')
    }
  }, [vm, code, updateVMState])

  const handleRun = useCallback(async () => {
    if (!vm || isRunning) return
    
    setIsRunning(true)
    try {
      const result = await vm.run(10000) // Max 10k instructions
      await updateVMState(vm)
      if (result.halted) {
        toast.success('Program halted')
      } else if (result.error) {
        toast.error(`Runtime error: ${result.error}`)
      }
    } catch (err) {
      console.error('Execution error:', err)
      toast.error('Execution failed')
    } finally {
      setIsRunning(false)
    }
  }, [vm, isRunning, updateVMState])

  const handleStep = useCallback(async () => {
    if (!vm || isRunning) return
    
    try {
      const result = await vm.step()
      await updateVMState(vm)
      if (result.halted) {
        toast('Program halted', {
          icon: 'ℹ️',
        })
      } else if (result.error) {
        toast.error(`Step error: ${result.error}`)
      }
    } catch (err) {
      console.error('Step error:', err)
      toast.error('Step failed')
    }
  }, [vm, isRunning, updateVMState])

  const handleReset = useCallback(async () => {
    if (!vm) return
    
    try {
      await vm.reset()
      await updateVMState(vm)
      toast.success('VM reset')
    } catch (err) {
      console.error('Reset error:', err)
      toast.error('Reset failed')
    }
  }, [vm, updateVMState])

  const handleExampleChange = useCallback((exampleId: string) => {
    const example = examples.find(e => e.id === exampleId)
    if (example) {
      setCode(example.code)
      setSelectedExample(exampleId)
    }
  }, [])

  return (
    <div className="h-screen w-screen flex flex-col bg-gray-900 text-gray-100">
      <Toaster position="bottom-right" />
      
      {/* Header */}
      <header className="bg-gray-800 border-b border-gray-700 px-4 py-2 flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <h1 className="text-xl font-bold">NanoCore Playground</h1>
          <ExampleSelector 
            value={selectedExample} 
            onChange={handleExampleChange} 
          />
        </div>
        <ControlPanel
          onAssemble={handleAssemble}
          onRun={handleRun}
          onStep={handleStep}
          onReset={handleReset}
          isRunning={isRunning}
        />
      </header>

      {/* Main Content */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left Panel - Code Editor */}
        <div className="w-1/2 border-r border-gray-700">
          <CodeEditor value={code} onChange={setCode} />
        </div>

        {/* Right Panel - VM State */}
        <div className="w-1/2 flex flex-col">
          {/* Tabs */}
          <div className="bg-gray-800 px-4 py-2 border-b border-gray-700 flex space-x-4">
            <button 
              className={`px-3 py-1 rounded ${activeTab === 'registers' ? 'bg-gray-700 text-white' : 'text-gray-400 hover:text-white'}`}
              onClick={() => setActiveTab('registers')}
            >
              Registers
            </button>
            <button 
              className={`px-3 py-1 rounded ${activeTab === 'memory' ? 'bg-gray-700 text-white' : 'text-gray-400 hover:text-white'}`}
              onClick={() => setActiveTab('memory')}
            >
              Memory
            </button>
            <button 
              className={`px-3 py-1 rounded ${activeTab === 'performance' ? 'bg-gray-700 text-white' : 'text-gray-400 hover:text-white'}`}
              onClick={() => setActiveTab('performance')}
            >
              Performance
            </button>
          </div>

          {/* Tab Content */}
          <div className="flex-1 flex overflow-hidden">
            {activeTab === 'registers' && (
              <div className="flex flex-1">
                <div className="w-1/2 border-r border-gray-700">
                  <RegisterView state={vmState} />
                </div>
                <div className="w-1/2">
                  <VMVisualizer state={vmState} />
                </div>
              </div>
            )}
            
            {activeTab === 'memory' && (
              <div className="flex-1">
                <MemoryView vm={vm} state={vmState} />
              </div>
            )}
            
            {activeTab === 'performance' && (
              <div className="flex-1">
                <PerformanceView state={vmState} />
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

export default App