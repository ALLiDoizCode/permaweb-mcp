-- MCP Client for AO/Permaweb Implementation
-- This client discovers and uses tools from ADP-compliant processes
-- while using APUS Router for AI inference to guide tool selection

-- APUS Router Process ID
APUS_ROUTER = "Bf6JJR2tl2Wr38O2-H6VctqtduxHgKF-NzRB9HhTRzo"

-- Task tracking storage
Tasks = Tasks or {}

-- Tool registry for discovered ADP tools
ToolRegistry = ToolRegistry or {
    processes = {},
    tools = {},
    initialized = false
}

-- Generate a unique reference ID for tracking requests
local function generateReference()
    return tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
end

-- Execute a chain of tools based on AI recommendations
local function executeToolChain(taskReference, toolIndex)
    local task = Tasks[taskReference]
    if not task or not task.toolsToExecute or toolIndex > #task.toolsToExecute then
        -- All tools executed, compile final result
        finalizeToolExecution(taskReference)
        return
    end
    
    local toolSpec = task.toolsToExecute[toolIndex]
    local toolKey = toolSpec.tool
    local tool = ToolRegistry.tools[toolKey]
    
    if not tool then
        -- Tool not found, record error and continue
        table.insert(task.toolResults, {
            toolIndex = toolIndex,
            tool = toolKey,
            success = false,
            error = "Tool not found in registry",
            timestamp = os.time()
        })
        executeToolChain(taskReference, toolIndex + 1)
        return
    end
    
    -- Build message tags from AI-recommended parameters
    local messageTags = { Action = tool.action }
    if toolSpec.parameters and type(toolSpec.parameters) == "table" then
        for key, value in pairs(toolSpec.parameters) do
            messageTags[key] = tostring(value)
        end
    end
    
    -- Track this tool execution
    task.currentToolIndex = toolIndex
    task.currentToolReference = generateReference()
    
    print("Executing tool " .. toolIndex .. "/" .. #task.toolsToExecute .. ": " .. toolKey)
    
    -- Send tool execution request
    ao.send({
        Target = tool.processId,
        Tags = messageTags,
        ["Tool-Chain-Reference"] = taskReference,
        ["Tool-Index"] = tostring(toolIndex),
        ["Tool-Reference"] = task.currentToolReference
    })
end

-- Finalize tool execution and send comprehensive result
local function finalizeToolExecution(taskReference)
    local task = Tasks[taskReference]
    if not task then return end
    
    task.status = "success"
    local successfulTools = 0
    local failedTools = 0
    
    for _, result in ipairs(task.toolResults) do
        if result.success then
            successfulTools = successfulTools + 1
        else
            failedTools = failedTools + 1
        end
    end
    
    ao.send({
        Target = task.requestor,
        Action = "Task-Completed",
        Data = json.encode({
            reference = taskReference,
            task = task.task,
            aiAnalysis = task.aiAnalysis,
            executionPlan = task.executionPlan,
            toolsUsed = #task.toolResults,
            successfulTools = successfulTools,
            failedTools = failedTools,
            toolResults = task.toolResults,
            duration = os.time() - task.starttime,
            completed = true
        })
    })
    
    print("Tool chain execution completed for task: " .. task.task .. 
          " (Success: " .. successfulTools .. ", Failed: " .. failedTools .. ")")
end

-- Initialize the MCP client
local function initializeMCPClient()
    if not ToolRegistry.initialized then
        ToolRegistry.processes = {}
        ToolRegistry.tools = {}
        ToolRegistry.initialized = true
        print("MCP Client initialized - ready to discover tools")
    end
end

-- Register tools from an ADP-compliant process
local function registerToolsFromProcess(processId, adpInfo)
    if not adpInfo.handlers then
        return false
    end

    ToolRegistry.processes[processId] = {
        name = adpInfo.name or "Unknown Process",
        version = adpInfo.version or "1.0.0",
        description = adpInfo.description or "",
        capabilities = adpInfo.capabilities or {},
        registeredAt = os.time()
    }

    local toolCount = 0
    for _, handler in ipairs(adpInfo.handlers) do
        if handler.category ~= "core" then -- Skip core handlers like Info
            local toolKey = processId .. ":" .. handler.action
            ToolRegistry.tools[toolKey] = {
                processId = processId,
                action = handler.action,
                description = handler.description or "",
                parameters = handler.tags or {},
                category = handler.category or "general",
                examples = handler.examples or {}
            }
            toolCount = toolCount + 1
        end
    end

    print("Registered " .. toolCount .. " tools from " .. (adpInfo.name or processId))
    return true
end

-- Handler: Discover tools from a process via ADP
Handlers.add("DiscoverProcess", Handlers.utils.hasMatchingTag("Action", "DiscoverProcess"),
    function(msg)
        local processId = msg.Tags.ProcessId or msg.Tags.Process

        if not processId then
            ao.send({
                Target = msg.From,
                Action = "DiscoverProcess-Response",
                Data = json.encode({
                    success = false,
                    error = "ProcessId is required"
                })
            })
            return
        end

        initializeMCPClient()

        -- Request Info from the target process to discover tools
        ao.send({
            Target = processId,
            Action = "Info"
        })

        ao.send({
            Target = msg.From,
            Action = "DiscoverProcess-Response",
            Data = json.encode({
                success = true,
                processId = processId,
                message = "Tool discovery initiated for process: " .. processId
            })
        })
    end
)

-- Handler: Receive tool execution responses during chain execution
Handlers.add("ToolChainResponse", function(msg)
    local chainReference = msg.Tags["Tool-Chain-Reference"]
    local toolIndex = tonumber(msg.Tags["Tool-Index"])
    
    if chainReference and toolIndex and Tasks[chainReference] then
        local task = Tasks[chainReference]
        
        -- Record tool result
        local result = {
            toolIndex = toolIndex,
            tool = task.toolsToExecute[toolIndex].tool,
            success = false,
            timestamp = os.time(),
            response = msg.Data
        }
        
        -- Check if this looks like a successful response
        local success, responseData = pcall(json.decode, msg.Data or "{}")
        if success and responseData and responseData.success ~= false then
            result.success = true
            result.data = responseData
        elseif msg.Data and not msg.Data:find("error") and not msg.Data:find("failed") then
            result.success = true
        else
            result.error = msg.Data or "Unknown error"
        end
        
        table.insert(task.toolResults, result)
        
        print("Tool " .. toolIndex .. " completed: " .. (result.success and "SUCCESS" or "FAILED"))
        
        -- Continue with next tool in chain
        executeToolChain(chainReference, toolIndex + 1)
    end
end, "Tool-Chain-Reference")

-- Handler: Receive ADP Info responses and register tools
Handlers.add("ProcessInfo", Handlers.utils.hasMatchingTag("Action", "Info-Response"),
    function(msg)
        initializeMCPClient()

        local success, adpInfo = pcall(json.decode, msg.Data)
        if not success or not adpInfo then
            print("Failed to parse ADP info from " .. msg.From)
            return
        end

        if adpInfo.protocolVersion == "1.0" and adpInfo.handlers then
            registerToolsFromProcess(msg.From, adpInfo)
        else
            print("Process " .. msg.From .. " is not ADP v1.0 compliant")
        end
    end
)

-- Handler: List available tools
Handlers.add("ListTools", Handlers.utils.hasMatchingTag("Action", "ListTools"),
    function(msg)
        initializeMCPClient()

        local toolList = {}
        for toolKey, tool in pairs(ToolRegistry.tools) do
            table.insert(toolList, {
                key = toolKey,
                process = ToolRegistry.processes[tool.processId].name,
                processId = tool.processId,
                action = tool.action,
                description = tool.description,
                category = tool.category,
                parameterCount = #tool.parameters
            })
        end

        ao.send({
            Target = msg.From,
            Action = "ListTools-Response",
            Data = json.encode({
                success = true,
                tools = toolList,
                processCount = #ToolRegistry.processes,
                toolCount = #toolList
            })
        })
    end
)

-- Handler: Use a discovered tool
Handlers.add("UseTool", Handlers.utils.hasMatchingTag("Action", "UseTool"),
    function(msg)
        local toolKey = msg.Tags.Tool
        local paramsJson = msg.Data or "{}"

        if not toolKey then
            ao.send({
                Target = msg.From,
                Action = "UseTool-Response",
                Data = json.encode({
                    success = false,
                    error = "Tool key is required"
                })
            })
            return
        end

        local tool = ToolRegistry.tools[toolKey]
        if not tool then
            ao.send({
                Target = msg.From,
                Action = "UseTool-Response",
                Data = json.encode({
                    success = false,
                    error = "Tool not found: " .. toolKey
                })
            })
            return
        end

        local success, params = pcall(json.decode, paramsJson)
        if not success then
            params = {}
        end

        -- Build message tags from parameters
        local messageTags = { Action = tool.action }
        for key, value in pairs(params) do
            messageTags[key] = tostring(value)
        end

        -- Call the tool on its process
        ao.send({
            Target = tool.processId,
            Tags = messageTags
        })

        ao.send({
            Target = msg.From,
            Action = "UseTool-Response",
            Data = json.encode({
                success = true,
                tool = toolKey,
                processId = tool.processId,
                action = tool.action,
                message = "Tool called successfully"
            })
        })
    end
)

-- Handler: AI-guided task execution with tool selection
Handlers.add("ExecuteTask", Handlers.utils.hasMatchingTag("Action", "ExecuteTask"),
    function(msg)
        local task = msg.Data or msg.Tags.Task
        local reference = msg.Tags.Reference or generateReference()

        if not task then
            ao.send({
                Target = msg.From,
                Action = "ExecuteTask-Response",
                Data = json.encode({
                    success = false,
                    error = "Task description is required"
                })
            })
            return
        end

        initializeMCPClient()

        -- Build context about available tools for the AI
        local toolContext = "Available tools:\n"
        for toolKey, tool in pairs(ToolRegistry.tools) do
            toolContext = toolContext .. "- " .. tool.action .. " (" .. tool.category .. "): " .. tool.description .. "\n"
        end

        -- Create enhanced prompt for APUS Router with structured response format
        local enhancedPrompt = "Task: " .. task .. "\n\n" .. toolContext .. "\nAnalyze this task and provide a JSON response with the following structure:\n{\n  \"analysis\": \"your analysis of the task\",\n  \"tools_needed\": [\n    {\n      \"tool\": \"ProcessId:Action\",\n      \"parameters\": {\"param1\": \"value1\"},\n      \"order\": 1,\n      \"description\": \"what this tool does\"\n    }\n  ],\n  \"execution_plan\": \"step by step plan\"\n}\n\nIf no tools are needed, set tools_needed to an empty array."

        -- Track the task
        Tasks[reference] = {
            task = task,
            prompt = enhancedPrompt,
            status = "processing",
            starttime = os.time(),
            reference = reference,
            requestor = msg.From
        }

        -- Send to APUS Router for AI analysis
        ao.send({
            Target = APUS_ROUTER,
            Action = "Infer",
            Data = enhancedPrompt,
            ["X-Reference"] = reference,
            ["X-Context"] = "tool-guided-execution"
        })

        ao.send({
            Target = msg.From,
            Action = "ExecuteTask-Response",
            Data = json.encode({
                success = true,
                reference = reference,
                task = task,
                message = "Task analysis initiated with AI guidance",
                availableTools = #ToolRegistry.tools
            })
        })
    end
)

-- Handler: Regular inference (kept for compatibility)
Handlers.add("SendInfer", Handlers.utils.hasMatchingTag("Action", "Infer"),
    function(msg)
        local reference = msg["X-Reference"] or msg.Reference or generateReference()

        -- Build the inference request
        local request = {
            Target = APUS_ROUTER,
            Action = "Infer",
            ["X-Prompt"] = msg.Data,
            ["X-Reference"] = reference
        }

        -- Add optional parameters if provided
        if msg["X-Session"] then
            request["X-Session"] = msg["X-Session"]
        end
        if msg["X-Options"] then
            request["X-Options"] = msg["X-Options"]
        end

        -- Track the task
        Tasks[reference] = {
            prompt = request["X-Prompt"],
            status = "processing",
            starttime = os.time(),
            reference = reference,
            requestor = msg.From
        }

        -- Send the request to APUS Router
        ao.send(request)

        -- Send confirmation back to requester
        ao.send({
            Target = msg.From,
            Action = "Infer-Submitted",
            Data = "Inference request submitted with reference: " .. reference,
            ["X-Reference"] = reference
        })
    end
)

-- Handler: Receive responses from APUS Router
Handlers.add("AcceptResponse", Handlers.utils.hasMatchingTag("Action", "Infer-Response"),
    function(msg)
        local reference = msg.Tags["X-Reference"] or ""

        if not Tasks[reference] then
            print("Received response for unknown reference: " .. reference)
            return
        end

        local task = Tasks[reference]

        -- Check for error responses
        if msg.Tags["Code"] then
            Tasks[reference].status = "failed"
            Tasks[reference].error_message = msg.Tags["Message"] or "Unknown error"
            Tasks[reference].error_code = msg.Tags["Code"]
            Tasks[reference].endtime = os.time()

            if task.requestor then
                ao.send({
                    Target = task.requestor,
                    Action = "Task-Failed",
                    Data = json.encode({
                        reference = reference,
                        error = Tasks[reference].error_message
                    })
                })
            end

            print("Inference failed for reference " .. reference .. ": " .. Tasks[reference].error_message)
            return
        end

        -- Process successful response
        Tasks[reference].response = msg.Data or ""
        Tasks[reference].endtime = os.time()
        Tasks[reference].duration = Tasks[reference].endtime - Tasks[reference].starttime

        -- Check if this was a tool-guided execution and parse AI response for tool recommendations
        if task.requestor and task.task then
            -- Try to parse AI response as JSON to extract tool recommendations
            local success, aiResponse = pcall(json.decode, Tasks[reference].response)
            
            if success and aiResponse and aiResponse.tools_needed and type(aiResponse.tools_needed) == "table" then
                -- AI provided structured response with tool recommendations
                Tasks[reference].status = "executing-tools"
                Tasks[reference].toolsToExecute = aiResponse.tools_needed
                Tasks[reference].aiAnalysis = aiResponse.analysis or ""
                Tasks[reference].executionPlan = aiResponse.execution_plan or ""
                Tasks[reference].toolResults = {}
                
                print("AI recommended " .. #aiResponse.tools_needed .. " tools for task: " .. task.task)
                
                if #aiResponse.tools_needed > 0 then
                    -- Execute tools in order
                    executeToolChain(reference, 1)
                else
                    -- No tools needed, send AI analysis as final result
                    Tasks[reference].status = "success"
                    ao.send({
                        Target = task.requestor,
                        Action = "Task-Completed",
                        Data = json.encode({
                            reference = reference,
                            task = task.task,
                            aiAnalysis = aiResponse.analysis,
                            executionPlan = aiResponse.execution_plan,
                            toolsUsed = 0,
                            duration = Tasks[reference].duration
                        })
                    })
                end
            else
                -- AI provided unstructured response, treat as regular inference
                Tasks[reference].status = "success"
                ao.send({
                    Target = task.requestor,
                    Action = "Task-Completed",
                    Data = json.encode({
                        reference = reference,
                        task = task.task,
                        response = Tasks[reference].response,
                        duration = Tasks[reference].duration,
                        note = "AI provided unstructured response - no automatic tool execution"
                    })
                })
            end
        else
            -- Regular inference task
            Tasks[reference].status = "success"
        end

        if Tasks[reference].status == "success" then
            print("Task completed for reference " .. reference .. " in " .. Tasks[reference].duration .. " seconds")
        end
    end
)

-- Handler: Check status of tasks or tools
Handlers.add("Status", Handlers.utils.hasMatchingTag("Action", "Status"),
    function(msg)
        local reference = msg.Tags["Reference"] or msg.Tags["X-Reference"]

        if reference then
            -- Status of specific task
            local task = Tasks[reference]
            if not task then
                ao.send({
                    Target = msg.From,
                    Action = "Status-Response",
                    Data = json.encode({
                        success = false,
                        error = "Task not found for reference: " .. reference
                    })
                })
                return
            end

            local response_data = {
                reference = reference,
                status = task.status,
                starttime = task.starttime
            }

            if task.task then
                response_data.task = task.task
            end
            if task.prompt then
                response_data.prompt = string.sub(task.prompt, 1, 200) .. "..."
            end

            if task.status == "success" then
                response_data.response = task.response
                response_data.endtime = task.endtime
                response_data.duration = task.duration
            elseif task.status == "failed" then
                response_data.error_message = task.error_message
                response_data.error_code = task.error_code
                response_data.endtime = task.endtime
            end

            ao.send({
                Target = msg.From,
                Action = "Status-Response",
                Data = json.encode(response_data)
            })
        else
            -- General status
            initializeMCPClient()

            local activeCount = 0
            local completedCount = 0
            local failedCount = 0

            for _, task in pairs(Tasks) do
                if task.status == "processing" then
                    activeCount = activeCount + 1
                elseif task.status == "success" then
                    completedCount = completedCount + 1
                elseif task.status == "failed" then
                    failedCount = failedCount + 1
                end
            end

            ao.send({
                Target = msg.From,
                Action = "Status-Response",
                Data = json.encode({
                    success = true,
                    mcp = {
                        registeredProcesses = #ToolRegistry.processes,
                        availableTools = #ToolRegistry.tools
                    },
                    tasks = {
                        active = activeCount,
                        completed = completedCount,
                        failed = failedCount,
                        total = activeCount + completedCount + failedCount
                    }
                })
            })
        end
    end
)

-- ADP-compliant Info handler for MCP client
Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        initializeMCPClient()

        local adpInfo = {
            protocolVersion = "1.0",
            name = "MCP Client for AO/Permaweb",
            version = "1.0.0",
            description = "MCP client that discovers tools from ADP-compliant processes and uses APUS Router for AI-guided task execution",
            handlers = {
                {
                    action = "DiscoverProcess",
                    pattern = {"Action"},
                    description = "Discover and register tools from an ADP-compliant process",
                    tags = {
                        {
                            name = "ProcessId",
                            type = "string",
                            required = true,
                            description = "AO process ID to discover tools from"
                        }
                    },
                    category = "mcp",
                    version = "1.0"
                },
                {
                    action = "ListTools",
                    pattern = {"Action"},
                    description = "List all discovered tools from registered processes",
                    tags = {},
                    category = "mcp",
                    version = "1.0"
                },
                {
                    action = "UseTool",
                    pattern = {"Action"},
                    description = "Use a discovered tool with parameters",
                    tags = {
                        {
                            name = "Tool",
                            type = "string",
                            required = true,
                            description = "Tool key (processId:action format)"
                        }
                    },
                    category = "mcp",
                    version = "1.0"
                },
                {
                    action = "ExecuteTask",
                    pattern = {"Action"},
                    description = "Execute a task with AI-guided tool selection",
                    tags = {
                        {
                            name = "Task",
                            type = "string",
                            required = false,
                            description = "Task description (can also be in Data)"
                        },
                        {
                            name = "Reference",
                            type = "string",
                            required = false,
                            description = "Optional reference ID for tracking"
                        }
                    },
                    category = "ai-guided",
                    version = "1.0"
                },
                {
                    action = "Infer",
                    pattern = {"Action"},
                    description = "Send direct inference request to APUS Router",
                    tags = {
                        {
                            name = "X-Reference",
                            type = "string",
                            required = false,
                            description = "Reference ID for tracking"
                        },
                        {
                            name = "X-Session",
                            type = "string",
                            required = false,
                            description = "Session ID for context"
                        }
                    },
                    category = "inference",
                    version = "1.0"
                },
                {
                    action = "Status",
                    pattern = {"Action"},
                    description = "Get status of tasks or general system status",
                    tags = {
                        {
                            name = "Reference",
                            type = "string",
                            required = false,
                            description = "Task reference ID (omit for general status)"
                        }
                    },
                    category = "monitoring",
                    version = "1.0"
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get MCP client information and capabilities",
                    tags = {},
                    category = "core",
                    version = "1.0"
                }
            },
            capabilities = {
                adpCompliant = true,
                mcpVersion = "2024-11-05",
                toolDiscovery = true,
                aiGuidedExecution = true,
                apusIntegration = true
            },
            statistics = {
                registeredProcesses = #ToolRegistry.processes,
                availableTools = #ToolRegistry.tools,
                apusRouter = APUS_ROUTER
            }
        }

        ao.send({
            Target = msg.From,
            Action = "Info-Response",
            Data = json.encode(adpInfo)
        })
    end
)

-- Initialize on load
initializeMCPClient()
print("MCP Client for AO/Permaweb loaded")
print("APUS Router: " .. APUS_ROUTER)
print("Ready to discover tools and execute AI-guided tasks")