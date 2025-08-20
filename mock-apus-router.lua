-- Mock APUS Router Process for Testing MCP Client
-- This simulates the APUS Router's AI inference capabilities with predefined responses
-- for testing the MCP client's AI-guided task execution flow

-- Process metadata
local PROCESS_NAME = "Mock APUS Router"
local PROCESS_VERSION = "1.0.0-test"

-- Mock AI responses for different task scenarios
local MOCK_RESPONSES = {
    -- Calculator-related tasks
    ["calculate"] = {
        analysis = "This task requires mathematical calculation using available calculator tools.",
        tools_needed = {
            {
                tool = "calculator-process:Add",
                parameters = { A = "25", B = "15" },
                order = 1,
                description = "Add 25 and 15 to get the result"
            }
        },
        execution_plan = "Use the Add tool from the calculator process to perform the addition operation."
    },
    ["add numbers"] = {
        analysis = "User wants to add two numbers. I'll use the calculator Add tool.",
        tools_needed = {
            {
                tool = "calculator-process:Add",
                parameters = { A = "10", B = "5" },
                order = 1,
                description = "Add 10 and 5"
            }
        },
        execution_plan = "Execute the Add operation with the provided numbers."
    },
    ["complex math"] = {
        analysis = "This requires multiple mathematical operations in sequence.",
        tools_needed = {
            {
                tool = "calculator-process:Add",
                parameters = { A = "20", B = "30" },
                order = 1,
                description = "First add 20 and 30"
            },
            {
                tool = "calculator-process:Subtract",
                parameters = { A = "50", B = "15" },
                order = 2,
                description = "Then subtract 15 from the result"
            }
        },
        execution_plan = "Perform addition first, then subtraction to complete the complex calculation."
    },
    -- Non-calculator tasks
    ["hello"] = {
        analysis = "This is a simple greeting that doesn't require any tools.",
        tools_needed = {},
        execution_plan = "No tools needed - this is just a greeting."
    },
    -- History-related tasks
    ["show history"] = {
        analysis = "User wants to see calculation history.",
        tools_needed = {
            {
                tool = "calculator-process:History",
                parameters = { Limit = "10" },
                order = 1,
                description = "Get the last 10 calculation operations"
            }
        },
        execution_plan = "Use the History tool to retrieve recent calculations."
    }
}

-- Default response for unknown tasks
local function getDefaultResponse(task)
    return {
        analysis = "I cannot determine specific tools needed for this task: " .. task,
        tools_needed = {},
        execution_plan = "No tools identified for this task."
    }
end

-- Find best matching response based on task content
local function findBestResponse(task)
    local taskLower = string.lower(task)
    
    -- Check for exact matches first
    if MOCK_RESPONSES[taskLower] then
        return MOCK_RESPONSES[taskLower]
    end
    
    -- Check for partial matches
    for key, response in pairs(MOCK_RESPONSES) do
        if string.find(taskLower, key) then
            return response
        end
    end
    
    -- Check for math-related keywords
    if string.find(taskLower, "add") or string.find(taskLower, "plus") or string.find(taskLower, "+") then
        return MOCK_RESPONSES["add numbers"]
    end
    
    if string.find(taskLower, "subtract") or string.find(taskLower, "minus") or string.find(taskLower, "-") then
        return {
            analysis = "User wants to perform subtraction.",
            tools_needed = {
                {
                    tool = "calculator-process:Subtract",
                    parameters = { A = "20", B = "8" },
                    order = 1,
                    description = "Subtract 8 from 20"
                }
            },
            execution_plan = "Use the Subtract tool to perform the subtraction operation."
        }
    end
    
    if string.find(taskLower, "history") or string.find(taskLower, "previous") or string.find(taskLower, "past") then
        return MOCK_RESPONSES["show history"]
    end
    
    -- Default response
    return getDefaultResponse(task)
end

-- Handler: Mock APUS Infer endpoint
Handlers.add("Infer", Handlers.utils.hasMatchingTag("Action", "Infer"),
    function(msg)
        local prompt = msg.Data or msg.Tags["X-Prompt"] or ""
        local reference = msg.Tags["X-Reference"] or "unknown"
        local context = msg.Tags["X-Context"] or "general"
        
        print("Mock APUS Router received inference request:")
        print("Reference: " .. reference)
        print("Context: " .. context)
        print("Prompt: " .. string.sub(prompt, 1, 100) .. "...")
        
        -- Simulate processing delay
        local processingTime = math.random(1, 3)
        print("Simulating " .. processingTime .. " second processing delay...")
        
        -- Extract task from prompt (look for "Task:" prefix)
        local task = "unknown"
        local taskMatch = string.match(prompt, "Task:%s*([^\n]+)")
        if taskMatch then
            task = taskMatch
        end
        
        -- Get appropriate response
        local response = findBestResponse(task)
        local responseJson = json.encode(response)
        
        -- Send structured response back to the requesting client
        ao.send({
            Target = msg.From,
            Action = "Infer-Response",
            Data = responseJson,
            ["X-Reference"] = reference,
            ["X-Context"] = context
        })
        
        print("Mock APUS Router sent response for task: " .. task)
        print("Tools recommended: " .. #response.tools_needed)
    end
)

-- Handler: Check mock router status
Handlers.add("Status", Handlers.utils.hasMatchingTag("Action", "Status"),
    function(msg)
        local status = {
            processName = PROCESS_NAME,
            version = PROCESS_VERSION,
            availableResponses = 0,
            isMock = true,
            capabilities = {
                "task-analysis",
                "tool-recommendation",
                "structured-responses"
            }
        }
        
        -- Count available mock responses
        for _ in pairs(MOCK_RESPONSES) do
            status.availableResponses = status.availableResponses + 1
        end
        
        ao.send({
            Target = msg.From,
            Action = "Status-Response",
            Data = json.encode(status)
        })
    end
)

-- ADP-compliant Info handler
Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local adpInfo = {
            protocolVersion = "1.0",
            name = PROCESS_NAME,
            version = PROCESS_VERSION,
            description = "Mock APUS Router for testing MCP client AI-guided task execution",
            handlers = {
                {
                    action = "Infer",
                    pattern = {"Action"},
                    description = "Provide mock AI inference responses for task analysis and tool selection",
                    tags = {
                        {
                            name = "X-Reference",
                            type = "string",
                            required = false,
                            description = "Reference ID for tracking"
                        },
                        {
                            name = "X-Context",
                            type = "string", 
                            required = false,
                            description = "Context for the inference"
                        }
                    },
                    category = "ai-inference",
                    version = "1.0"
                },
                {
                    action = "Status",
                    pattern = {"Action"},
                    description = "Get mock router status and capabilities",
                    tags = {},
                    category = "monitoring",
                    version = "1.0"
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get process information and capabilities",
                    tags = {},
                    category = "core",
                    version = "1.0"
                }
            },
            capabilities = {
                adpCompliant = true,
                mockRouter = true,
                supportedTasks = {"calculate", "add numbers", "complex math", "hello", "show history"}
            },
            statistics = {
                mockResponses = 5,
                isTest = true
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "Info-Response",
            Data = json.encode(adpInfo)
        })
    end
)

print("Mock APUS Router loaded - " .. PROCESS_NAME .. " v" .. PROCESS_VERSION)
print("Available mock responses: calculate, add numbers, complex math, hello, show history")
print("Ready to provide structured AI responses for MCP testing")