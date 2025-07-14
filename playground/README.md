# NanoCore Playground

Interactive web-based IDE for the NanoCore Assembly VM.

## Features

- 🎨 **Monaco Editor** - Full-featured code editor with syntax highlighting
- ⚡ **Real-time Execution** - Step through code and watch registers update
- 📊 **Performance Monitoring** - Track IPC, cache hits, and more
- 🔍 **Memory Inspector** - View and modify VM memory
- 📚 **Example Programs** - Learn with pre-built demos
- 🚀 **WASM-powered** - Near-native performance in the browser

## Running Locally

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build
```

## Architecture

The playground consists of:

1. **React Frontend** - Modern UI with real-time updates
2. **TypeScript VM** - Simulated VM for demonstration
3. **Monaco Editor** - VS Code's editor for the web
4. **Tailwind CSS** - Utility-first styling

In production, the TypeScript VM would be replaced with the actual NanoCore WASM module compiled from the assembly implementation.

## Screenshots

### Main Interface
- Code editor on the left
- Register view on the right
- Console output at the bottom
- Performance metrics displayed

### Features
- Syntax highlighting for NanoCore assembly
- Step-by-step execution
- Breakpoint support
- Memory inspection
- Real-time performance monitoring

## Technology Stack

- **React 18** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool
- **Monaco Editor** - Code editing
- **Tailwind CSS** - Styling
- **Lucide Icons** - Beautiful icons

## Future Enhancements

- WebAssembly integration for real VM
- Time-travel debugging
- Collaborative editing
- Export/import programs
- More visualization tools