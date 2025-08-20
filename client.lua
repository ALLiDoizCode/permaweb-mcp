-- AO MCP Client Process with ADP Discovery
-- This process orchestrates AI and tool processes using the AO Documentation Protocol

local json = require("json")

-- Configuration
local ADP_VERSION = "1.0"
local AI_PROCESS = "" -- Set this to your AI process ID
local DEFAULT_TIMEOUT = 30000 -- 30 seconds

-- State
local availableTools = {}
local processCapabilities = {}
local activeQueries = {}
local registeredProcesses = {}

-- Utility Functions
function generateId()
  return tostring(math.random(100000, 999999)) .. "-" .. tostring(os.time())
end

function validateProcessId(processId)
  return processId and type(processId) == "string" and #processId > 0
end

function toolsToString()
  local toolList = {}
  for toolName, tool in pairs(availableTools) do
    table.insert(toolList, string.format("%s: %s", toolName, tool.description))
  end
  return table.concat(toolList, "\n")
end

function parseToolCalls(response)
  -- Try to parse JSON array of tool calls
  local success, parsed = pcall(json.decode, response)
  if success and type(parsed) == "table" then
    return parsed
  end
  
  -- Check for "none" response
  if string.lower(response):match("none") then
    return "none"
  end
  
  -- Default to no tools
  return "none"
end

-- ADP Functions
function registerToolFromADP(processId, handlerSpec)
  local toolName = handlerSpec.name
  
  availableTools[toolName] = {
    process = processId,
    action = handlerSpec.action,
    description = handlerSpec.description,
    parameters = handlerSpec.parameters or {},
    returns = handlerSpec.returns or {}
  }
  
  print("Registered tool: " .. toolName .. " from process: " .. processId)
end

function discoverProcessCapabilities(processId)
  if not validateProcessId(processId) then
    return nil
  end
  
  print("Discovering capabilities for process: " .. processId)
  
  ao.send({
    Target = processId,
    Action = "Info"
  })
  
  -- Note: In a real implementation, you'd handle the response asynchronously
  -- This is a simplified version for demonstration
end

function buildToolMessage(tool, toolCall)
  local message = {
    Target = tool.process,
    Action = tool.action,
    Data = ""
  }
  
  -- Handle parameters according to ADP spec
  if toolCall.params then
    for paramName, paramValue in pairs(toolCall.params) do
      if paramName == "Data" then
        message.Data = tostring(paramValue)
      else
        message.Tags = message.Tags or {}
        message.Tags[paramName] = tostring(paramValue)
      end
    end
  end
  
  return message
end

-- Core MCP Logic
function executeADPTools(toolCalls, originalQuery, originalMsg, queryId)
  if not toolCalls or #toolCalls == 0 then
    finalResponse(originalMsg, originalQuery, {}, queryId)
    return
  end
  
  local results = {}
  local completed = 0
  local totalTools = #toolCalls
  
  print(string.format("Executing %d tools for query %s", totalTools, queryId))
  
  for i, toolCall in ipairs(toolCalls) do
    local tool = availableTools[toolCall.name]
    
    if not tool then
      print("Tool not found: " .. (toolCall.name or "unknown"))
      results[i] = {
        tool = toolCall.name,
        error = "Tool not found",
        result = ""
      }
      completed = completed + 1
    else
      local toolMessage = buildToolMessage(tool, toolCall)
      toolMessage.Tags = toolMessage.Tags or {}
      toolMessage.Tags.QueryId = queryId
      toolMessage.Tags.ToolIndex = tostring(i)
      
      print("Calling tool: " .. toolCall.name)
      ao.send(toolMessage)
    end
  end
  
  -- If all tools failed immediately
  if completed == totalTools then
    finalResponse(originalMsg, originalQuery, results, queryId)
  end
end

function finalResponse(originalMsg, query, toolResults, queryId)
  if not AI_PROCESS or AI_PROCESS == "" then
    originalMsg.reply({
      Data = "Error: AI_PROCESS not configured",
      Action = "QueryResponse",
      Tags = { QueryId = queryId, Error = "Configuration" }
    })
    return
  end
  
  local contextPrompt = "User query: " .. query
  
  if toolResults and #toolResults > 0 then
    contextPrompt = contextPrompt .. "\n\nTool results:\n"
    for _, result in ipairs(toolResults) do
      if result.error then
        contextPrompt = contextPrompt .. result.tool .. " (ERROR): " .. result.error .. "\n"
      else
        contextPrompt = contextPrompt .. result.tool .. ": " .. (result.result or "") .. "\n"
      end
    end
  end
  
  contextPrompt = contextPrompt .. "\n\nProvide a helpful response based on the above information:"
  
  ao.send({
    Target = AI_PROCESS,
    Action = "Infer",
    Data = contextPrompt,
    Tags = { QueryId = queryId, Stage = "Final" }
  })
