-- Comprehensive MCP Integration Test Suite using AOLite
-- This test file uses aolite to create a local AO environment and test
-- the complete MCP client-server flow with mock APUS Router

local aolite = require("aolite")

-- Test configuration
local TEST_CONFIG = {
    CLIENT_PROCESS_ID = "client-process",
    SERVER_PROCESS_ID = "server-process", 
    MOCK_APUS_PROCESS_ID = "mock-apus-router",
    TEST_TIMEOUT = 5000, -- 5 seconds
    VERBOSE_LOGGING = true
}

-- Test results tracking
local TestResults = {
    total = 0,
    passed = 0,
    failed = 0,
    tests = {}
}

-- Helper function for logging
local function log(message)
    if TEST_CONFIG.VERBOSE_LOGGING then
        print("[TEST] " .. message)
    end
end

-- Helper function to record test result
local function recordTest(testName, passed, message)
    TestResults.total = TestResults.total + 1
    if passed then
        TestResults.passed = TestResults.passed + 1
        log("✅ " .. testName .. " - PASSED")
    else
        TestResults.failed = TestResults.failed + 1
        log("❌ " .. testName .. " - FAILED: " .. (message or "Unknown error"))
    end
    
    table.insert(TestResults.tests, {
        name = testName,
        passed = passed,
        message = message or ""
    })
end

-- Helper function to wait for messages with timeout
local function waitForMessage(processId, actionPattern, timeout)
    local startTime = os.time()
    timeout = timeout or TEST_CONFIG.TEST_TIMEOUT
    
    while (os.time() - startTime) < timeout do
        aolite.runScheduler()
        
        -- Check process state for recent messages
        local state = aolite.getProcessState(processId)
        if state and state.inbox then
            for _, message in ipairs(state.inbox) do
                if message.Tags and message.Tags.Action and 
                   string.find(message.Tags.Action, actionPattern) then
                    return message
                end
            end
        end
        
        -- Small delay to prevent busy waiting
        os.execute("sleep 0.1")
    end
    
    return nil -- Timeout
end

-- Load Lua files into processes
local function loadProcesses()
    log("Loading processes...")
    
    -- Create and load MCP Server (Calculator)
    aolite.spawnProcess(TEST_CONFIG.SERVER_PROCESS_ID)
    local serverCode = io.open("mcp-server.lua", "r"):read("*all")
    aolite.eval(TEST_CONFIG.SERVER_PROCESS_ID, serverCode)
    
    -- Create and load Mock APUS Router  
    aolite.spawnProcess(TEST_CONFIG.MOCK_APUS_PROCESS_ID)
    local mockApusCode = io.open("mock-apus-router.lua", "r"):read("*all")
    aolite.eval(TEST_CONFIG.MOCK_APUS_PROCESS_ID, mockApusCode)
    
    -- Create and load MCP Client (but update APUS_ROUTER constant first)
    aolite.spawnProcess(TEST_CONFIG.CLIENT_PROCESS_ID)
    local clientCode = io.open("client.lua", "r"):read("*all")
    -- Replace the APUS Router process ID with our mock
    clientCode = string.gsub(clientCode, 
        'APUS_ROUTER = "Bf6JJR2tl2Wr38O2-H6VctqtduxHgKF-NzRB9HhTRzo"',
        'APUS_ROUTER = "' .. TEST_CONFIG.MOCK_APUS_PROCESS_ID .. '"')
    aolite.eval(TEST_CONFIG.CLIENT_PROCESS_ID, clientCode)
    
    log("All processes loaded successfully")
end

-- Test 1: Process Initialization
local function testProcessInitialization()
    log("Running Test 1: Process Initialization")
    
    local serverState = aolite.getProcessState(TEST_CONFIG.SERVER_PROCESS_ID)
    local clientState = aolite.getProcessState(TEST_CONFIG.CLIENT_PROCESS_ID)
    local mockState = aolite.getProcessState(TEST_CONFIG.MOCK_APUS_PROCESS_ID)
    
    local allInitialized = serverState ~= nil and clientState ~= nil and mockState ~= nil
    recordTest("Process Initialization", allInitialized, 
        allInitialized and "All processes initialized" or "Some processes failed to initialize")
end

