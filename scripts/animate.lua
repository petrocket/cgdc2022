local Easing = require "scripts.easing"
local Utilities = require "scripts.utilities"

local Animate = {
    Properties = {
   		Debug = true,
		Relative = true,
		Destination = Vector3(0,0,1),
		Duration = {default=3.0, suffix = "s"},
		Loop = true,
		Method = { default = "InOutSine"}
    }
}

function Animate:OnActivate()
    Utilities:InitLogging(self, "Animate")

    local tm = TransformBus.Event.GetWorldTM(self.entityId)
	self.startWorldPosition = tm:GetTranslation()
	self.endWorldPosition = self.Properties.Relative and (self.startWorldPosition + self.Properties.Destination) or self.Properties.Destination
	self.endLocalPosition = self.endWorldPosition - self.startWorldPosition
	self.durationInMS = self.Properties.Duration * 1000

    self.value = Vector3(0,0,0)
	
	self.jobId = Easing:Ease(Easing[self.Properties.Method], self.durationInMS, self.value, self.endLocalPosition, self)
	self:Log("OnActivate " .. tostring(self.jobId))	
end

function Animate:OnEasingBegin(id, value)
	self:Log("OnEasingBegin " .. tostring(id) .. " ".. tostring(value))
end

function Animate:OnEasingUpdate(id, value)
	self:Log("OnEasingUpdate " .. tostring(id) .. " ".. tostring(value))
	
	local tm = TransformBus.Event.GetWorldTM(self.entityId)
	tm:SetTranslation(self.startWorldPosition + value)
	TransformBus.Event.SetWorldTM(self.entityId, tm)
end

function Animate:OnEasingEnd(id, value)
	self:Log("OnEasingEnd " .. tostring(id) .. " " .. tostring(value))	
	return self.Properties.Loop
end

function Animate:OnDeactivate()
    Easing:StopAll()
end

return Animate