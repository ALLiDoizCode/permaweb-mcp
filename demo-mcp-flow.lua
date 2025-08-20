#!/usr/bin/env lua

-- Demo MCP Flow - Standalone demonstration of MCP client-server interaction
-- This script simulates the complete MCP workflow without requiring aolite
-- Shows how the client discovers tools and executes AI-guided tasks

-- ANSI color codes for better output
local colors = {
    reset = "\27[0m",
    bold = "\27[1m", 
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m"
}

-- Helper function for colored output
local function colorPrint(color, text)
    print(color .. text .. colors.reset)
end

-- Simulate JSON encoding/decoding
local json = {
    encode = function(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                local key = '"' .. tostring(k) .. '"'
                local value
                if type(v) == "string" then
                    value = '"' .. v .. '"'
                elseif type(v) == "table" then
                    value = json.encode(v)
                else
                    value = tostring(v)
                end
                table.insert(parts, key .. ":" .. value)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        else
            return '"' .. tostring(obj) .. '"'
        end
    end,
    
    decode = function(str)
        -- Simple JSON parser for demo purposes
        -- In real implementation, would use proper JSON library
        return {}
    end
}

-- Demo function: Server Info Response
local function simulateServerInfo()
    colorPrint(colors.cyan, "\n🏠 Step 1: Calculator Server Info Response")
    colorPrint(colors.yellow, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local serverInfo = {
        protocolVersion = "1.0",
        name = "Calculator MCP Server",
        version = "1.0.0", 
        description = "Calculator process providing addition and subtraction as MCP tools",
        handlers = {
            {
                action = "Add",
                description = "Add two numbers together",
                tags = {
                    {name = "A", type = "number", required = true},
                    {name = "B", type = "number", required = true}
                },
                category = "calculator"
            },
            {
                action = "Subtract", 
                description = "Subtract second number from first number",
                tags = {
                    {name = "A", type = "number", required = true},
                    {name = "B", type = "number", required = true}
                },
                category = "calculator"
            },
            {
                action = "History",
                description = "Get calculation history",
                category = "utility"
            }
        },
        capabilities = {
            adpCompliant = true,
            mcpVersion = "2024-11-05"
        }
    }
    
    print("📤 Server Response (ADP-compliant):")
    print("   Protocol Version: " .. serverInfo.protocolVersion)
    print("   Process Name: " .. serverInfo.name)
    print("   Available Handlers: " .. #serverInfo.handlers)
    
    for i, handler in ipairs(serverInfo.handlers) do
        print("   " .. i .. ". " .. handler.action .. " (" .. handler.category .. ")")
        print("      Description: " .. handler.description)
        if handler.tags then
            print("      Parameters: " .. #handler.tags .. " required")
        end
    end
    
    colorPrint(colors.green, "✅ Server provides ADP-compliant tool information")
    return serverInfo
end

-- Demo function: Client Tool Registration
local function simulateToolRegistration(serverInfo)
    colorPrint(colors.cyan, "\n🔧 Step 2: Client Tool Registration")
    colorPrint(colors.yellow, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local toolRegistry = {
        processes = {},
        tools = {}
    }
    
    -- Simulate client registering tools from server info
    local processId = "calculator-server-123"
    toolRegistry.processes[processId] = {
        name = serverInfo.name,
        version = serverInfo.version,
        registeredAt = os.time()
    }
    
    print("📥 Client registering tools from process: " .. processId)
    
    local toolCount = 0
    for _, handler in ipairs(serverInfo.handlers) do
        if handler.category ~= "core" then
            local toolKey = processId .. ":" .. handler.action
            toolRegistry.tools[toolKey] = {
                processId = processId,
                action = handler.action,
                description = handler.description,
                category = handler.category,
                parameters = handler.tags or {}
            }
            toolCount = toolCount + 1
            print("   ✓ Registered tool: " .. toolKey)
        end
    end
    
    colorPrint(colors.green, "✅ Client registered " .. toolCount .. " tools successfully")
    return toolRegistry
end

-- Demo function: Mock APUS AI Analysis
local function simulateAIAnalysis(task)
    colorPrint(colors.cyan, "\n🤖 Step 3: AI Task Analysis (Mock APUS Router)")
    colorPrint(colors.yellow, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    print("📝 Task received: \"" .. task .. "\"")
    print("🧠 AI analyzing task and available tools...")
    
    -- Simulate AI processing delay
    print("   Processing...")
    os.execute("sleep 1")
    
    local aiResponse = {
        analysis = "This task requires adding two numbers. I can use the calculator Add tool.",
        tools_needed = {
            {
                tool = "calculator-server-123:Add",
                parameters = {A = "25", B = "15"},
                order = 1,
                description = "Add 25 and 15 to get the sum"
            }
        },
        execution_plan = "Execute the Add tool with A=25 and B=15 to complete the calculation."
    }
    
    print("🎯 AI Analysis Result:")
    print("   Analysis: " .. aiResponse.analysis)
    print("   Tools needed: " .. #aiResponse.tools_needed)
    print("   Execution plan: " .. aiResponse.execution_plan)
    
    if #aiResponse.tools_needed > 0 then
        print("📋 Recommended tool chain:")
        for i, tool in ipairs(aiResponse.tools_needed) do
            print("   " .. i .. ". " .. tool.tool)
            print("      Parameters: A=" .. tool.parameters.A .. ", B=" .. tool.parameters.B)
            print("      Description: " .. tool.description)
        end
    end
    
    colorPrint(colors.green, "✅ AI provided structured tool execution plan")
    return aiResponse
end

-- Demo function: Tool Chain Execution
local function simulateToolExecution(aiResponse, toolRegistry)
    colorPrint(colors.cyan, "\n⚡ Step 4: Tool Chain Execution")
    colorPrint(colors.yellow, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local results = {}
    
    print("🔄 Executing " .. #aiResponse.tools_needed .. " tools in sequence...")
    
    for i, toolSpec in ipairs(aiResponse.tools_needed) do
        print("\n   Tool " .. i .. "/" .. #aiResponse.tools_needed .. ": " .. toolSpec.tool)
        
        -- Look up tool in registry
        local tool = toolRegistry.tools[toolSpec.tool]
        if tool then
            print("   📤 Sending message to " .. tool.processId)
            print("      Action: " .. tool.action)
            print("      Parameters: A=" .. toolSpec.parameters.A .. ", B=" .. toolSpec.parameters.B)
            
            -- Simulate tool execution based on action
            local result
            if tool.action == "Add" then
                local a = tonumber(toolSpec.parameters.A)
                local b = tonumber(toolSpec.parameters.B)
                result = {
                    success = true,
                    operation = "addition",
                    operand1 = a,
                    operand2 = b,
                    result = a + b,
                    message = a .. " + " .. b .. " = " .. (a + b)
                }
                print("   📥 Response: " .. result.message)
            elseif tool.action == "Subtract" then
                local a = tonumber(toolSpec.parameters.A)
                local b = tonumber(toolSpec.parameters.B)
                result = {
                    success = true,
                    operation = "subtraction", 
                    operand1 = a,
                    operand2 = b,
                    result = a - b,
                    message = a .. " - " .. b .. " = " .. (a - b)
                }
                print("   📥 Response: " .. result.message)
            end
            
            table.insert(results, {
                toolIndex = i,
                tool = toolSpec.tool,
                success = result.success,
                data = result,
                timestamp = os.time()
            })
            
            colorPrint(colors.green, "   ✅ Tool executed successfully")
        else
            print("   ❌ Tool not found in registry")
            table.insert(results, {
                toolIndex = i,
                tool = toolSpec.tool,
                success = false,
                error = "Tool not found in registry"
            })
        end
    end
    
    colorPrint(colors.green, "✅ Tool chain execution completed")
    return results
end

-- Demo function: Final Result Compilation
local function simulateFinalResult(task, aiResponse, toolResults)
    colorPrint(colors.cyan, "\n📊 Step 5: Final Result Compilation")
    colorPrint(colors.yellow, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local successfulTools = 0
    local failedTools = 0
    
    for _, result in ipairs(toolResults) do
        if result.success then
            successfulTools = successfulTools + 1
        else
            failedTools = failedTools + 1
        end
    end
    
    local finalResult = {
        reference = "demo-task-" .. os.time(),
        task = task,
        aiAnalysis = aiResponse.analysis,
        executionPlan = aiResponse.execution_plan,
        toolsUsed = #toolResults,
        successfulTools = successfulTools,
        failedTools = failedTools,
        toolResults = toolResults,
        completed = true
    }
    
    print("📋 Task Execution Summary:")
    print("   Original Task: " .. finalResult.task)
    print("   Tools Used: " .. finalResult.toolsUsed)
    print("   Successful: " .. finalResult.successfulTools)
    print("   Failed: " .. finalResult.failedTools)
    print("   AI Analysis: " .. finalResult.aiAnalysis)
    
    if successfulTools > 0 then
        print("\n🎯 Results:")
        for _, result in ipairs(toolResults) do
            if result.success and result.data then
                print("   " .. result.data.message)
            end
        end
    end
    
    colorPrint(colors.green, "✅ Task completed successfully with AI guidance")
    return finalResult
end

-- Main demonstration function
local function runMCPDemo()
    colorPrint(colors.bold .. colors.magenta, "🚀 MCP Integration Flow Demonstration")
    colorPrint(colors.bold .. colors.magenta, "════════════════════════════════════════")
    
    print("This demo shows the complete MCP (Model Context Protocol) workflow:")
    print("1. Server exposes tools via ADP (Action Documentation Protocol)")
    print("2. Client discovers and registers available tools")
    print("3. AI analyzes tasks and recommends tool usage")
    print("4. Client executes tool chains based on AI guidance")
    print("5. Results are compiled and returned to user")
    
    -- Simulate the complete flow
    local task = "Please add 25 and 15 together"
    colorPrint(colors.bold, "\n🎯 Demo Task: \"" .. task .. "\"")
    
    local serverInfo = simulateServerInfo()
    local toolRegistry = simulateToolRegistration(serverInfo)
    local aiResponse = simulateAIAnalysis(task)
    local toolResults = simulateToolExecution(aiResponse, toolRegistry)
    local finalResult = simulateFinalResult(task, aiResponse, toolResults)
    
    -- Demo conclusion
    colorPrint(colors.cyan, "\n🏁 Demo Completed Successfully!")
    colorPrint(colors.yellow, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    print("Key MCP Features Demonstrated:")
    print("✓ ADP-compliant tool discovery")
    print("✓ Dynamic tool registration")
    print("✓ AI-guided task analysis") 
    print("✓ Structured tool chain execution")
    print("✓ Comprehensive result compilation")
    
    print("\nActual Files for Testing:")
    print("• client.lua - Full MCP client implementation")
    print("• mcp-server.lua - Calculator server with ADP compliance")
    print("• mock-apus-router.lua - Mock AI router for testing")
    print("• test-mcp-integration.lua - Complete test suite using aolite")
    
    colorPrint(colors.green, "\n🎉 MCP Integration is ready for testing!")
end

-- Execute the demonstration
runMCPDemo()