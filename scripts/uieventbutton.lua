local Events = require "scripts.events"

local UiEventButton = {
    Properties = {
        Event = { default="Event"},
        Value = { default="Value"}
    }
}

function UiEventButton:OnActivate()
    self.handler = UiButtonNotificationBus.Connect(self, self.entityId)
end

function UiEventButton:OnButtonClick()
    Events:GlobalLuaEvent(self.Properties.Event, self.Properties.Value)
end

function UiEventButton:OnDeactivate()
    self.handler:Disconnect()
    self.handler = nil
end

return UiEventButton