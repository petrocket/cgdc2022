local Events = require "scripts/events"

local UiCanvasEventLoader = {
    Properties = {
        Event = { default="Event"},
        ActivateValue = { default="Value"}
    }
}

function UiCanvasEventLoader:OnActivate()
    self[self.Properties.Event] = function(self, value)
        --Debug.Log("Received event value " .. tostring(value))
        if value == self.Properties.ActivateValue then
            UiCanvasAssetRefBus.Event.LoadCanvas(self.entityId)
        else
            UiCanvasAssetRefBus.Event.UnloadCanvas(self.entityId)
        end
    end
    --Debug.Log("Connecting uicanvas loader to " .. self.Properties.Event)
    Events:Connect(self, self.Properties.Event)
end

function UiCanvasEventLoader:OnDeactivate()
    Events:Disconnect(self, self.Properties.Event)
end

return UiCanvasEventLoader