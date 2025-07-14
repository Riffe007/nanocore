#!/usr/bin/env node
/**
 * Build script to compile NanoCore C FFI to WebAssembly
 * This creates a WASM module that can be used in the web playground
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('Building NanoCore WebAssembly module...');

// Check if emcc is available
try {
  execSync('emcc --version', { stdio: 'ignore' });
} catch (e) {
  console.error('Error: Emscripten (emcc) not found!');
  console.log('Please install Emscripten: https://emscripten.org/docs/getting_started/downloads.html');
  process.exit(1);
}

const srcFile = path.join(__dirname, '../../glue/ffi/nanocore_ffi.c');
const outDir = path.join(__dirname, '../public');
const outFile = path.join(outDir, 'nanocore.js');

// Ensure output directory exists
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

// Emscripten compilation flags
const flags = [
  '-O3',  // Optimize for performance
  '-s', 'WASM=1',
  '-s', 'EXPORTED_FUNCTIONS=["_nanocore_init", "_nanocore_vm_create", "_nanocore_vm_destroy", "_nanocore_vm_reset", "_nanocore_vm_run", "_nanocore_vm_step", "_nanocore_vm_get_state", "_nanocore_vm_get_register", "_nanocore_vm_set_register", "_nanocore_vm_load_program", "_nanocore_vm_read_memory", "_nanocore_vm_write_memory", "_nanocore_vm_set_breakpoint", "_nanocore_vm_clear_breakpoint", "_nanocore_vm_get_perf_counter", "_nanocore_vm_poll_event", "_malloc", "_free"]',
  '-s', 'EXPORTED_RUNTIME_METHODS=["ccall", "cwrap", "getValue", "setValue", "HEAP8", "HEAP16", "HEAP32", "HEAPU8", "HEAPU16", "HEAPU32", "HEAPF32", "HEAPF64"]',
  '-s', 'ALLOW_MEMORY_GROWTH=1',
  '-s', 'MODULARIZE=1',
  '-s', 'EXPORT_ES6=1',
  '-s', 'ENVIRONMENT=web',
  '-s', 'EXPORT_NAME="NanoCore"',
  '-s', 'SINGLE_FILE=1',  // Embed WASM in JS for easier deployment
];

const command = `emcc ${srcFile} -o ${outFile} ${flags.join(' ')}`;

console.log('Running:', command);

try {
  execSync(command, { stdio: 'inherit' });
  console.log(`\n✅ Successfully built WebAssembly module: ${outFile}`);
  
  // Create TypeScript declarations
  const dtsContent = `
export interface NanoCoreModule {
  ccall: (name: string, returnType: string | null, argTypes: string[], args: any[]) => any;
  cwrap: (name: string, returnType: string | null, argTypes: string[]) => Function;
  getValue: (ptr: number, type: string) => number;
  setValue: (ptr: number, value: number, type: string) => void;
  _malloc: (size: number) => number;
  _free: (ptr: number) => void;
  HEAP8: Int8Array;
  HEAP16: Int16Array;
  HEAP32: Int32Array;
  HEAPU8: Uint8Array;
  HEAPU16: Uint16Array;
  HEAPU32: Uint32Array;
  HEAPF32: Float32Array;
  HEAPF64: Float64Array;
}

declare const NanoCore: () => Promise<NanoCoreModule>;
export default NanoCore;
`;

  fs.writeFileSync(outFile.replace('.js', '.d.ts'), dtsContent);
  console.log('✅ Created TypeScript declarations');

} catch (error) {
  console.error('Build failed:', error.message);
  process.exit(1);
}

console.log('\n📝 Note: If you don\'t have Emscripten installed, you can:');
console.log('1. Install it from https://emscripten.org');
console.log('2. Or use the pre-built WASM module (if available)');
console.log('3. Or use the mock implementation for development');