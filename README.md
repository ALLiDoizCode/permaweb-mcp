# MCP Integration Test Suite for AO/Permaweb

This repository contains a comprehensive test suite for demonstrating and testing the **Model Context Protocol (MCP)** implementation on the AO/Permaweb ecosystem using **aolite** for local development and testing.

## 🎯 Overview

The MCP implementation consists of three main components:

1. **MCP Client** (`client.lua`) - Discovers tools from ADP-compliant processes and uses AI guidance for task execution
2. **MCP Server** (`mcp-server.lua`) - Calculator server that exposes tools through ADP (Action Documentation Protocol)
3. **Mock APUS Router** (`mock-apus-router.lua`) - Simulates AI inference for testing purposes

## 🏗️ Architecture

```
User Request → MCP Client → APUS Router (AI) → Tool Recommendations → Tool Execution → Final Result
                ↓
        Tool Discovery via ADP
                ↓
        MCP Server (Calculator)
```

### Key Features

- ✅ **ADP-Compliant Tool Discovery** - Automatic discovery and registration of tools from processes
- ✅ **AI-Guided Task Execution** - Uses APUS Router for intelligent tool selection and sequencing  
- ✅ **Structured Tool Chains** - Executes multiple tools in sequence based on AI recommendations
- ✅ **Mock Testing Environment** - Complete testing setup with fake AI responses
- ✅ **Error Handling** - Comprehensive error handling and response validation

## 📁 File Structure

```
├── client.lua                  # MCP Client - discovers and uses tools
├── mcp-server.lua             # Calculator MCP Server - provides tools
├── mock-apus-router.lua       # Mock AI router for testing
├── test-mcp-integration.lua   # Complete integration test suite (requires aolite)
├── demo-mcp-flow.lua         # Standalone demo of MCP workflow
├── run-tests.lua             # Test verification and documentation
└── README.md                 # This file
```

## 🚀 Quick Start

### Prerequisites

