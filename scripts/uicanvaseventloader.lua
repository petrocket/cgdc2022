local Events = require "scripts/events"

local UiCanvasEventLoader = {
    Properties = {
        Event = { default="Event"},
        Values = { default={"Value",""}}
    }
}

function UiCanvasEventLoader:OnActivate()
    self.canvasLoaded = false

    self[self.Properties.Event] = function(self, value)
        --Debug.Log("Received event value " .. tostring(value))
        local valueFound = false
        for i = 0, #self.Properties.Values do
            if value == self.Properties.Values[i] then
                if not self.canvasLoaded then
                    UiCanvasAssetRefBus.Event.LoadCanvas(self.entityId)
                    self.canvasLoaded = true
                end
                valueFound = true
                break
            end
        end
        if not valueFound and self.canvasLoaded then
            self.canvasLoaded = false 
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