end

-- Handlers

-- ADP Compliance - Info Handler
Handlers.add("Info",
  { Action = "Info" },
  function(msg)
    local adpInfo = {
      version = ADP_VERSION,
      name = "MCP Client Process",
      description = "Orchestrates AI and tool processes using ADP discovery",
      handlers = {
        {
          name = "Query",
          action = "Query",
          description = "Process user queries with AI and tool orchestration",
          parameters = {
            required = {
              {
                name = "Data",
                type = "string",
                description = "User query to process"
              }
            },
            optional = {
              {
                name = "AIProcess",
                type = "string",
                description = "Override default AI process ID"
              }
            }
          },
          returns = {
            type = "string",
            description = "AI response with tool integration"
          }
        },
        {
          name = "RegisterProcess",
          action = "RegisterProcess",
          description = "Register a new ADP-compliant process",
          parameters = {
            required = {
              {
                name = "ProcessId",
                type = "string",
                description = "Process ID to register"
              }
            }
          }
        },
        {
          name = "ListTools",
          action = "ListTools",
          description = "List all available registered tools",
          parameters = {},
          returns = {
            type = "object",
            description = "Dictionary of available tools and their capabilities"
          }
        },
        {
          name = "SetAIProcess",
          action = "SetAIProcess", 
          description = "Set the AI process ID for inference",
          parameters = {
            required = {
              {
                name = "ProcessId",
                type = "string",
                description = "AI process ID"
              }
            }
          }
        }
      }
    }
    
    msg.reply({
      Data = json.encode(adpInfo),
      Action = "Info-Response"
    })
  end
)

-- Main Query Handler
Handlers.add("Query",
  { Action = "Query" },
  function(msg)
    local userQuery = msg.Data
    local queryId = generateId()
    local aiProcess = msg.Tags.AIProcess or AI_PROCESS
    
    if not aiProcess or aiProcess == "" then
      msg.reply({
        Data = "Error: No AI process configured. Use SetAIProcess action first.",
        Action = "QueryResponse",
        Tags = { QueryId = queryId, Error = "NoAI" }
      })
      return
    end
    
    -- Store query context
    activeQueries[queryId] = {
      originalMsg = msg,
      query = userQuery,
      aiProcess = aiProcess,
      timestamp = os.time()
    }
    
    print("Processing query: " .. queryId)
    
    -- Build tool descriptions from available tools
    local toolDescriptions = {}
    for toolName, tool in pairs(availableTools) do
      table.insert(toolDescriptions, {
        name = toolName,
        description = tool.description,
        parameters = tool.parameters
      })
    end
    
    local analysisPrompt = string.format([[
User query: %s

Available tools (ADP-discovered):
%s

Analyze the query and determine which tools to call. Respond with a JSON array of tool calls with exact parameter names from ADP specs, or respond with exactly "none" if no tools are needed.

Example format for tool calls:
[{"name": "GetWeather", "params": {"Location": "New York", "Units": "metric"}}]

Response:]], userQuery, json.encode(toolDescriptions))

    ao.send({
      Target = aiProcess,
      Action = "Infer",
      Data = analysisPrompt,
      Tags = { QueryId = queryId, Stage = "Analysis" }
    })
  end
)

-- Handle AI Analysis Response
Handlers.add("AIAnalysisResponse",
  { Action = "InferResponse" },
  function(msg)
    local queryId = msg.Tags.QueryId
    local stage = msg.Tags.Stage
    
    if not queryId or not activeQueries[queryId] then
      print("Received response for unknown query: " .. (queryId or "nil"))
      return
    end
    
    local queryContext = activeQueries[queryId]
    
    if stage == "Analysis" then
      -- Parse tool analysis
      local toolCalls = parseToolCalls(msg.Data)
      
      if toolCalls == "none" then
        -- No tools needed, go directly to final response
        finalResponse(queryContext.originalMsg, queryContext.query, {}, queryId)
      else
        -- Execute tools
        executeADPTools(toolCalls, queryContext.query, queryContext.originalMsg, queryId)
      end
      
    elseif stage == "Final" then
      -- Final AI response
      queryContext.originalMsg.reply({
        Data = msg.Data,
        Action = "QueryResponse",
        Tags = { QueryId = queryId }
      })
      
      -- Clean up
      activeQueries[queryId] = nil
      print("Query completed: " .. queryId)
    end
  end
)

