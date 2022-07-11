local StateMachine = require "scripts/statemachine"
local Utilities = require "scripts/utilities"
local Events = require "scripts.events"
local Timer = require "scripts/timer"
local Player = require "scripts/player"

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
        ProceduralLevel = false,
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
    game:ResetGrid()
    game.currentEnemy = 1

    -- hide the player by moving off the board while we build out
    TransformBus.Event.SetLocalTranslation(game.Properties.Player1, Vector3(-100,-100,-100))

    -- prep random enemies
    game.enemies = {}
    for i = 1,game.Properties.NumEnemies do
        -- TODO give random number of weaknesses and amounts
        table.insert(game.enemies, {
            Name = 'enemy '..tostring(i),
            Weaknesses = {
                Weakness1 = { Weapon='Weapon1', Amount=1},
                Weakness2 = { Weapon='Weapon2', Amount=2},
                Weakness3 = { Weapon='Weapon3', Amount=3}
            }
        })
    end
    Utilities:Shuffle(game.enemies)
    Events:GlobalLuaEvent(Events.OnSetEnemies, game.enemies)

    local cards = {}
    cardColors = {}
    table.insert(cardColors, Color(255.0 / 255.0, 0.0,0.0,1.0))
    table.insert(cardColors, Color(0,172.0 / 255.0,34.0 / 255.0,1.0))
    table.insert(cardColors, Color(0,150.0/ 255.0,210.0 / 255.0,1.0))
    table.insert(cardColors, Color(217.0/ 255.0,207.0 / 255.0,20.0 / 255.0,1.0))

    local numWeaponCardTypes = 4
    for i = 1,game.Properties.NumWeaponCards do
        local cardTypeId = (i %  numWeaponCardTypes) + 1
        table.insert(cards, {
            Name = 'Weapon'..tostring(cardTypeId),
            Weakness = 'Weakness'..tostring(cardTypeId),
            Color = cardColors[cardTypeId] 
        })
    end
    Utilities:Shuffle(cards)

    game.player1:SetCards(cards, 4)
end

function game.States.LevelBuildOut.OnExit(sm)
    game.timer:Start()

    -- TODO send to level start position
    game:MovePlayer(Vector3(0,0,0))
    --TransformBus.Event.SetLocalTranslation(game.Properties.Player1, Vector3(0.0,0.0,0.0))
end

function game:MovePlayer(position)
    TransformBus.Event.SetLocalTranslation(self.Properties.Player1, position)
end

function game.States.LevelBuildOut.Transitions.RevealTiles.Evaluate(sm)
    return true
end

-------------------------------------------
--- RevealTiles
-------------------------------------------
function game.States.RevealTiles.OnEnter(sm)
    -- show tiles in proximity to player
    game.revealTilesEndTime = TickRequestBus.Broadcast.GetTimeAtCurrentTick():GetSeconds() + 
        1.0 / game.Properties.RevealSpeed
    game:Log("$5 revealing tiles")
end
function game.States.RevealTiles.Transitions.Navigation.Evaluate(sm)
    local currentTime = TickRequestBus.Broadcast.GetTimeAtCurrentTick():GetSeconds()
    return currentTime >= game.revealTilesEndTime 
end

-------------------------------------------
--- Navigation
-------------------------------------------
function game.States.Navigation.OnUpdate(sm, deltaTime, scriptTime)
    game.player1:Update(deltaTime, scriptTime)
end
function game.States.Navigation.Transitions.RevealTiles.Evaluate(sm)
    if game.player1.moveAmount >= 1.0 then
        local tile = game:GetTile(game.player1.moveEnd)
        return not tile.enemy
    end
    return false
end
function game.States.Navigation.Transitions.Combat.Evaluate(sm)
    if game.player1.moveAmount >= 1.0 then
        local tile = game:GetTile(game.player1.moveEnd)
        return tile.enemy
    end
    return false
end
function game.States.Navigation.Transitions.Treasure.Evaluate(sm)
    return false
