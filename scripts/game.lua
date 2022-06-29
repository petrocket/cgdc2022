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
        },
        NumEnemies = 3,
        NumWeaponCards = 30,
        TilePrefab = {default=SpawnableScriptAssetRef(), description="Tile Prefab to spawn"}
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
	},
    InputEvents = {
        Player1Action1 = {},
        Player1Action2 = {},
        Player1Action3 = {},
        Player1Action4 = {},
        Player1UpDown = {},
        Player1LeftRight = {},
        MouseLeftClick = {}
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

    -- prep random enemies
    math.randomseed(math.ceil(time:GetSeconds()))
    sm.UserData.enemies = {}
    for i = 1,sm.UserData.Properties.NumEnemies do
        -- TODO give random number of weaknesses and amounts
        table.insert(sm.UserData.enemies, {
            Name = 'enemy '..tostring(i),
            Weaknesses = {
                Weakness1 = { Weapon='Weapon1', Amount=1},
                Weakness2 = { Weapon='Weapon2', Amount=2},
                Weakness3 = { Weapon='Weapon3', Amount=3}
            }
        })
    end
    Utilities:Shuffle(sm.UserData.enemies)
    Events:GlobalLuaEvent(Events.OnSetEnemies, sm.UserData.enemies)
    Events:GlobalLuaEvent(Events.OnSetEnemy, sm.UserData.enemies[1])

    sm.UserData.player1CardDeck = {}
    cardColors = {}
    table.insert(cardColors, Color(255.0 / 255.0, 0.0,0.0,1.0))
    table.insert(cardColors, Color(0,172.0 / 255.0,34.0 / 255.0,1.0))
    table.insert(cardColors, Color(0,150.0/ 255.0,210.0 / 255.0,1.0))
    table.insert(cardColors, Color(217.0/ 255.0,207.0 / 255.0,20.0 / 255.0,1.0))


    local numWeaponCardTypes = 4
    for i = 1,sm.UserData.Properties.NumWeaponCards do
        local cardTypeId = (i %  numWeaponCardTypes) + 1
        table.insert(sm.UserData.player1CardDeck, {
            Name = 'Weapon'..tostring(cardTypeId),
            Weakness = 'Weakness'..tostring(cardTypeId),
            Color = cardColors[cardTypeId] 
        })
    end
    Utilities:Shuffle(sm.UserData.player1CardDeck)

    local numActiveCards = 4
    sm.UserData.player1ActiveCards = {}
    for i = 1, numActiveCards do
        local card = table.remove(sm.UserData.player1CardDeck)
        table.insert(sm.UserData.player1ActiveCards, card)
        Events:LuaEvent(Events.OnSetPlayerCard, "Player1", i, card)
    end

    sm.OnEnemyDefeated = function(sm)
        sm:GotoState("Win")
    end
    Events:Connect(sm, Events.OnEnemyDefeated)

    -- spawn "the grid"
    sm.UserData:ResetGrid()
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
function game.States.Win.OnEnter(sm)
    sm.OnRetryPressed = function(sm)
        sm:GotoState("InGame")
    end
    Events:Connect(sm, "OnRetryPressed")
    sm.OnQuitPressed = function(sm)
        ConsoleRequestBus.Broadcast.ExecuteConsoleCommand("quit")
    end
    Events:Connect(sm, "OnQuitPressed")
end

function game.States.Win.OnExit(sm)
    Events:Disconnect(sm, "OnRetryPressed")
    Events:Disconnect(sm, "OnQuitPressed")
end

function game:OnActivate()
    Utilities:InitLogging(self, "Game")
    self.stateMachine = {}
    self.timeRemaining = 0;
    self.spawnableMediator = SpawnableScriptMediator()
    self.spawnTicket = self.spawnableMediator:CreateSpawnTicket(self.Properties.TilePrefab)
    self:BindInputEvents(self.InputEvents)

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

 function game.InputEvents.Player1Action1:OnPressed(value)
    self.Component:UseCard(self.Component.player1ActiveCards, 1, 1, self.Component.player1CardDeck)
 end
 function game.InputEvents.Player1Action2:OnPressed(value)
    self.Component:UseCard(self.Component.player1ActiveCards, 2, 1, self.Component.player1CardDeck)
 end
 function game.InputEvents.Player1Action3:OnPressed(value)
    self.Component:UseCard(self.Component.player1ActiveCards, 3, 1, self.Component.player1CardDeck)
 end
 function game.InputEvents.Player1Action4:OnPressed(value)
    self.Component:UseCard(self.Component.player1ActiveCards, 4, 1, self.Component.player1CardDeck)
 end

 function game:ResetGrid()
    self.spawnableMediator:Despawn(self.spawnTicket)
    local gridSizeX = 3
    local gridSizeY = 5
    for x = 1, gridSizeX do
        for y = 1,gridSizeY do
            self.spawnableMediator:SpawnAndParentAndTransform(
                self.spawnTicket,
                self.entityId,
                Vector3(x - 1,y - 1,0.0),
                Vector3(0,0,0),
                1.0
            )
        end
    end
 end

 function game:UseCard(cards, cardIndex, playerIndex, deck)
    local damageTaken = false
    local card = cards[cardIndex]
    if card ~= nil then
        self:Log("UseCard " ..tostring(card.Name))
        damageTaken = Events:GlobalLuaEvent(Events.OnTakeDamage, card.Weakness, 1)
    end

    if damageTaken then
        self:Log("Getting new card")
        if #deck > 0 then
            card = table.remove(deck)
        else
            self:Log("Deck empty")
            card = nil
        end
        cards[cardIndex] = card
        Events:LuaEvent(Events.OnSetPlayerCard, "Player"..tostring(playerIndex), cardIndex, card)
    end
 end

 function game.InputEvents.Player1UpDown:OnPressed(value)
 end
 function game.InputEvents.Player1LeftRight:OnPressed(value)
 end
 function game.InputEvents.MouseLeftClick:OnPressed(value)
 end

function game:BindInputEvents(events)
	for event, handler in pairs(events) do
		handler.Component = self
		handler.Listener = InputEventNotificationBus.Connect(handler, InputEventNotificationId(event))
	end
end

function game:UnBindInputEvents(events)
	for event, handler in pairs(events) do
		handler.Listener:Disconnect()
		handler.Listener = nil
	end
end

function game:OnDeactivate()
    self:UnBindInputEvents(self.InputEvents)
    while UiCursorBus.Broadcast.IsUiCursorVisible() == true do
        UiCursorBus.Broadcast.DecrementVisibleCounter()
    end
    Events:ClearAll()
end

return game