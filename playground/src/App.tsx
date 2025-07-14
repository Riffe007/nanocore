import React, { useState, useEffect, useRef } from 'react';
import Editor from '@monaco-editor/react';
import { Toaster, toast } from 'react-hot-toast';
import { Play, Pause, RotateCcw, Download, Upload, Cpu, Zap, BarChart } from 'lucide-react';
import { NanoCoreVM, AssemblyError } from './wasm/nanocore';
import { RegisterView } from './components/RegisterView';
import { MemoryView } from './components/MemoryView';
import { PerformanceView } from './components/PerformanceView';
import { examples } from './examples';

interface VMState {
  pc: number;
  sp: number;
  flags: number;
  registers: number[];
  vectorRegisters: number[][];
  performance: {
    instructions: number;
    cycles: number;
    cacheHits: number;
    cacheMisses: number;
  };
}

function App() {
  const [code, setCode] = useState(examples.helloWorld);
  const [isRunning, setIsRunning] = useState(false);
  const [vmState, setVmState] = useState<VMState | null>(null);
  const [output, setOutput] = useState<string[]>([]);
  const [selectedExample, setSelectedExample] = useState('helloWorld');
  const vmRef = useRef<NanoCoreVM | null>(null);
  const intervalRef = useRef<number | null>(null);

  useEffect(() => {
    // Initialize VM
    const initVM = async () => {
      try {
        const vm = await NanoCoreVM.init();
        vmRef.current = vm;
        setVmState(vm.getState());
        toast.success('VM initialized');
      } catch (error) {
        toast.error('Failed to initialize VM');
        console.error(error);
      }
    };
    
    initVM();
    
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, []);

  const handleAssemble = async () => {
    if (!vmRef.current) return;
    
    try {
      const bytecode = await vmRef.current.assemble(code);
      vmRef.current.loadProgram(bytecode);
      setVmState(vmRef.current.getState());
      toast.success(`Assembled ${bytecode.length} bytes`);
      addOutput(`[ASSEMBLED] ${bytecode.length} bytes`);
    } catch (error) {
      if (error instanceof AssemblyError) {
        toast.error(`Assembly error: ${error.message}`);
        addOutput(`[ERROR] ${error.message}`);
      } else {
        toast.error('Unknown assembly error');
      }
    }
  };

  const handleRun = () => {
    if (!vmRef.current || isRunning) return;
    
    setIsRunning(true);
    addOutput('[RUNNING]');
    
    // Run VM in steps with visualization
    let steps = 0;
    intervalRef.current = setInterval(() => {
      if (!vmRef.current) return;
      
      const result = vmRef.current.step();
      setVmState(vmRef.current.getState());
      steps++;
      
      if (result.halted || result.error || steps > 1000) {
        handleStop();
        if (result.halted) {
          addOutput('[HALTED]');
        } else if (result.error) {
          addOutput(`[ERROR] ${result.error}`);
        } else {
          addOutput('[TIMEOUT] Execution limit reached');
        }
      }
      
      // Handle any output from the VM
      if (result.output) {
        addOutput(result.output);
      }
    }, 100); // 10 steps per second for visualization
  };

  const handleStep = () => {
    if (!vmRef.current || isRunning) return;
    
    const result = vmRef.current.step();
    setVmState(vmRef.current.getState());
    
    if (result.output) {
      addOutput(result.output);
    }
    
    if (result.halted) {
      addOutput('[HALTED]');
    } else if (result.error) {
      addOutput(`[ERROR] ${result.error}`);
    }
  };

  const handleStop = () => {
    setIsRunning(false);
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  };

  const handleReset = () => {
    if (!vmRef.current) return;
    
    handleStop();
    vmRef.current.reset();
    setVmState(vmRef.current.getState());
    setOutput([]);
    toast.success('VM reset');
  };

  const addOutput = (line: string) => {
    setOutput(prev => [...prev, `${new Date().toLocaleTimeString()}: ${line}`]);
  };

  const loadExample = (exampleKey: string) => {
    setSelectedExample(exampleKey);
    setCode(examples[exampleKey as keyof typeof examples]);
    handleReset();
  };

  return (
    <div className="min-h-screen bg-gray-900 text-gray-100">
      <Toaster position="top-right" />
      
      {/* Header */}
      <header className="bg-gray-800 border-b border-gray-700 px-4 py-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <Cpu className="w-8 h-8 text-blue-400" />
            <h1 className="text-2xl font-bold">NanoCore Playground</h1>
            <span className="text-sm text-gray-400">High-Performance Assembly VM</span>
          </div>
          
          <div className="flex items-center space-x-4">
            <select
              value={selectedExample}
              onChange={(e) => loadExample(e.target.value)}
              className="bg-gray-700 px-3 py-1 rounded border border-gray-600"
            >
              <option value="helloWorld">Hello World</option>
              <option value="fibonacci">Fibonacci</option>
              <option value="simd">SIMD Demo</option>
              <option value="loops">Loops & Branches</option>
            </select>
            
            <button
              onClick={handleAssemble}
              className="btn btn-secondary"
            >
              Assemble
            </button>
            
            <div className="flex items-center space-x-2">
              <button
                onClick={handleRun}
                disabled={isRunning}
                className="btn btn-primary"
              >
                <Play className="w-4 h-4 mr-1" />
                Run
              </button>
              
              <button
                onClick={handleStep}
                disabled={isRunning}
                className="btn btn-secondary"
              >
                Step
              </button>
              
              <button
                onClick={handleStop}
                disabled={!isRunning}
                className="btn btn-secondary"
              >
                <Pause className="w-4 h-4" />
              </button>
              
              <button
                onClick={handleReset}
                className="btn btn-secondary"
              >
                <RotateCcw className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="flex h-[calc(100vh-64px)]">
        {/* Code Editor */}
        <div className="w-1/2 border-r border-gray-700">
          <div className="h-full flex flex-col">
            <div className="bg-gray-800 px-4 py-2 border-b border-gray-700">
              <h2 className="font-semibold">Assembly Code</h2>
            </div>
            <div className="flex-1">
              <Editor
                theme="vs-dark"
                language="asm"
                value={code}
                onChange={(value) => setCode(value || '')}
                options={{
                  minimap: { enabled: false },
                  fontSize: 14,
                  lineNumbers: 'on',
                  rulers: [80],
                  wordWrap: 'off',
                }}
              />
            </div>
          </div>
        </div>

        {/* Right Panel */}
        <div className="w-1/2 flex flex-col">
          {/* VM State */}
          <div className="flex-1 overflow-hidden">
            <div className="h-full flex flex-col">
              {/* Tabs */}
              <div className="bg-gray-800 px-4 py-2 border-b border-gray-700 flex space-x-4">
                <button className="tab tab-active">Registers</button>
                <button className="tab">Memory</button>
                <button className="tab">Performance</button>
              </div>
              
              {/* Tab Content */}
              <div className="flex-1 overflow-auto p-4">
                {vmState && (
                  <>
                    <RegisterView state={vmState} />
                    <div className="mt-6">
                      <h3 className="font-semibold mb-2 flex items-center">
                        <Zap className="w-4 h-4 mr-2 text-yellow-400" />
                        Performance Counters
                      </h3>
                      <PerformanceView performance={vmState.performance} />
                    </div>
                  </>
                )}
              </div>
            </div>
          </div>

          {/* Console Output */}
          <div className="h-1/3 border-t border-gray-700">
            <div className="h-full flex flex-col">
              <div className="bg-gray-800 px-4 py-2 border-b border-gray-700 flex justify-between">
                <h2 className="font-semibold">Console Output</h2>
                <button
                  onClick={() => setOutput([])}
                  className="text-sm text-gray-400 hover:text-gray-200"
                >
                  Clear
                </button>
              </div>
              <div className="flex-1 overflow-auto p-4 font-mono text-sm">
                {output.map((line, i) => (
                  <div key={i} className="text-green-400">{line}</div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;