-- Test 2: Server Info Handler
local function testServerInfoHandler()
    log("Running Test 2: Server Info Handler")
    
    -- Send Info request to calculator server
    aolite.send({
        From = TEST_CONFIG.CLIENT_PROCESS_ID,
        Target = TEST_CONFIG.SERVER_PROCESS_ID,
        Tags = { Action = "Info" }
    })
    
    aolite.runScheduler()
    
    -- Wait for Info-Response
    local response = waitForMessage(TEST_CONFIG.CLIENT_PROCESS_ID, "Info%-Response", 2000)
    
    if response and response.Data then
        local success, adpInfo = pcall(json.decode, response.Data)
        local validResponse = success and adpInfo and 
                            adpInfo.protocolVersion == "1.0" and
                            adpInfo.handlers and 
                            #adpInfo.handlers > 0
        
        recordTest("Server Info Handler", validResponse,
            validResponse and "Valid ADP Info response received" or "Invalid or missing ADP Info")
    else
        recordTest("Server Info Handler", false, "No Info-Response received")
    end
end

-- Test 3: Tool Discovery Flow
local function testToolDiscoveryFlow()
    log("Running Test 3: Tool Discovery Flow")
    
    -- Send DiscoverProcess request to client
    aolite.send({
        From = "test-requester",
        Target = TEST_CONFIG.CLIENT_PROCESS_ID,
        Tags = { 
            Action = "DiscoverProcess",
            ProcessId = TEST_CONFIG.SERVER_PROCESS_ID
        }
    })
    
    aolite.runScheduler()
    
    -- Wait for discovery response
    local response = waitForMessage("test-requester", "DiscoverProcess%-Response", 3000)
    
    if response and response.Data then
        local success, responseData = pcall(json.decode, response.Data)
        local discoverySuccess = success and responseData and responseData.success
        
        recordTest("Tool Discovery Flow", discoverySuccess,
            discoverySuccess and "Tool discovery initiated successfully" or "Tool discovery failed")
    else
        recordTest("Tool Discovery Flow", false, "No DiscoverProcess-Response received")
    end
end

-- Test 4: Calculator Add Operation
local function testCalculatorAddOperation()
    log("Running Test 4: Calculator Add Operation")
    
    -- Send Add request directly to calculator server
    aolite.send({
        From = "test-requester",
        Target = TEST_CONFIG.SERVER_PROCESS_ID,
        Tags = { 
            Action = "Add",
            A = "15",
            B = "25"
        }
    })
    
    aolite.runScheduler()
    
    -- Wait for Add-Response
    local response = waitForMessage("test-requester", "Add%-Response", 2000)
    
    if response and response.Data then
        local success, responseData = pcall(json.decode, response.Data)
        local validResult = success and responseData and 
                          responseData.success and
                          responseData.result == 40 and
                          responseData.operand1 == 15 and
                          responseData.operand2 == 25
        
        recordTest("Calculator Add Operation", validResult,
            validResult and "Addition calculated correctly (15 + 25 = 40)" or "Addition calculation failed")
    else
        recordTest("Calculator Add Operation", false, "No Add-Response received")
    end
end

-- Test 5: Calculator Subtract Operation  
local function testCalculatorSubtractOperation()
    log("Running Test 5: Calculator Subtract Operation")
    
    aolite.send({
        From = "test-requester",
        Target = TEST_CONFIG.SERVER_PROCESS_ID,
        Tags = { 
            Action = "Subtract",
            A = "50",
            B = "20"
        }
    })
    
    aolite.runScheduler()
    
    local response = waitForMessage("test-requester", "Subtract%-Response", 2000)
    
    if response and response.Data then
        local success, responseData = pcall(json.decode, response.Data)
        local validResult = success and responseData and 
                          responseData.success and
                          responseData.result == 30 and
                          responseData.operand1 == 50 and
                          responseData.operand2 == 20
        
        recordTest("Calculator Subtract Operation", validResult,
            validResult and "Subtraction calculated correctly (50 - 20 = 30)" or "Subtraction calculation failed")
    else
        recordTest("Calculator Subtract Operation", false, "No Subtract-Response received")
    end
end

