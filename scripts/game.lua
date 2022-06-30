local StateMachine = require "scripts/statemachine"
local Utilities = require "scripts/utilities"
local Events = require "scripts.events"
local Timer = require "scripts/timer"

local game = {
    Properties = {
        Debug = true,
        DebugEvents = false,
        InitialState = "MainMenu",
        TimeLimit = {
            default = 30, 
            description="Time limit",  
            suffix=" sec"
        },
        NumEnemies = 3,
        NumWeaponCards = 30,
        TilePrefab = {default=SpawnableScriptAssetRef(), description="Tile Prefab to spawn"},
        PlayerMoveSpeed = 2.0,
        RevealSpeed = 2.0,
        Player1 = EntityId()
    },
    States = {
		MainMenu = {
        	Transitions = {
                LevelBuildOut = {}
            }
        },    
        LevelBuildOut = {
            Transitions = {
                RevealTiles = {}
            }
        },
        RevealTiles = {
            Transitions = {
                Navigation = {}
            }
        },
        Navigation = {
            Transitions = {
                RevealTiles = {},
                Combat = {},
                Treasure = {},
                Lose = {},
                Win = {}
            }
        },
        Combat = {
            Transitions = {
                RevealTiles = {},
                Lose = {},
                Win = {}
            }
        },
        Treasure = {
            Transitions = {
                RevealTiles = {}
            }
        },
        Paused = { Transitions = {} },
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
    },
}

local TileState = {
    Navigation = "Navigation",
    Treasure = "Treasure",
    Combat = "Combat"
}

-------------------------------------------
---  MainMenu
-------------------------------------------
function game.States.MainMenu.OnEnter(sm)
    -- show main menu screen
end

function game.States.MainMenu.Transitions.LevelBuildOut.Evaluate(sm)
    return true
end


-------------------------------------------
--- LevelBuildOut
-------------------------------------------
function game.States.LevelBuildOut.OnEnter(sm)
    -- generate the level and animate it 
    sm.UserData:ResetGrid()
    sm.UserData.currentEnemy = 1
    TransformBus.Event.SetLocalTranslation(sm.UserData.Properties.Player1, Vector3(-100,-100,-100))

    -- prep random enemies
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
end
function game.States.LevelBuildOut.OnExit(sm)
    sm.UserData.timer:Start()
    TransformBus.Event.SetLocalTranslation(sm.UserData.Properties.Player1, Vector3(0.0,0.0,0.0))
end
function game.States.LevelBuildOut.Transitions.RevealTiles.Evaluate(sm)
    return true
end

-------------------------------------------
--- RevealTiles
-------------------------------------------
function game.States.RevealTiles.OnEnter(sm)
    -- show tiles in proximity to player
    sm.UserData.revealTilesEndTime = TickRequestBus.Broadcast.GetTimeAtCurrentTick():GetSeconds() + 
        1.0 / sm.UserData.Properties.RevealSpeed
    sm.UserData:Log("$5 revealing tiles")
end
function game.States.RevealTiles.Transitions.Navigation.Evaluate(sm)
    local currentTime = TickRequestBus.Broadcast.GetTimeAtCurrentTick():GetSeconds()
    return currentTime >= sm.UserData.revealTilesEndTime 
end

-------------------------------------------
--- Navigation
-------------------------------------------
function game.States.Navigation.OnEnter(sm)
    sm.UserData.player1MoveAmount = 0
end
function game.States.Navigation.OnUpdate(sm, deltaTime, scriptTime)
    if sm.UserData.player1Moving then
        local moveAmount = scriptTime:GetSeconds() - sm.UserData.player1MoveStartTime
        moveAmount = math.min(1.0,  moveAmount / (1.0 / sm.UserData.Properties.PlayerMoveSpeed)) 
        local translation = sm.UserData.player1MoveStart:Lerp(sm.UserData.player1MoveEnd, moveAmount)
        TransformBus.Event.SetWorldTranslation(sm.UserData.Properties.Player1, translation)
        sm.UserData.player1MoveAmount = moveAmount
    elseif sm.UserData.player1Movement:GetLengthSq() > 0 then
        sm.UserData.player1Moving = true
        sm.UserData.player1MoveStartTime = scriptTime:GetSeconds()
        sm.UserData.player1MoveStart = TransformBus.Event.GetWorldTranslation(sm.UserData.Properties.Player1)
        if sm.UserData.player1Movement.x ~= 0 then
            sm.UserData.player1MoveEnd = sm.UserData.player1MoveStart + Vector3(math.ceil(sm.UserData.player1Movement.x), 0, 0)
        else
            sm.UserData.player1MoveEnd = sm.UserData.player1MoveStart + Vector3(0, math.ceil(sm.UserData.player1Movement.y), 0)
        end
        sm.UserData:Log("$3 player movement")
    end
end
function game.States.Navigation.OnExit(sm)
    sm.UserData.player1Moving = false
end
function game.States.Navigation.Transitions.RevealTiles.Evaluate(sm)
    local x = sm.UserData.player1MoveEnd.x + 1
    local y = sm.UserData.player1MoveEnd.y + 1
    if x > 0 and y > 0 then
        return sm.UserData.player1MoveAmount >= 1.0 and not sm.UserData.grid[x][y].enemy
    else
        return sm.UserData.player1MoveAmount >= 1.0
    end
