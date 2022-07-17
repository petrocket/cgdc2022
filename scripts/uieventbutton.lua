local Events = require "scripts.events"

local UiEventButton = {
    Properties = {
        Event = { default="Event"},
        Value = { default="Value"},
        InputEvent = ""
    }
}

function UiEventButton:OnActivate()
    self.handler = UiButtonNotificationBus.Connect(self, self.entityId)
    if self.Properties.InputEvent ~= "" and self.Properties.InputEvent ~= nil then
        self.inputHandler = InputEventNotificationBus.Connect(self, InputEventNotificationId(self.Properties.InputEvent))
    end
end

function UiEventButton:OnPressed(value)
    Events:GlobalLuaEvent(self.Properties.Event, self.Properties.Value)
end

function UiEventButton:OnButtonClick()
    Events:GlobalLuaEvent(self.Properties.Event, self.Properties.Value)
end

function UiEventButton:OnDeactivate()
    self.handler:Disconnect()
    self.handler = nil

    if self.inputHandler ~= nil then
        self.inputHandler:Disconnect()
        self.inputHandler = nil
    end
end

return UiEventButton