local Events = require "scripts/events"
local Utilities = {}

function Utilities:RequestProperty(entityId, property, callback)
    -- have to use the Utilities local or the object seems to go out of scope by the time
    -- the event is sent
    Utilities.handler = {
        OnEventBegin = function(self, value)
            --Debug.Log("Received property value " .. tostring(value))
            callback(value)
            Utilities.handler.listener:Disconnect()
        end,
        listener = nil
    }
    Utilities.handler.listener = GameplayNotificationBus.Connect(Utilities.handler, GameplayNotificationId(entityId, Events.OnReceiveProperty, "float"))
    
    --Debug.Log("Requesting property " .. tostring(property))
    Events:Event(entityId, Events.OnRequestProperty, property)
    --local id = GameplayNotificationId(entityId, "OnRequestProperty", "float")
    --GameplayNotificationBus.Event.OnEventBegin(id, property)
end 

function Utilities:BindEvents(component, events)
    for event, handler in pairs(events) do
        handler.Component = component
        
        -- create Bind function
        if handler.global then
            --component:Log("Binding global event " .. tostring(event))
            handler.Bind = function(self) 
                self.Component:Log("Binding global event " .. tostring(event))
                self.Listener = GameplayNotificationBus.Connect(self, GameplayNotificationId(EntityId(0), event, "float"))
            end
        else
            --component:Log("Binding event " .. tostring(event))
            handler.Bind = function(self) 
                self.Component:Log("Binding event " .. tostring(event))
                self.Listener = GameplayNotificationBus.Connect(self, GameplayNotificationId(component.entityId, event, "float"))
            end            
            --handler.Listener = GameplayNotificationBus.Connect(handler, GameplayNotificationId(component.entityId, event))
        end
        
        -- create UnBind function
        handler.UnBind = function(self)
            if self.Listener ~= nil then
                self.Listener:Disconnect()
                self.Listener = nil
            end
        end
        
        if handler.ignore then
            component:Log("Not binding event " .. tostring(event))
        else
            
            handler:Bind()
        end
        
    end
end

function Utilities:UnBindEvents(events)
    if events ~= nil then
        for event, handler in pairs(events) do
            if handler ~= nil then
                if handler.Listener ~= nil then
                    handler.Listener:Disconnect()
                end
                handler = nil
            end
        end
    end
end

function Utilities:InitLogging(object, name)
    if object.Log == nil then
        if object.debug ~= nil then
            object.Log = function(context, value) if context.debug then Debug.Log(name .. ": " .. tostring(value)); end end
        else
            object.Log = function(context, value) if context.Properties.Debug then Debug.Log(name .. ": " .. tostring(value)); end end
        end
    end
end

function Utilities:ExecuteOnNextTick(component, func)
    if component._nextTickHandler == nil or component._nextTickHandler.Listener == nil then
        -- create a handler to capture OnTick events
        component._nextTickHandler = {
            -- OnTick gets called by the TickBus
            OnTick = function(self, deltaTime, scriptTime)
                -- disconnect form the tick bus
                if self.Listener ~= nil then
                    self.Listener:Disconnect()
                    self.Listener = nil
                end
                -- call the function
                func(component)                                
            end
        }
    end

    -- connect to the TickBus
    component._nextTickHandler.Listener = TickBus.Connect(component._nextTickHandler, 0)
end

-- call a function when a tag is added to any entity
-- this is useful for getting entity ids of a unique entity
function Utilities:OnTagAdded(component, tag, func)
    if component._tagHandlers == nil then
        component._tagHandlers = {}
    end

    local handler = {
        listener = nil,
        activated = false,
        OnEntityTagAdded = function(self, entityId)
            activated = true
            if self.listener ~= nil then
                self.listener:Disconnect()
            end
            func(component, entityId)
        end
    }

    handler.listener = TagGlobalNotificationBus.Connect(handler, Crc32(tag))

    -- if an entity already has that tag OnEntityTagAdded will be called
    -- immediately so we can clean up now
    if handler.activated then
        if handler.listener ~= nil then
            handler.listener:Disconnect()
        end
        handler = nil
    else
        component._tagHandlers[tag] = handler
    end
end

function Utilities:OnActivated(component, entityIds, func)
    component._onActivatedEntities = entityIds
    if component._onActivatedHandlers == nil then
        component._onActivatedHandlers = {}
    end

    -- reverse iterate so we can remove elements from this table without messing
    -- up the iterator
    for i=#entityIds,1,-1 do
        local entityId = entityIds[i]
        --local name = GameEntityContextRequestBus.Broadcast.GetEntityName(entityId)
        --Debug:Log("Waiting for ".. tostring(name).." to activate ("..tostring(entityId)..")")

        local handler = {
            entityActivated = false,
            OnEntityActivated = function(self, activatedEntityId)
                --local name = GameEntityContextRequestBus.Broadcast.GetEntityName(activatedEntityId)
                --Debug:Log("entity " .. tostring(name) .. " activated")

                -- if it is in our list then remove it
                for i=#component._onActivatedEntities,1,-1 do
                    if component._onActivatedEntities[i] == activatedEntityId then
                        self.entityActivated = true
                        table.remove(component._onActivatedEntities,i)
                        break
                    end
                end

                if #component._onActivatedEntities <= 0 then
                    --Debug:Log("all entities activated")
                    func(component)
                end
            end
        }

        handler.listener = EntityBus.Connect(handler, entityId)
        -- if the entity activated immediately we disconnect/remove the listener
        if handler.entityActivated then
            handler.listener:Disconnect()
            handler = nil
        end
        component._onActivatedHandlers[tostring(entityId)] = handler
    end
end

function Utilities:Shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
end

function Utilities:GetKeyList(tbl)
  local result = {}
  -- use own index for speed improvement over table.insert on large tables of 10000+
  local i = 0
  for key, value in pairs(tbl)  do
    i=i+1
    result[i]=key
  end
  return result
end

function Utilities:Count(tbl)
    -- don't check for nil, we want those errors to cause failures so we see them
    local count = 0
    for key,value in pairs(tbl) do
        count = count + 1
    end
    return count
end

function Utilities:Split (str, sep)
	-- split a string based on separator 'sep'
    if sep == nil then
        sep = ","
    end
    local t={}
    for match in string.gmatch(str, "([^"..sep.."]+)") do
        table.insert(t, match)
    end
    return t
end

return Utilities