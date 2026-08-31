local Upvalue = {}
local TableUpvalue = {}

local function safeSetUpvalue(closure, index, value)
    if type(closure) ~= "function" then
        return false
    end

    if type(setUpvalue) ~= "function" then
        return false
    end

    local success = pcall(
        setUpvalue,
        closure,
        index,
        value
    )

    return success
end

local function safeGetUpvalue(closure, index)
    if type(closure) ~= "function" then
        return false, nil
    end

    if type(getUpvalue) ~= "function" then
        return false, nil
    end

    local success, value = pcall(
        getUpvalue,
        closure,
        index
    )

    if not success then
        return false, nil
    end

    return true, value
end

function Upvalue.new(closure, index, value)
    local upvalue = {}

    upvalue.Closure = closure
    upvalue.Index = index
    upvalue.Value = value

    upvalue.Set = Upvalue.set
    upvalue.Update = Upvalue.update

    return upvalue
end

function Upvalue.set(upvalue, value)
    if type(upvalue) ~= "table" then
        return false
    end

    local closure = upvalue.Closure

    if type(closure) ~= "table" then
        return false
    end

    local data = closure.Data

    if type(data) ~= "function" then
        return false
    end

    if safeSetUpvalue(
        data,
        upvalue.Index,
        value
    ) then
        upvalue.Value = value
        return true
    end

    return false
end

function Upvalue.update(upvalue, newValue)
    if type(upvalue) ~= "table" then
        return false
    end

    local closure = upvalue.Closure

    if type(closure) ~= "table" then
        return false
    end

    local data = closure.Data

    if type(data) ~= "function" then
        return false
    end

    local value = newValue

    if value == nil then
        local success, fetched = safeGetUpvalue(
            data,
            upvalue.Index
        )

        if not success then
            return false
        end

        value = fetched
    end

    upvalue.Value = value

    local scanned = upvalue.Scanned

    if type(value) ~= "table" then
        if scanned then
            upvalue.Scanned = nil
        end

        return true
    end

    if scanned then
        pcall(function()
            for i, v in pairs(value) do
                if scanned[i] ~= nil then
                    scanned[i] = v
                end
            end
        end)
    end

    return true
end

return Upvalue, TableUpvalue