end
function game.States.Navigation.Transitions.Combat.Evaluate(sm)
    local x = sm.UserData.player1MoveEnd.x + 1
    local y = sm.UserData.player1MoveEnd.y + 1
    if x > 0 and y > 0 then
        return sm.UserData.player1MoveAmount >= 1.0 and sm.UserData.grid[x][y].enemy
    else
        return false
    end
end
function game.States.Navigation.Transitions.Treasure.Evaluate(sm)
    return false
end
function game.States.Navigation.Transitions.Lose.Evaluate(sm)
    return sm.UserData.timer.timeLeft <= 0 
end
function game.States.Navigation.Transitions.Win.Evaluate(sm)
    return false
end

-------------------------------------------
--- Combat
-------------------------------------------
function game.States.Combat.OnEnter(sm)
    -- show combat UI
    Events:GlobalLuaEvent(Events.OnSetEnemyCardVisible, true)
    Events:GlobalLuaEvent(Events.OnSetPlayerCardsVisible, 1, true)

    Events:GlobalLuaEvent(Events.OnSetEnemy, sm.UserData.enemies[sm.UserData.currentEnemy])

    sm.OnEnemyDefeated = function(sm)
        local x = sm.UserData.player1MoveEnd.x + 1
        local y = sm.UserData.player1MoveEnd.y + 1
        sm.UserData.grid[x][y].enemy = false
        if sm.UserData.currentEnemy >= sm.UserData.Properties.NumEnemies then
            sm:GotoState("Win")
        else
            sm.UserData.currentEnemy = sm.UserData.currentEnemy + 1
            sm:GotoState("Navigation")
        end
    end
    Events:Connect(sm, Events.OnEnemyDefeated)

    sm.OnRunAway = function(sm)
        TransformBus.Event.SetWorldTranslation(sm.UserData.Properties.Player1, sm.UserData.player1MoveStart)
        sm:GotoState("Navigation")
    end
    Events:Connect(sm, Events.OnRunAway)
end
function game.States.Combat.OnExit(sm)
    Events:Disconnect(sm, Events.OnEnemyDefeated)
    Events:Disconnect(sm, Events.OnRunAway)
    Events:GlobalLuaEvent(Events.OnSetEnemyCardVisible, false)
    Events:GlobalLuaEvent(Events.OnSetPlayerCardsVisible, 1, false)
end
function game.States.Combat.Transitions.RevealTiles.Evaluate(sm)
    return false
end
function game.States.Combat.Transitions.Lose.Evaluate(sm)
    return sm.UserData.timer.timeLeft <= 0 
end
function game.States.Combat.Transitions.Win.Evaluate(sm)
    return false
end

-------------------------------------------
--- Treasure
-------------------------------------------
function game.States.Treasure.Transitions.RevealTiles.Evaluate(sm)
    return false
end

-------------------------------------------
--- Lose
-------------------------------------------
function game.States.Lose.OnEnter(sm)
    sm.UserData.timer:Pause()

    sm.OnRetryPressed = function(sm)
        sm:GotoState("LevelBuildOut")
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
    sm.UserData.timer:Pause()
    sm.OnRetryPressed = function(sm)
        sm:GotoState("LevelBuildOut")
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
    self.tileState = nil
    self.timer = Timer(self.Properties.TimeLimit)

    self.player1Moving = false
    self.player1MoveStart = Vector3(0,0,0) 
    self.player1MoveEnd = Vector3(0,0,0) 
    self.player1Movement = Vector2(0,0)
    self.player1MoveStartTime = 0 

    local time = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
    math.randomseed(math.ceil(time:GetSeconds()))

    Events.DebugEvents = self.Properties.DebugEvents

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

function game:StartTimer()
end
function game:PauseTimer()
end
function game:ResumeTimer()
end
function game:StopTimer()
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

function game.InputEvents.Player1UpDown:OnPressed(value)
    self.Component.player1Movement.y = value
end
function game.InputEvents.Player1UpDown:OnHeld(value)
    self.Component.player1Movement.y = value
end
function game.InputEvents.Player1UpDown:OnReleased(value)
    self.Component.player1Movement.y = 0
end

function game.InputEvents.Player1LeftRight:OnPressed(value)
    self.Component.player1Movement.x = value
end
function game.InputEvents.Player1LeftRight:OnHeld(value)
    self.Component.player1Movement.x = value
end
function game.InputEvents.Player1LeftRight:OnReleased(value)
    self.Component.player1Movement.x = 0
end


function game:ResetGrid()
    self.spawnableMediator:Despawn(self.spawnTicket)
    self.grid = {}
    local gridSizeX = 3
    local gridSizeY = 5
    for x = 1, gridSizeX do
        self.grid[x] = {}
        for y = 1,gridSizeY do
            self.grid[x][y] = {
                type="Path",
                enemy=false
            }
            if y % 2 == 1 or x %2 == 1 then
                self.grid[x][y].enemy = true
            end
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