-- Test 6: Mock APUS Router Inference
local function testMockApusInference()
    log("Running Test 6: Mock APUS Router Inference")
    
    aolite.send({
        From = "test-requester",
        Target = TEST_CONFIG.MOCK_APUS_PROCESS_ID,
        Tags = { 
            Action = "Infer",
            ["X-Reference"] = "test-ref-123"
        },
        Data = "Task: add numbers\n\nAvailable tools:\n- Add (calculator): Add two numbers together"
    })
    
    aolite.runScheduler()
    
    local response = waitForMessage("test-requester", "Infer%-Response", 3000)
    
    if response and response.Data then
        local success, responseData = pcall(json.decode, response.Data)
        local validInference = success and responseData and 
                             responseData.analysis and
                             responseData.tools_needed and
                             responseData.execution_plan
        
        recordTest("Mock APUS Router Inference", validInference,
            validInference and "Mock APUS provided structured AI response" or "Invalid AI response format")
    else
        recordTest("Mock APUS Router Inference", false, "No Infer-Response received")
    end
end

-- Test 7: AI-Guided Task Execution Flow
local function testAIGuidedTaskExecution()
    log("Running Test 7: AI-Guided Task Execution Flow")
    
    -- First ensure tools are discovered
    aolite.send({
        From = "test-requester",
        Target = TEST_CONFIG.CLIENT_PROCESS_ID,
        Tags = { 
            Action = "DiscoverProcess",
            ProcessId = TEST_CONFIG.SERVER_PROCESS_ID
        }
    })
    aolite.runScheduler()
    
    -- Wait a moment for tool registration
    os.execute("sleep 1")
    aolite.runScheduler()
    
    -- Now send ExecuteTask request
    aolite.send({
        From = "test-requester", 
        Target = TEST_CONFIG.CLIENT_PROCESS_ID,
        Tags = {
            Action = "ExecuteTask",
            Reference = "task-exec-test"
        },
        Data = "Please add 25 and 15 together"
    })
    
    aolite.runScheduler()
    
    -- Wait for task completion
    local response = waitForMessage("test-requester", "Task%-Completed", 8000)
    
    if response and response.Data then
        local success, responseData = pcall(json.decode, response.Data)
        local validExecution = success and responseData and
                             responseData.reference == "task-exec-test" and
                             responseData.aiAnalysis and
                             responseData.toolsUsed
        
        recordTest("AI-Guided Task Execution", validExecution,
            validExecution and "AI-guided task executed successfully" or "Task execution failed")
    else
        recordTest("AI-Guided Task Execution", false, "No Task-Completed response received")
    end
end

-- Test 8: List Available Tools
local function testListAvailableTools()
    log("Running Test 8: List Available Tools")
    
    aolite.send({
        From = "test-requester",
        Target = TEST_CONFIG.CLIENT_PROCESS_ID,
        Tags = { Action = "ListTools" }
    })
    
    aolite.runScheduler()
    
    local response = waitForMessage("test-requester", "ListTools%-Response", 2000)
    
    if response and response.Data then
        local success, responseData = pcall(json.decode, response.Data)
        local validList = success and responseData and 
                        responseData.success and
                        responseData.tools and
                        type(responseData.tools) == "table"
        
        recordTest("List Available Tools", validList,
            validList and ("Found " .. #responseData.tools .. " available tools") or "Failed to list tools")
    else
        recordTest("List Available Tools", false, "No ListTools-Response received")
    end
end

-- Main test execution function
local function runAllTests()
    print("🧪 Starting MCP Integration Test Suite")
    print("=====================================")
    
    -- Initialize test environment
    loadProcesses()
    
    -- Run all tests
    testProcessInitialization()
    testServerInfoHandler()
    testToolDiscoveryFlow()
    testCalculatorAddOperation()
    testCalculatorSubtractOperation()
    testMockApusInference()
    testAIGuidedTaskExecution()
    testListAvailableTools()
    
    -- Print results summary
    print("\n🏁 Test Suite Results")
    print("=====================")
    print("Total Tests: " .. TestResults.total)
    print("Passed: " .. TestResults.passed)
    print("Failed: " .. TestResults.failed)
    
    if TestResults.failed > 0 then
        print("\n❌ Failed Tests:")
        for _, test in ipairs(TestResults.tests) do
            if not test.passed then
                print("  - " .. test.name .. ": " .. test.message)
            end
        end
    end
    
    local successRate = math.floor((TestResults.passed / TestResults.total) * 100)
    print("\nSuccess Rate: " .. successRate .. "%")
    
    if successRate >= 80 then
        print("🎉 Test suite passed with acceptable success rate!")
    else
        print("⚠️  Test suite needs attention - low success rate")
    end
end

-- Execute tests
runAllTests()