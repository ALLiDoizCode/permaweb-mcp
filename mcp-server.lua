-- Calculator MCP Server Process with ADP Compliance
-- This process provides calculator functionality as MCP tools
-- discoverable through ADP (Action Documentation Protocol)

-- Process metadata
local PROCESS_NAME = "Calculator MCP Server"
local PROCESS_VERSION = "1.0.0"
local PROTOCOL_VERSION = "1.0"

-- Initialize process state for calculator operations
CalculatorState = CalculatorState or {
    operations = {},
    totalOperations = 0,
    initialized = false
}

-- Initialize calculator state
local function initializeCalculator()
    if not CalculatorState.initialized then
        CalculatorState.operations = {}
        CalculatorState.totalOperations = 0
        CalculatorState.initialized = true
        print("Calculator MCP Server initialized")
    end
end

-- Store operation result
local function storeOperation(operation, a, b, result)
    local operationRecord = {
        id = CalculatorState.totalOperations + 1,
        operation = operation,
        operand1 = a,
        operand2 = b,
        result = result,
        timestamp = os.time()
    }

    table.insert(CalculatorState.operations, operationRecord)
    CalculatorState.totalOperations = CalculatorState.totalOperations + 1

    -- Keep only last 100 operations
    if #CalculatorState.operations > 100 then
        table.remove(CalculatorState.operations, 1)
    end

    return operationRecord
end

-- Handler: Addition
Handlers.add("Add", Handlers.utils.hasMatchingTag("Action", "Add"),
    function(msg)
        local a = tonumber(msg.Tags.A or msg.Tags.a)
        local b = tonumber(msg.Tags.B or msg.Tags.b)

        if not a or not b then
            local response = {
                Target = msg.From,
                Action = "Add-Response",
                Data = json.encode({
                    success = false,
                    error = "Invalid input: A and B must be numbers",
                    received = {
                        A = msg.Tags.A or msg.Tags.a,
                        B = msg.Tags.B or msg.Tags.b
                    }
                })
            }

            -- Echo back tool chain tags if present for automatic chain execution
            if msg.Tags["Tool-Chain-Reference"] then
                response["Tool-Chain-Reference"] = msg.Tags["Tool-Chain-Reference"]
            end
            if msg.Tags["Tool-Index"] then
                response["Tool-Index"] = msg.Tags["Tool-Index"]
            end

            ao.send(response)
            return
        end

        local result = a + b
        local operation = storeOperation("addition", a, b, result)

        local response = {
            Target = msg.From,
            Action = "Add-Response",
            Data = json.encode({
                success = true,
                operation = "addition",
                operand1 = a,
                operand2 = b,
                result = result,
                operationId = operation.id,
                message = a .. " + " .. b .. " = " .. result
            })
        }

        -- Echo back tool chain tags if present for automatic chain execution
        if msg.Tags["Tool-Chain-Reference"] then
            response["Tool-Chain-Reference"] = msg.Tags["Tool-Chain-Reference"]
        end
        if msg.Tags["Tool-Index"] then
            response["Tool-Index"] = msg.Tags["Tool-Index"]
        end

        ao.send(response)

        print("Addition: " .. a .. " + " .. b .. " = " .. result)
    end
)

-- Handler: Subtraction
Handlers.add("Subtract", Handlers.utils.hasMatchingTag("Action", "Subtract"),
    function(msg)
        local a = tonumber(msg.Tags.A or msg.Tags.a)
        local b = tonumber(msg.Tags.B or msg.Tags.b)

        if not a or not b then
            local response = {
                Target = msg.From,
                Action = "Subtract-Response",
                Data = json.encode({
                    success = false,
                    error = "Invalid input: A and B must be numbers",
                    received = {
                        A = msg.Tags.A or msg.Tags.a,
                        B = msg.Tags.B or msg.Tags.b
                    }
                })
            }

            -- Echo back tool chain tags if present for automatic chain execution
            if msg.Tags["Tool-Chain-Reference"] then
                response["Tool-Chain-Reference"] = msg.Tags["Tool-Chain-Reference"]
            end
            if msg.Tags["Tool-Index"] then
                response["Tool-Index"] = msg.Tags["Tool-Index"]
            end

            ao.send(response)
            return
        end

        local result = a - b
        local operation = storeOperation("subtraction", a, b, result)

        local response = {
            Target = msg.From,
            Action = "Subtract-Response",
            Data = json.encode({
                success = true,
                operation = "subtraction",
                operand1 = a,
                operand2 = b,
                result = result,
                operationId = operation.id,
                message = a .. " - " .. b .. " = " .. result
            })
        }

        -- Echo back tool chain tags if present for automatic chain execution
        if msg.Tags["Tool-Chain-Reference"] then
            response["Tool-Chain-Reference"] = msg.Tags["Tool-Chain-Reference"]
        end
        if msg.Tags["Tool-Index"] then
            response["Tool-Index"] = msg.Tags["Tool-Index"]
        end

        ao.send(response)

        print("Subtraction: " .. a .. " - " .. b .. " = " .. result)
    end
)