- Lua 5.3+
- [aolite](https://github.com/perplex-labs/aolite) (for full integration tests)

### Basic Demo (No Dependencies)

Run the standalone demo to see the complete MCP workflow:

```bash
lua demo-mcp-flow.lua
```

This will show:
- Server tool discovery via ADP
- Client tool registration
- AI task analysis with mock responses
- Tool chain execution
- Result compilation

### Full Integration Testing (Requires aolite)

1. Install aolite:
```bash
# Follow instructions at https://github.com/perplex-labs/aolite
```

2. Run comprehensive tests:
```bash
lua test-mcp-integration.lua
```

### Test Verification

View test scenarios and verification:
```bash
lua run-tests.lua
```

## 🧪 Test Scenarios

### 1. Tool Discovery Flow
- Client sends `DiscoverProcess` to discover available tools
- Server responds with ADP-compliant handler information
- Client registers tools in internal registry

### 2. Direct Calculator Operations
- Test basic Add operation: `A=15, B=25 → Result: 40`
- Test basic Subtract operation: `A=50, B=20 → Result: 30`
- Verify calculation history and state management

### 3. AI-Guided Task Execution
- Send natural language task: "Please add 25 and 15 together"  
- AI analyzes task and recommends tool chain
- Client executes tools in sequence
- Final result compilation and response

### 4. Mock APUS Router Testing
- Predefined AI responses for common calculation tasks
- Structured JSON responses with tool recommendations
- Support for complex multi-step operations

## 📋 API Reference

### MCP Client Handlers

#### `DiscoverProcess`
Discover and register tools from an ADP-compliant process.
```lua
{
    Action = "DiscoverProcess",
    ProcessId = "target-process-id"
}
```

#### `ExecuteTask` 
Execute a task with AI-guided tool selection.
```lua
{
    Action = "ExecuteTask",
    Data = "Please add 20 and 30 together"
}
```

#### `ListTools`
List all discovered and registered tools.
```lua
{
    Action = "ListTools"
}
```

#### `UseTool`
Directly use a discovered tool.
```lua
{
    Action = "UseTool", 
    Tool = "process-id:Action",
    Data = '{"param1": "value1"}'
}
```

### MCP Server (Calculator) Handlers

#### `Add`
Add two numbers together.
```lua
{
    Action = "Add",
    A = "25",
    B = "15"
}
```

#### `Subtract`
Subtract second number from first.
```lua
{
    Action = "Subtract", 
    A = "50",
    B = "20"
}
```

#### `History`
Get calculation history.
```lua
{
    Action = "History",
    Limit = "10"  -- Optional
}
```

### Mock APUS Router

#### `Infer`
Get AI analysis and tool recommendations for a task.
```lua
{
    Action = "Infer",
    Data = "Task: add numbers\n\nAvailable tools: ...",
    ["X-Reference"] = "tracking-id"
}
```

## 🎯 Example Usage

### Simple Addition Task

```lua
-- 1. Discover calculator tools
send({
    Target = "mcp-client",
    Action = "DiscoverProcess", 
    ProcessId = "calculator-server"
})

-- 2. Execute AI-guided task
send({
    Target = "mcp-client",
    Action = "ExecuteTask",
    Data = "Please add 25 and 15 together"
})

-- Result: AI analyzes task, recommends Add tool, executes, returns 40
```

### Complex Multi-Step Task

```lua
send({
    Target = "mcp-client", 
    Action = "ExecuteTask",
    Data = "Add 20 and 30, then subtract 15 from the result"
})

-- Result: 
-- Step 1: Add(20, 30) = 50
-- Step 2: Subtract(50, 15) = 35
-- Final result: 35
```

## 🔧 Mock Data for Testing

The mock APUS router includes predefined responses for:

- **Calculator tasks**: "calculate", "add numbers", "complex math"
- **History queries**: "show history", "previous calculations" 
- **General tasks**: "hello", greeting responses
- **Default responses**: For unknown tasks

### Adding Custom Mock Responses

Edit `mock-apus-router.lua` and add to `MOCK_RESPONSES`:

```lua
["your task"] = {
    analysis = "Analysis of the task",
    tools_needed = {
        {
            tool = "process-id:Action",
            parameters = {param1 = "value1"},
            order = 1,
            description = "What this tool does"
        }
    },
    execution_plan = "Step by step plan"
}
```

## 📊 Test Results

When running the full test suite, you'll see results for:

- ✅ Process Initialization
- ✅ Server Info Handler (ADP compliance)  
- ✅ Tool Discovery Flow
- ✅ Calculator Operations (Add/Subtract)
- ✅ Mock APUS Inference
- ✅ AI-Guided Task Execution
- ✅ Tool Listing

Expected success rate: **≥80%** for passing tests.

## 🐛 Troubleshooting

### Common Issues

1. **"Tool not found in registry"**
   - Ensure tools are discovered before use
   - Check process IDs match between client and server

2. **"No response from APUS Router"**
   - Verify mock APUS router is loaded
   - Check APUS_ROUTER process ID in client.lua

3. **"Invalid ADP response"**
   - Ensure server implements proper Info handler
   - Verify JSON structure in responses

### Debug Mode

Enable verbose logging by setting `VERBOSE_LOGGING = true` in test files.

## Implementation Details

### client.lua
Advanced MCP client that combines AI-guided tool selection with automatic execution capabilities.

**Key Features:**
- **Calculator Operations**: Addition and subtraction with validation
- **Operation History**: Tracks last 100 operations with timestamps
- **Tool Chain Support**: Echoes back chain coordination tags for automatic execution
- **ADP v1.0 Compliance**: Complete handler documentation with parameters and examples
- **Error Handling**: Comprehensive validation with structured error responses

**Handlers:**
- `Add` - Add two numbers (A + B = result)
- `Subtract` - Subtract second number from first (A - B = result)  
- `History` - Get calculation history with optional limit parameter
- `Clear` - Clear all calculation history
- `Info` - ADP-compliant process information with complete tool documentation

## ADP Compliance

Both processes implement ADP v1.0 specification with:

- **Protocol Version**: "1.0" in Info responses
- **Handler Definitions**: Complete handler metadata with tags, types, and validation
- **Capabilities**: Process capabilities and feature flags
- **Tag Validation**: Type checking and requirement validation
- **Categorization**: Logical grouping of handlers by function

## Usage

### Deploy as AO Processes

1. Deploy `client.lua` as an AO process for MCP client with AI-guided tool execution
2. Deploy `mcp-server.lua` as an AO process for calculator MCP server functionality
3. Note the process IDs for interaction

### Client Discovery & Tool Registration

#### Discover Calculator Process
```lua
-- Register the calculator process with the MCP client
Send({
    Target = "CLIENT_PROCESS_ID",
    Action = "DiscoverProcess",
    ["Process-Id"] = "CALCULATOR_PROCESS_ID",
    ["Process-Name"] = "Calculator Server"
})
```

The client will automatically:
1. Query the calculator's `Info` handler
2. Parse ADP response and register available tools
3. Make tools available for AI-guided execution

#### List Discovered Tools
```lua
Send({
    Target = "CLIENT_PROCESS_ID",
    Action = "ListTools"
})
```

### AI-Guided Task Execution

#### Execute Tasks with Automatic Tool Selection
```lua
-- AI will analyze task and automatically use calculator tools
Send({
    Target = "CLIENT_PROCESS_ID",
    Action = "ExecuteTask",
    Data = "Calculate 15 + 25 and then subtract 10 from the result",
    ["X-Session"] = "calc-session-1"
})

-- Simple calculation task
Send({
    Target = "CLIENT_PROCESS_ID", 
    Action = "ExecuteTask",
    Data = "What is 45 minus 23?"
})

-- Multi-step calculation
Send({
    Target = "CLIENT_PROCESS_ID",
    Action = "ExecuteTask", 
    Data = "Add 100 and 50, then show me the calculation history"
})
```

### Direct Tool Usage

#### Use Individual Tools Directly
```lua
-- Direct tool execution (bypasses AI)
Send({
    Target = "CLIENT_PROCESS_ID",
    Action = "UseTool",
    Tool = "CALCULATOR_PROCESS_ID:Add",
    A = "25",
    B = "17"
})

-- Check calculation history
Send({
    Target = "CLIENT_PROCESS_ID", 
    Action = "UseTool",
    Tool = "CALCULATOR_PROCESS_ID:History",
    Limit = "10"
})
```

### Direct Calculator Interaction

You can also interact directly with the calculator:

```lua
-- Add two numbers
Send({
    Target = "CALCULATOR_PROCESS_ID",
    Action = "Add",
    A = "10", 
    B = "5"
})

-- Subtract numbers
Send({
    Target = "CALCULATOR_PROCESS_ID",
    Action = "Subtract",
    A = "20",
    B = "8" 
})
```

### Get Process Information

Both processes support ADP-compliant Info requests:

```lua
Send({
    Target = "PROCESS_ID", 
    Action = "Info"
})
```

**Client Info Response includes:**
- Protocol version and MCP capabilities
- Registry of discovered processes and tools
- Session tracking statistics
- Available handler documentation

**Calculator Info Response exposes:**
- **Complete Tool Documentation**: `Add`, `Subtract`, `History`, `Clear` with full ADP metadata
- **Parameter Specifications**: Type definitions, requirements, examples, validation rules
- **Operation Statistics**: Total operations performed, history count, handler metrics
- **Tool Chain Compatibility**: Confirms support for automatic tool chain execution

This ADP-compliant information enables the MCP client to automatically discover, validate, and register calculator tools for AI-guided execution.

## Architecture

```
                              ┌─────────────────┐
                              │   APUS Router   │ 
                              │   AI Inference  │
                              └─────────┬───────┘
                                        │
                                        ▼
┌─────────────────┐             ┌─────────────────┐             ┌─────────────────┐
│      User       │────────────▶│  MCP Client     │◀───────────▶│  Calculator     │
│   Messages      │             │  (client.lua)   │             │  MCP Server     │
└─────────────────┘             └─────────────────┘             │ (mcp-server.lua)│
                                        │                       └─────────────────┘
                                        ▼
                              ┌─────────────────┐
                              │  Tool Registry  │
                              │ & Chain Executor│
                              └─────────────────┘
```

**AI-Guided Tool Chain Flow:**

1. **Tool Discovery**: MCP Client queries Calculator `Info` handler via ADP
2. **Registration**: Calculator tools (`Add`, `Subtract`, `History`, `Clear`) registered in tool registry
3. **Task Analysis**: User sends task → Client forwards to APUS Router for AI analysis  
4. **Tool Recommendation**: AI returns structured JSON with recommended tools and parameters
5. **Automatic Execution**: Client executes tool chain automatically based on AI recommendations
6. **Chain Coordination**: Calculator echoes back chain reference tags for sequential execution
7. **Result Compilation**: Client compiles all tool results and returns final response

**Key Features:**
- **Automatic Discovery**: ADP-compliant tool discovery and registration
- **AI-Guided Selection**: APUS Router analyzes tasks and recommends appropriate tools
- **Chain Execution**: Sequential tool execution with automatic coordination
- **Error Handling**: Comprehensive error handling and result validation
- **Session Support**: Context continuity across multiple interactions

## Example Interactions

### Complete AI-Guided Calculation Flow

```lua
-- 1. Discover calculator process
Send({
    Target = "CLIENT_PROCESS_ID",
    Action = "DiscoverProcess", 
    ["Process-Id"] = "CALC_PROCESS_ID",
    ["Process-Name"] = "Calculator"
})

-- 2. Execute complex multi-step calculation
Send({
    Target = "CLIENT_PROCESS_ID",
    Action = "ExecuteTask",
    Data = "Calculate 25 + 15, then subtract 8 from the result, and show me the history"
})
```

**What happens automatically:**
1. Client queries calculator `Info` handler and registers tools
2. Client sends task to APUS Router for analysis
3. AI recommends tool chain: `[{"tool": "CALC:Add", "parameters": {"A": "25", "B": "15"}, "order": 1}, {"tool": "CALC:Subtract", "parameters": {"A": "40", "B": "8"}, "order": 2}, {"tool": "CALC:History", "parameters": {"Limit": "5"}, "order": 3}]`
4. Client executes tools sequentially with chain coordination tags
5. Calculator processes each operation and echoes back chain tags
6. `ToolChainResponse` handler coordinates automatic progression through the chain
7. Client compiles final result: `"Calculation complete: 25 + 15 = 40, 40 - 8 = 32. Recent history shows 3 operations."`

### Task Status Monitoring

```lua
-- Check status of running task
Send({
    Target = "CLIENT_PROCESS_ID",
    Action = "Status",
    ["Reference"] = "task-reference-id"
})
```

## Future Enhancements

- **Multi-Process Discovery**: Registry-based automatic discovery of multiple MCP servers
- **Advanced Tool Chaining**: Parallel execution and conditional branching
- **Schema Validation**: JSON schema support for enhanced parameter validation  
- **Real-Time Updates**: Dynamic capability updates and tool versioning
- **Batch Operations**: Efficient bulk operation processing
- **Tool Composition**: Combining multiple tools into composite operations