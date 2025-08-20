# Permaweb MCP Implementation

This repository contains a pure Lua implementation of MCP (Model Context Protocol) for the Permaweb using AO processes. The client discovers tools from ADP-compliant processes and uses AI inference to automatically select and execute tool chains.

## Files

### client.lua
Advanced MCP client that combines AI-guided tool selection with automatic execution capabilities.

**Key Features:**
- **Tool Discovery**: Automatically discovers tools from ADP-compliant AO processes
- **AI-Guided Execution**: Uses APUS Router to analyze tasks and recommend tool usage
- **Automatic Tool Chains**: Executes sequences of tools based on AI recommendations
- **Process Registry**: Maintains registry of discovered processes and their capabilities
- **Session Support**: Context continuity across multiple interactions
- **ADP v1.0 Compliance**: Full protocol compliance for process discovery

**Core Handlers:**
- `DiscoverProcess` - Discover and register tools from ADP-compliant processes
- `ProcessInfo` - Handle ADP Info responses and tool registration  
- `ListTools` - List all registered tools and processes
- `UseTool` - Execute individual tools directly
- `ExecuteTask` - AI-guided task execution with automatic tool selection
- `SendInfer` - Send inference requests to APUS Router
- `AcceptResponse` - Process AI responses and execute recommended tools
- `ToolChainResponse` - Handle tool execution responses and continue chains
- `Status` - Check status of tasks and tool executions
- `Info` - ADP-compliant process information

### mcp-server.lua
Calculator MCP server process that provides arithmetic operations as discoverable tools via ADP, with full support for automatic tool chain execution.

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