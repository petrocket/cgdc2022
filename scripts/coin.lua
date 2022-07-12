local Events = require "scripts.events"
local Utilities = require "scripts.utilities"

local Coin = {
    Properties = {
        Debug = false,
        Mesh = EntityId()
    }
}

function Coin:OnActivate()
    Utilities:InitLogging(self, "Coin")

    local translation = TransformBus.Event.GetWorldTranslation(self.entityId)
    local gridPosition = tostring(math.floor(translation.x)) .. "_" .. tostring(math.floor(translation.y))
    Events:Connect(self, Events.OnRevealTile, gridPosition)
    Events:Connect(self, Events.OnStateChange)
end

function Coin:Reset()
    RenderMeshComponentRequestBus.Event.SetVisibility(self.Properties.Mesh, true)
end

function Coin:OnStateChange(newState)
    if newState == 'LevelBuildOut' then
        self:Reset()
    end
end

function Coin:OnRevealTile()
    local visible = RenderMeshComponentRequestBus.Event.GetVisibility(self.Properties.Mesh)
    if visible then
        RenderMeshComponentRequestBus.Event.SetVisibility(self.Properties.Mesh, false)
        Events:GlobalLuaEvent(Events.ModifyCoinAmount, 1)
    end
end

function Coin:OnDeactivate()
    local translation = TransformBus.Event.GetWorldTranslation(self.entityId)
    local gridPosition = tostring(math.floor(translation.x)) .. "_" .. tostring(math.floor(translation.y))
    Events:Disconnect(self, Events.OnRevealTile, gridPosition)
    Events:Disconnect(self, Events.OnStateChange)
end

return Coin