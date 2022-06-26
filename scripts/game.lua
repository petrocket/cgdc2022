local StateMachine = require "scripts/statemachine"
local Utilities = require "scripts/utilities"
local Events = require "scripts.events"

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
		MainMenu = {
        	Transitions = {
                InGame = {}
            }
        },       
        InGame = {
            Transitions = {
                Lose = {},
                Win = {}
            }
        },
        Lose = { Transitions = {} },
        Win = { Transitions = {} },
	}
}

-------------------------------------------
---  MainMenu
-------------------------------------------
function game.States.MainMenu.OnEnter(sm)
end

function game.States.MainMenu.Transitions.InGame.Evaluate(sm)
    return true
end

-------------------------------------------
--- InGame 
-------------------------------------------
function game.States.InGame.OnEnter(sm)
    local time = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
    sm.UserData.roundOverTime = time:GetSeconds() + sm.UserData.Properties.TimeLimit
    sm.UserData.timeRemaining = math.ceil(sm.UserData.Properties.TimeLimit) 
    sm.UserData.playerWon = false
    sm.UserData:Log("Time remaining: " ..tostring(sm.UserData.timeRemaining) .. " seconds")
    Events:GlobalLuaEvent(Events.OnUpdateTimeRemaining,tostring(sm.UserData.timeRemaining))
end

function game.States.InGame.OnUpdate(sm, deltaTime, scriptTime)
    local timeRemaining = math.ceil(sm.UserData.roundOverTime - scriptTime:GetSeconds())
    if timeRemaining ~= sm.UserData.timeRemaining and timeRemaining >= 0 then
        Events:GlobalLuaEvent(Events.OnUpdateTimeRemaining,tostring(timeRemaining))
        sm.UserData:Log("Time remaining: " ..tostring(timeRemaining) .. " seconds")
        sm.UserData.timeRemaining = timeRemaining
    end
end

function game.States.InGame.Transitions.Lose.Evaluate(sm)
    return sm.UserData.timeRemaining <= 0
end

function game.States.InGame.Transitions.Win.Evaluate(sm)
    return sm.UserData.playerWon
end

-------------------------------------------
--- Lose
-------------------------------------------
function game.States.Lose.OnEnter(sm)
    sm.OnRetryPressed = function(sm)
        sm:GotoState("InGame")
    end
    Events:Connect(sm, "OnRetryPressed")
    sm.OnQuitPressed = function(sm)
        ConsoleRequestBus.Broadcast.ExecuteConsoleCommand("quit")
    end
    Events:Connect(sm, "OnQuitPressed")
end

function game.States.Lose.OnExit(sm)
    Events:Disconnect(sm, "OnRetryPressed")
    Events:Disconnect(sm, "OnQuitPressed")
end

-------------------------------------------
--- Win
-------------------------------------------

function game:OnActivate()
    Utilities:InitLogging(self, "Game")
    self.stateMachine = {}
    self.timeRemaining = 0;

    Events.DebugEvents = self.Properties.Debug

    while UiCursorBus.Broadcast.IsUiCursorVisible() == false do
        UiCursorBus.Broadcast.IncrementVisibleCounter()
    end
    setmetatable(self.stateMachine, StateMachine)

    -- execute on the next tick after every entity is activated
    Utilities:ExecuteOnNextTick(self, function(self)
        local sendEventOnStateChange = true
        self.stateMachine:Start("Game Logic State Machine", 
            self.entityId, self, self.States, 
            sendEventOnStateChange, 
            self.Properties.InitialState,  
            self.Properties.Debug)    
    end)
end

function game:OnDeactivate()
    while UiCursorBus.Broadcast.IsUiCursorVisible() == true do
        UiCursorBus.Broadcast.DecrementVisibleCounter()
    end
    Events:ClearAll()
end

return game