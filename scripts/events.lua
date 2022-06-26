 local Events = require "scripts/eventnames" 
 if Events == nil then
    Events = {}
end

-- add some other events for Utilities
Events.OnRequestProperty = "OnRequestProperty"
Events.OnReceiveProperty = "OnReceiveProperty"
Events.OnGameDataUpdated = "OnGameDataUpdated"
Events.DebugEvents = false;

-- used by StateMachine
Events.OnStateChange = "OnStateChange"

function Events:Event(entityId, event, value)
	local id = GameplayNotificationId(entityId, event, "float")
	GameplayNotificationBus.Event.OnEventBegin(id, value)
end

function Events:EventResult(entityId, event, value)
    local id = GameplayNotificationId(entityId, event, "float")
    return GameplayRequestBus.Event.OnEventRequestFloat(id, value)
end

function Events:GlobalEvent(event, value)
	local id = GameplayNotificationId(EntityId(0), event, "float")
	GameplayNotificationBus.Event.OnEventBegin(id, value)
end


if _G["LuaEvents"] == nil then
	_G["LuaEvents"] = {}
end

-- call this on the deactivate of your main level to clean up all events
function Events:ClearAll()
    if self.DebugEvents then
        Debug.Log("Clearing all LuaEvents handlers ")
    end
	_G["LuaEvents"] = {}
end

function Events:Connect(listener, event, address)
	local combined = event .. "%" .. tostring(address)
	if _G["LuaEvents"][combined] == nil then
		_G["LuaEvents"][combined] = {}
	end

	table.insert(_G["LuaEvents"][combined], listener)
    if self.DebugEvents then
	    Debug.Log("Connected to " .. tostring(combined))
	--Debug.Log("Events:Connect has " .. tostring(table.getn(_G["LuaEvents"][combined])) .. " events registered")
    end
end

function Events:Disconnect(listener, event, address)
	local combined = event .. "%" .. tostring(address)
	local listeners = _G["LuaEvents"][combined]


	local numListeners = 0
	if listeners ~= nil then
		for k,l in ipairs(listeners) do
			if l == listener then
				table.remove(listeners,k)

                if self.DebugEvents then
                    Debug.Log("Disconnecting listener from event " .. tostring(combined))
                end
				--Debug.Log("Events:Disconnect has " .. tostring(table.getn(listeners)) .. " events registered")
				return
			end
		end
	end
end

function Events:LuaEvent(event, address, ...)
	--local args = {...}
	local combined = event .. "%" .. tostring(address)
    if self.DebugEvents then
	    Debug.Log("Looking for listeners for " .. tostring(combined))
    end
	local listeners = _G["LuaEvents"][combined]
	if listeners ~= nil then
        if self.DebugEvents then
		    Debug.Log("Found " ..tostring(#listeners) .." listeners for " .. tostring(combined))
        end
		for k,listener in ipairs(listeners) do
            if listener[event] == nil then
                if self.DebugEvents then
		            Debug.Log("Unable to send event " ..tostring(event) .." to listener because missing event function")
                end
            else
                listener[event](listener,...)
            end
		end
	end
end

function Events:LuaEventResult(event, address, ...)
	--local args = {...}
	local combined = event .. "%" .. tostring(address)
	local listeners = _G["LuaEvents"][combined]
	if listeners ~= nil then
		for k,listener in ipairs(listeners) do
			return listener[event](listener,...)
		end
	end

	return nil
end

function Events:GlobalLuaEvent(event, ...)
	self:LuaEvent(event, nil, ...)
end

function Events:GlobalLuaEventResult(event, ...)
	return self:LuaEvent(event, nil, ...)
end

return Events


-- To use this system you need to create a lua file named EventNames.lua in your scripts folder
-- This file should return an object with all the event names like so
-- return {
--     EventName1 = "EventName1,
--     EventName2 = "EventName2"
--     ...
-- }
-- Usage:
-- at the top of your Lua file add
-- local Events = require "scripts/ToolKit/events"
-- To send an event (for example EventName1 with a value of 1) add
-- Events:Event(entityId, Events.EventName1, 1)
