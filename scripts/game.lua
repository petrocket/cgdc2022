local StateMachine = require "scripts/statemachine"
local Utilities = require "scripts/utilities"

local game = {
    Properties = {
        Debug = true,
        InitialState = "MainMenu",
        TimeLimit = {
            default = 30, 
            description="Time limit",  
            suffix=" sec"
        }
    },
    States = {
		MainMenu =
        {
        	OnEnter = function(sm)
        		-- sm.UserData.currentLevel = 0
        		-- Events:GlobalEvent(Events.OnSetLevel, sm.UserData.currentLevel)
        		-- or continue?
        	end,
        	Transitions =
        	{
        		InGame =
        		{
        			Evaluate = function(sm)
                        -- TODO menu
        				return true 
        			end
        		}
        	}          
        },       
        InGame = 
        {
            OnEnter = function(sm)
                local time = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
                sm.UserData.roundOverTime = time:GetSeconds() + sm.UserData.Properties.TimeLimit
                sm.UserData.timeRemaining = math.ceil(sm.UserData.Properties.TimeLimit) 
                sm.UserData.playerWon = false
                sm.UserData:Log("Time remaining: " ..tostring(sm.UserData.timeRemaining) .. " seconds")
            end,
            OnUpdate = function(sm, deltaTime, scriptTime)
                local timeRemaining = math.ceil(sm.UserData.roundOverTime - scriptTime:GetSeconds())
                if timeRemaining ~= sm.UserData.timeRemaining and timeRemaining >= 0 then
                    sm.UserData:Log("Time remaining: " ..tostring(timeRemaining) .. " seconds")
                    sm.UserData.timeRemaining = timeRemaining
                end
            end,
            Transitions =
            {
                Lose =
                {
                    Evaluate = function(sm)
                        return sm.UserData.timeRemaining <= 0
                    end
                },
                Win =
                {
                    Evaluate = function(sm)
                        return sm.UserData.playerWon
                    end
                }
            }
        },
        Lose =
        {
        	OnEnter = function(sm)
        	end,
        	Transitions =
        	{
                Reset =
                {
                    Evaluate = function(sm)
                        -- TODO wait for player input to reset or use timer 
                        return false
                    end

                }
        	}
        },
        Win =
        {
        	OnEnter = function(sm)
        		-- Events:Event(sm.UserData.Properties.Player, Events.OnSetEnabled, false)
        		-- sm.UserData.currentLevel = sm.UserData.currentLevel + 1
        		
        		-- Events:GlobalEvent(Events.OnSetLevel, sm.UserData.currentLevel)
        	end,
        	Transitions =
        	{
                Reset =
                {
                    Evaluate = function(sm)
                        -- TODO wait for player input to reset or use timer 
                        return false
                    end

                }
        	}
        },
	}
}

function game:OnActivate()
    Utilities:InitLogging(self, "Game")
    self:Log("activate")
    --self:Reset()
    --self.tickHandler = TickBus.Connect(self, 0)
    self.stateMachine = {}
    setmetatable(self.stateMachine, StateMachine)

    -- execute on the next tick after every entity is activated for this level
    Utilities:ExecuteOnNextTick(self, function(self)
        local sendEventOnStateChange = true
        --Events:GlobalEvent(Events.OnSetLevel, self.currentLevel)
        self.stateMachine:Start("Game Logic State Machine", 
            self.entityId, self, self.States, 
            sendEventOnStateChange, 
            self.Properties.InitialState,  
            self.Properties.Debug)    
    end)
end

function game:OnTick(deltaTime, scriptTime)
    local timeRemaining = math.ceil(self.roundTimeLimit - scriptTime:GetSeconds())
    if timeRemaining ~= self.timeRemaining and timeRemaining >= 0 then
        self:Log("Time remaining: " ..tostring(timeRemaining) .. " seconds")
        self.timeRemaining = timeRemaining
    end

    if scriptTime:GetSeconds() > self.roundTimeLimit then
        self:Log("Round over")
        self:Reset()
    end
end

function game:Reset()
    local time = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
    self.roundTimeLimit = time:GetSeconds() + self.Properties.TimeLimit
    self.timeRemaining = math.ceil(self.Properties.TimeLimit) 
    self:Log("Time remaining: " ..tostring(self.timeRemaining) .. " seconds")
end

function game:OnDeactivate()
    --self.tickHandler:Disconnect()
    self:Log("deactivate")
end

return game