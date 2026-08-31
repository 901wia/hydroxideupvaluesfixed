local UpvalueScanner = {}

local Closure = import("objects/Closure")
local Upvalue = import("objects/Upvalue")

local requiredMethods = {
    ["getGc"] = true,
    ["getInfo"] = true,
    ["isXClosure"] = true,
    ["getUpvalue"] = true,
    ["setUpvalue"] = true,
    ["getUpvalues"] = true
}

local function safeGetGc()
    if type(getGc) ~= "function" then
        return {}
    end

    local success, result = pcall(getGc)

    if not success or type(result) ~= "table" then
        return {}
    end

    return result
end

local function safeGetInfo(closure)
    if type(closure) ~= "function" then
        return nil
    end

    if type(getInfo) ~= "function" then
        return nil
    end

    local success, result = pcall(getInfo, closure)

    if not success or type(result) ~= "table" then
        return nil
    end

    return result
end

local function isLuaClosure(closure)
    if type(closure) ~= "function" then
        return false
    end

    if type(islclosure) == "function" then
        local success, result = pcall(islclosure, closure)

        if success then
            return result == true
        end
    end

    if type(isLClosure) == "function" then
        local success, result = pcall(isLClosure, closure)

        if success then
            return result == true
        end
    end

    local info = safeGetInfo(closure)

    if info then
        if info.what == "Lua" then
            return true
        end

        if info.source ~= nil then
            return true
        end
    end

    return false
end

local function isXClosureSafe(closure)
    if type(isXClosure) ~= "function" then
        return false
    end

    local success, result = pcall(isXClosure, closure)

    if not success then
        return false
    end

    return result == true
end

local function safeGetUpvalues(closure)
    if type(closure) ~= "function" then
        return nil
    end

    if type(getUpvalues) ~= "function" then
        return nil
    end

    local success, result = pcall(getUpvalues, closure)

    if not success or type(result) ~= "table" then
        return nil
    end

    return result
end

local function safeToString(value)
    if type(toString) == "function" then
        local success, result = pcall(toString, value)

        if success and result ~= nil then
            return tostring(result)
        end
    end

    local success, result = pcall(tostring, value)

    if success then
        return result
    end

    return ""
end

local function safeTypeOf(value)
    local success, result = pcall(typeof, value)

    if success then
        return result
    end

    return type(value)
end

local function compareUpvalue(query, upvalue, ignore)
    if upvalue == nil then
        return false
    end

    local queryText = tostring(query)
    local queryLower = queryText:lower()
    local upvalueType = type(upvalue)

    if upvalueType == "string" then
        local success, result = pcall(function()
            return upvalue:lower():find(queryLower, 1, true) ~= nil
        end)

        return success and result == true
    end

    if upvalueType == "number" then
        if ignore then
            return false
        end

        local numericQuery = tonumber(query)

        if numericQuery ~= nil and numericQuery == upvalue then
            return true
        end

        local success, formatted = pcall(function()
            return ("%.2f"):format(upvalue)
        end)

        if success and formatted then
            return formatted:find(queryLower, 1, true) ~= nil
        end

        return false
    end

    if upvalueType == "boolean" then
        return tostring(upvalue):lower() == queryLower
    end

    local valueTypeOf = safeTypeOf(upvalue)

    if valueTypeOf == "Instance" then
        local success, name = pcall(function()
            return upvalue.Name
        end)

        if success and type(name) == "string" then
            return name:lower():find(queryLower, 1, true) ~= nil
        end

        return false
    end

    if upvalueType == "userdata" then
        local stringValue = safeToString(upvalue)

        if stringValue ~= "" then
            return stringValue:lower():find(queryLower, 1, true) ~= nil
        end

        return false
    end

    if upvalueType == "function" then
        local info = safeGetInfo(upvalue)

        if not info then
            return false
        end

        local closureName = info.name

        if type(closureName) ~= "string" then
            closureName = ""
        end

        return closureName:lower():find(queryLower, 1, true) ~= nil
    end

    return false
end

local function createClosureStorage(closure, index, value, storage)
    if storage then
        local success = pcall(function()
            storage.Upvalues[index] = Upvalue.new(
                storage,
                index,
                value
            )
        end)

        if success then
            return storage
        end

        return nil
    end

    local success, newClosure = pcall(Closure.new, closure)

    if not success or not newClosure then
        return nil
    end

    local upvalueSuccess = pcall(function()
        newClosure.Upvalues[index] = Upvalue.new(
            newClosure,
            index,
            value
        )
    end)

    if not upvalueSuccess then
        return nil
    end

    return newClosure
end

local function scanTable(closure, index, value, query, upvalues)
    local storage = upvalues[closure]
    local tableObject

    local success = pcall(function()
        for i, v in pairs(value) do
            if i ~= value and v ~= value then
                local indexMatch = compareUpvalue(query, i, true)
                local valueMatch = compareUpvalue(query, v)

                if indexMatch or valueMatch then
                    if not storage then
                        storage = Closure.new(closure)

                        if not storage then
                            return
                        end

                        upvalues[closure] = storage
                    end

                    if not tableObject then
                        tableObject = Upvalue.new(
                            storage,
                            index,
                            value
                        )

                        if not tableObject then
                            return
                        end

                        tableObject.Scanned = {}
                        storage.Upvalues[index] = tableObject
                    end

                    tableObject.Scanned[i] = v
                end
            end
        end
    end)

    return success
end

local function scan(query, deepSearch)
    local results = {}

    if query == nil then
        return results
    end

    query = tostring(query)

    if query == "" then
        return results
    end

    local gcObjects = safeGetGc()

    for _, closure in pairs(gcObjects) do
        pcall(function()
            if type(closure) ~= "function" then
                return
            end

            if not isLuaClosure(closure) then
                return
            end

            if isXClosureSafe(closure) then
                return
            end

            local closureUpvalues = safeGetUpvalues(closure)

            if not closureUpvalues then
                return
            end

            for index, value in pairs(closureUpvalues) do
                local valueType = type(value)

                if valueType ~= "table" then
                    if compareUpvalue(query, value) then
                        local storage = createClosureStorage(
                            closure,
                            index,
                            value,
                            results[closure]
                        )

                        if storage then
                            results[closure] = storage
                        end
                    end
                elseif deepSearch then
                    scanTable(
                        closure,
                        index,
                        value,
                        query,
                        results
                    )
                end
            end
        end)
    end

    return results
end

UpvalueScanner.Scan = scan
UpvalueScanner.RequiredMethods = requiredMethods

return UpvalueScanner