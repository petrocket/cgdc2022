local Events = require "scripts.events"

local Timer = {
    timeLeft = 0,
    duration = 0,
    endTime = 0
}
Timer.__index = Timer
setmetatable(Timer, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})
function Timer.new (duration)
	local self = setmetatable({}, Timer)
	self.duration = math.ceil(duration)
    self.timeLeft = duration
	return self
end

function Timer:Start()
    if self.tickBusHandler ~= nil then
        self.tickBusHandler:Disconnect()
    end
    self.timeLeft = self.duration
    self:Resume()
end

function Timer:OnTick(deltaTime, scriptTime)
    local timeLeft = math.ceil(self.endTime - scriptTime:GetSeconds())
    if timeLeft ~= self.timeLeft and timeLeft >= 0 then
        Events:GlobalLuaEvent(Events.OnUpdateTimeRemaining, tostring(timeLeft))
        self.timeLeft = timeLeft
    elseif timeLeft < 0 then
        Events:GlobalLuaEvent(Events.OnTimerFinished)
        self:Stop()
    end
end

function Timer:Stop()
    self:Pause()
    self.timeLeft = -1
end

function Timer:Pause()
    if self.tickBusHandler ~= nil then
        self.tickBusHandler:Disconnect()
        self.tickBusHandler = nil
    end
end

function Timer:Resume()
    self.tickBusHandler = TickBus.Connect(self)
    local time = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
    self.endTime = time:GetSeconds() + self.timeLeft 
    Events:GlobalLuaEvent(Events.OnUpdateTimeRemaining, tostring(self.timeLeft))
end

return Timer