-- Handle Tool Responses
Handlers.add("ToolResponse",
  function(msg)
    return msg.Tags.QueryId and msg.Tags.ToolIndex
  end,
  function(msg)
    local queryId = msg.Tags.QueryId
    local toolIndex = tonumber(msg.Tags.ToolIndex)
    
    if not activeQueries[queryId] then
      print("Received tool response for unknown query: " .. queryId)
      return
    end
    
    local queryContext = activeQueries[queryId]
    
    -- Initialize results if not exists
    if not queryContext.toolResults then
      queryContext.toolResults = {}
      queryContext.completedTools = 0
      queryContext.expectedTools = queryContext.expectedTools or 1
    end
    
    -- Store result
    queryContext.toolResults[toolIndex] = {
      tool = msg.Tags.Tool or "unknown",
      result = msg.Data,
      action = msg.Action
    }
    
    queryContext.completedTools = queryContext.completedTools + 1
    
    print(string.format("Tool response %d/%d for query %s", 
          queryContext.completedTools, queryContext.expectedTools, queryId))
    
    -- Check if all tools completed
    if queryContext.completedTools >= queryContext.expectedTools then
      finalResponse(queryContext.originalMsg, queryContext.query, queryContext.toolResults, queryId)
    end
  end
)

-- Process Registration Handler
Handlers.add("RegisterProcess",
  { Action = "RegisterProcess" },
  function(msg)
    local processId = msg.Tags.ProcessId or msg.Data
    
    if not validateProcessId(processId) then
      msg.reply({
        Data = "Error: Invalid process ID provided",
        Action = "RegistrationResponse",
        Tags = { Error = "InvalidProcessId" }
      })
      return
    end
    
    -- Discover capabilities
    discoverProcessCapabilities(processId)
    
    -- Add to registry
    registeredProcesses[processId] = {
      timestamp = os.time(),
      registeredBy = msg.From
    }
    
    msg.reply({
      Data = "Process registration initiated: " .. processId,
      Action = "RegistrationResponse"
    })
  end
)

-- Handle Info Responses from discovered processes
Handlers.add("InfoResponse",
  { Action = "Info-Response" },
  function(msg)
    local success, capabilities = pcall(json.decode, msg.Data)
    
    if not success then
      print("Failed to parse capabilities from process: " .. msg.From)
      return
    end
    
    processCapabilities[msg.From] = capabilities
    
    -- Register handlers as tools
    if capabilities.handlers then
      for _, handler in ipairs(capabilities.handlers) do
        registerToolFromADP(msg.From, handler)
      end
      
      print("Registered " .. #capabilities.handlers .. " tools from process: " .. (capabilities.name or msg.From))
    end
  end
)

-- List Available Tools
Handlers.add("ListTools",
  { Action = "ListTools" },
  function(msg)
    local toolList = {}
    
    for toolName, tool in pairs(availableTools) do
      toolList[toolName] = {
        process = tool.process,
        description = tool.description,
        parameters = tool.parameters,
        returns = tool.returns
      }
    end
    
    msg.reply({
      Data = json.encode({
        tools = toolList,
        count = #availableTools,
        registeredProcesses = registeredProcesses
      }),
      Action = "ToolsResponse"
    })
  end
)

-- Set AI Process
Handlers.add("SetAIProcess",
  { Action = "SetAIProcess" },
  function(msg)
    local processId = msg.Tags.ProcessId or msg.Data
    
    if not validateProcessId(processId) then
      msg.reply({
        Data = "Error: Invalid process ID",
        Action = "ConfigResponse",
        Tags = { Error = "InvalidProcessId" }
      })
      return
    end
    
    AI_PROCESS = processId
    
    msg.reply({
      Data = "AI process set to: " .. processId,
      Action = "ConfigResponse"
    })
  end
)

-- Cleanup old queries (prevent memory leaks)
Handlers.add("Cleanup",
  { Action = "Cron" },
  function(msg)
    local now = os.time()
    local timeout = 300 -- 5 minutes
    
    for queryId, query in pairs(activeQueries) do
      if now - query.timestamp > timeout then
        print("Cleaning up expired query: " .. queryId)
        activeQueries[queryId] = nil
      end
    end
  end
)

-- Initialization
print("MCP Client Process initialized")
print("Register processes with: Send({Target = '" .. ao.id .. "', Action = 'RegisterProcess', ProcessId = 'your-process-id'})")
print("Set AI process with: Send({Target = '" .. ao.id .. "', Action = 'SetAIProcess', ProcessId = 'ai-process-id'})")
print("Query with: Send({Target = '" .. ao.id .. "', Action = 'Query', Data = 'your question'})")