-- Handler: Get calculation history
Handlers.add("History", Handlers.utils.hasMatchingTag("Action", "History"),
    function(msg)
        local limit = tonumber(msg.Tags.Limit) or 10
        local history = {}

        -- Get the last 'limit' operations
        local start = math.max(1, #CalculatorState.operations - limit + 1)
        for i = start, #CalculatorState.operations do
            table.insert(history, CalculatorState.operations[i])
        end

        local response = {
            Target = msg.From,
            Action = "History-Response",
            Data = json.encode({
                success = true,
                history = history,
                totalOperations = CalculatorState.totalOperations,
                showing = #history
            })
        }

        -- Echo back tool chain tags if present for automatic chain execution
        if msg.Tags["Tool-Chain-Reference"] then
            response["Tool-Chain-Reference"] = msg.Tags["Tool-Chain-Reference"]
        end
        if msg.Tags["Tool-Index"] then
            response["Tool-Index"] = msg.Tags["Tool-Index"]
        end

        ao.send(response)
    end
)

-- Handler: Clear calculation history
Handlers.add("Clear", Handlers.utils.hasMatchingTag("Action", "Clear"),
    function(msg)
        local clearedCount = #CalculatorState.operations
        CalculatorState.operations = {}

        local response = {
            Target = msg.From,
            Action = "Clear-Response",
            Data = json.encode({
                success = true,
                message = "Calculation history cleared",
                clearedOperations = clearedCount
            })
        }

        -- Echo back tool chain tags if present for automatic chain execution
        if msg.Tags["Tool-Chain-Reference"] then
            response["Tool-Chain-Reference"] = msg.Tags["Tool-Chain-Reference"]
        end
        if msg.Tags["Tool-Index"] then
            response["Tool-Index"] = msg.Tags["Tool-Index"]
        end

        ao.send(response)

        print("Calculator history cleared: " .. clearedCount .. " operations removed")
    end
)

-- ADP-compliant Info handler that exposes calculator as MCP tools
Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        initializeCalculator()

        local adpInfo = {
            protocolVersion = PROTOCOL_VERSION,
            name = PROCESS_NAME,
            version = PROCESS_VERSION,
            description = "Calculator process providing addition and subtraction as MCP tools",
            handlers = {
                {
                    action = "Add",
                    pattern = {"Action"},
                    description = "Add two numbers together",
                    tags = {
                        {
                            name = "A",
                            type = "number",
                            required = true,
                            description = "First number to add",
                            examples = {"5", "10.5", "-3"}
                        },
                        {
                            name = "B",
                            type = "number",
                            required = true,
                            description = "Second number to add",
                            examples = {"3", "7.2", "-1"}
                        }
                    },
                    category = "calculator",
                    version = "1.0",
                    examples = {
                        "Send Add with A=5 and B=3 to get 8",
                        "Send Add with A=10.5 and B=7.2 to get 17.7"
                    }
                },
                {
                    action = "Subtract",
                    pattern = {"Action"},
                    description = "Subtract second number from first number",
                    tags = {
                        {
                            name = "A",
                            type = "number",
                            required = true,
                            description = "Number to subtract from",
                            examples = {"10", "15.5", "0"}
                        },
                        {
                            name = "B",
                            type = "number",
                            required = true,
                            description = "Number to subtract",
                            examples = {"3", "5.2", "-2"}
                        }
                    },
                    category = "calculator",
                    version = "1.0",
                    examples = {
                        "Send Subtract with A=10 and B=3 to get 7",
                        "Send Subtract with A=15.5 and B=5.2 to get 10.3"
                    }
                },
                {
                    action = "History",
                    pattern = {"Action"},
                    description = "Get calculation history",
                    tags = {
                        {
                            name = "Limit",
                            type = "number",
                            required = false,
                            description = "Maximum number of operations to return (default: 10)",
                            examples = {"5", "20", "100"}
                        }
                    },
                    category = "utility",
                    version = "1.0",
                    examples = {
                        "Send History to get last 10 operations",
                        "Send History with Limit=5 to get last 5 operations"
                    }
                },
                {
                    action = "Clear",
                    pattern = {"Action"},
                    description = "Clear calculation history",
                    tags = {},
                    category = "utility",
                    version = "1.0",
                    examples = {
                        "Send Clear to remove all calculation history"
                    }
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get process information and available tools/handlers",
                    tags = {},
                    category = "core",
                    version = "1.0",
                    examples = {
                        "Send Info to get process capabilities and handler documentation"
                    }
                }
            },
            capabilities = {
                adpCompliant = true,
                mcpVersion = "2024-11-05",
                supportsCalculations = true,
                supportsHistory = true
            },
            statistics = {
                totalOperations = CalculatorState.totalOperations,
                operationsInHistory = #CalculatorState.operations,
                availableHandlers = 5
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
initializeCalculator()
print("Calculator MCP Server loaded - " .. PROCESS_NAME .. " v" .. PROCESS_VERSION)
print("ADP Protocol Version: " .. PROTOCOL_VERSION)
print("Available operations: Add, Subtract, History, Clear, Info")