end
function game.States.Navigation.Transitions.Lose.Evaluate(sm)
    return game.timer.timeLeft <= 0 
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

    Events:GlobalLuaEvent(Events.OnSetEnemy, game.enemies[game.currentEnemy])

    sm.OnEnemyDefeated = function(sm)
        local x = game.player1.moveEnd.x
        local y = game.player1.moveEnd.y
        game.grid[x][y].enemy = false
        if game.grid[x][y].boss then
            sm:GotoState("Win")
        elseif game.currentEnemy >= game.numEnemies then
            sm:GotoState("Win")
        else
            game.currentEnemy = game.currentEnemy + 1
            sm:GotoState("Navigation")
        end
    end
    Events:Connect(sm, Events.OnEnemyDefeated)

    sm.OnDiscard = function(sm)

    end
    sm.OnRunAway = function(sm)
        game:RunAway()
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
    return game.timer.timeLeft <= 0 
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
    game.timer:Pause()

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
    game.timer:Pause()
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

    -- there's only one game instance so assign game to this object
    -- because using 'game' is much simpler and clear 
    -- than using sm.UserData in the statemachine
    game = self

    self.timeRemaining = 0;
    self.spawnableMediator = SpawnableScriptMediator()
    self.spawnTicket = self.spawnableMediator:CreateSpawnTicket(self.Properties.TilePrefab)
    self:BindInputEvents(self.InputEvents)
    self.tileState = nil
    self.timer = Timer(self.Properties.TimeLimit)
    self.player1 = {}
    self.tiles = {}
    self.numEnemies = self.Properties.NumEnemies

    self.tagListener = TagGlobalNotificationBus.Connect(self, Crc32("Tile"))
    Events:Connect(self, Events.GetTile)

    local time = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
    math.randomseed(math.ceil(time:GetSeconds()))

    Events.DebugEvents = self.Properties.DebugEvents

    self.stateMachine = {}
    setmetatable(self.stateMachine, StateMachine)

    while UiCursorBus.Broadcast.IsUiCursorVisible() == false do
        UiCursorBus.Broadcast.IncrementVisibleCounter()
    end

    -- execute on the next tick after every entity is activated
    Utilities:ExecuteOnNextTick(self, function(self)

        self.player1 = Events:LuaEvent(Events.GetPlayer, 1)

        local sendEventOnStateChange = true
        self.stateMachine:Start("Game Logic State Machine", 
            self.entityId, self, self.States, 
            sendEventOnStateChange, 
            self.Properties.InitialState,  
            self.Properties.Debug)  
    end)
end

function game:OnEntityTagAdded(entityId)
    self:Log("Tile spawned " ..tostring(entityId))
    table.insert(self.tiles, entityId)
end

function game:OnEntityTagRemoved(entityId)
    self:Log("Tile de-spawned " ..tostring(entityId))
    table.remove(self.tiles, entityId)
end

function game.InputEvents.MouseLeftClick:OnPressed(value)
end

function game:GetTile(gridPosition)
    self:Log("GetTile")
    if gridPosition ~= nil then
        local x = math.floor(gridPosition.x)
        local y = math.floor(gridPosition.y)
        if self.grid[x] ~= nil then
            if self.grid[x][y] ~= nil then
                return self.grid[x][y]
            end
        end
    end

    return {
        type="None",
        walkable = false,
        enemy=false
    }
end

function game:ResetGrid()
    self.spawnableMediator:Despawn(self.spawnTicket)
    self.grid = {}
    if self.Properties.ProceduralLevel then
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
    else
        self.numEnemies = 0

        -- find all tiles and add them to our grid
        for i=1,#self.tiles do
            local entityId = self.tiles[i]
            local translation = TransformBus.Event.GetWorldTranslation(entityId)
            local x = math.floor(translation.x)
            local y = math.floor(translation.y)
            if self.grid[x] == nil then
                self.grid[x] = {}
            end

            -- TODO potentially just GetTags and store them on the tile
            -- or add a lua entity so can use different data types
            local isWalkable = TagComponentRequestBus.Event.HasTag(entityId, Crc32("Walkable"))
            local hasEnemy = TagComponentRequestBus.Event.HasTag(entityId, Crc32("Enemy"))
            local isBoss = TagComponentRequestBus.Event.HasTag(entityId, Crc32("Boss"))
            local isMiniBoss = TagComponentRequestBus.Event.HasTag(entityId, Crc32("MiniBoss"))

            if hasEnemy then
                self.numEnemies = self.numEnemies + 1
            end
            self.grid[x][y] = {
                enemy = hasEnemy,
                boss = isBoss,
                miniBoss = isMiniBoss,
                walkable = isWalkable,
                revealed = false
            }
        end
    end
end

function game:InCombat()
    return self.stateMachine.CurrentStateName == "Combat"
end

function game:RunAway()
    if not self:InCombat() then
       return 
    end

    TransformBus.Event.SetWorldTranslation(self.Properties.Player1, self.player1.moveStart)
    self.stateMachine:GotoState("Navigation")
end

function game:BindInputEvents(events)
	for event, handler in pairs(events) do
		handler.Component = self
		handler.Listener = InputEventNotificationBus.Connect(handler, InputEventNotificationId(event))
	end
end

function game:UnBindInputEvents(events)
	for event, handler in pairs(events) do
        if handler ~= nil and handler.Listener ~= nil then
            handler.Listener:Disconnect()
            handler.Listener = nil
        end
	end
end

function game:OnDeactivate()
    if self.tagListener ~= nil then
        self.tagListener:Disconnect()
    end

    self.spawnableMediator:Despawn(self.spawnTicket)
    self.stateMachine:Stop()
    self:UnBindInputEvents(self.InputEvents)
    while UiCursorBus.Broadcast.IsUiCursorVisible() == true do
        UiCursorBus.Broadcast.DecrementVisibleCounter()
    end
    Events:ClearAll()
end

return game