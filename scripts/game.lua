local StateMachine = require "scripts/statemachine"
local Utilities = require "scripts/utilities"
local Events = require "scripts.events"
local Timer = require "scripts/timer"
local Player = require "scripts/player"
local Card = require "scripts.card"
local Easing = require "scripts.easing"

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
        NumWeaponCards = 30,
        TilePrefab = {default=SpawnableScriptAssetRef(), description="Tile Prefab to spawn"},
        PlayerMoveSpeed = 2.0,
        RevealSpeed = 2.0,
        Player1 = EntityId(),
        Camera = EntityId(),
        CameraCombatFOV = 70,
        FlyInDuration = { default=1.5, suffix = " sec"},
        CombatEndingDuration = { default=2, suffix=" sec"}
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
                CombatFlyIn = {},
                Treasure = {},
                Lose = {}
            }
        },
        CombatFlyIn = {
            Transitions = {
                Combat = {}
            }
        },
        Combat = {
            Transitions = {
                CombatFlyOut = {},
                Lose = {}
            }
        },
        CombatFlyOut = {
            Transitions = {
                Navigation = {},
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
        MouseLeftClick = {},
        Esc = {}
    },
}

-------------------------------------------
---  MainMenu
-------------------------------------------
function game.States.MainMenu.OnEnter(sm)
    sm.newGamePressed = false
    sm.OnNewGamePressed = function(_sm)
        Events:Disconnect(_sm, Events.OnNewGamePressed)
        _sm.newGamePressed = true
    end
    sm.OnQuitPressed = function(_sm)
        Events:Disconnect(_sm, Events.OnQuitPressed)
        ConsoleRequestBus.Broadcast.ExecuteConsoleCommand("quit")
    end
    Events:Connect(sm, Events.OnQuitPressed)
    Events:Connect(sm, Events.OnNewGamePressed)

    game:TestSaveAndLoad()
end

function game.States.MainMenu.Transitions.LevelBuildOut.Evaluate(sm)
    return sm.newGamePressed 
end


-------------------------------------------
--- LevelBuildOut
-------------------------------------------
function game.States.LevelBuildOut.OnEnter(sm)
    -- generate the level and animate it 
    game:ResetGrid()
    game.currentEnemy = 1

    -- level stats
    game.totalEnemiesDefeated = 0
    game.totalCoinsCollected = 0
    game.totalCardsCollected = 0

    -- hide the player by moving off the board while we build out
    game.player1:SetVisible(false)
    game.cameraTM = TransformBus.Event.GetWorldTM(game.Properties.Camera)
    game.cameraFOV = CameraRequestBus.Event.GetFovDegrees(game.Properties.Camera)

    local cards = {}

    -- give the player an equal number of each common card
    for _,type in pairs(Card.Types.Common) do
        for i = 1,6 do
            table.insert(cards, Card(type))
        end
    end
    Utilities:Shuffle(cards)

    game.player1:SetCards(cards, 4)
    game.player1:SetCoinAmount(0)
end

function game.States.LevelBuildOut.OnExit(sm)
    game.player1:Move(Vector3(0,0,0), true)
    game.timer:Start()
    game.player1:SetVisible(true)
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

    local pos = game.player1:GridPosition()
    -- notify all tiles around the player
    for x=pos.x-1,pos.x+1 do
        for y=pos.y-1,pos.y+1 do
            --game:Log("Reveal " .. tostring(x).."_"..tostring(y))
            Events:LuaEvent(Events.OnRevealTile, tostring(x).."_"..tostring(y))
        end
    end
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
    if game.timer.timeLeft > 0 and game.player1.moveAmount >= 1.0 then
        local tile = game:GetTile(game.player1.moveEnd)
        return not tile.enemy and not tile.treasure
    end
    return false
end
function game.States.Navigation.Transitions.CombatFlyIn.Evaluate(sm)
    -- player must finish combat before moving
    if game.timer.timeLeft > 0 and game.player1.moveStart ~= game.player1.moveEnd then
        local tile = game:GetTile(game.player1.moveEnd)
        return tile.enemy
    end
    return false
end
function game.States.Navigation.Transitions.Treasure.Evaluate(sm)
    if game.timer.timeLeft > 0 and game.player1.moveAmount >= 1.0 then
        local tile = game:GetTile(game.player1.moveEnd)
        return tile.treasure
    end
    return false
end
function game.States.Navigation.Transitions.Lose.Evaluate(sm)
    return game.timer.timeLeft <= 0 
end

-------------------------------------------
--- CombatFlyIn
-------------------------------------------
function game:CameraEasingUpdate(startPosition, endPosition, endLookAtPosition, startFOV, endFOV, value)
    local position = startPosition:Lerp(endPosition, value)
    local tm = TransformBus.Event.GetWorldTM(self.Properties.Camera)
    local currentRotation = tm:GetRotation()

    local lookAtTM = Transform.CreateLookAt(position, endLookAtPosition, AxisType.YPositive)
    local rotation = currentRotation:Slerp(lookAtTM:GetRotation(), value)
    local fov = Math.Lerp(startFOV,endFOV,value)

    tm = Transform.CreateFromQuaternionAndTranslation(rotation, position)
    TransformBus.Event.SetWorldTM(game.Properties.Camera, tm)
    CameraRequestBus.Event.SetFovDegrees(game.Properties.Camera, fov)
end

function game.States.CombatFlyIn.OnEnter(sm)
    Events:LuaEvent(Events.SetAnimationEnabled, game.Properties.Camera, false)
    game.timer:Pause()

    local startPosition = game.cameraTM:GetTranslation()
    local forward = game.player1.meshTM:GetBasisY()
    local endPosition = game.player1.meshTM:GetTranslation() + Vector3(0,0,0.4) - forward * 0.2
    local endLookAtPosition = endPosition + forward + Vector3(0,0,-0.2)
    local startFOV = game.cameraFOV
    local endFOV = game.Properties.CameraCombatFOV

    game.player1:SetVisible(false)

    sm.cameraAnimating = true
    sm.OnEasingUpdate = function(sm, jobId, value )
        game:CameraEasingUpdate(startPosition, endPosition, endLookAtPosition, startFOV, endFOV, value)
    end
    sm.OnEasingEnd = function(sm)
        sm.cameraAnimating = false
    end

	game.cameraEasingId = Easing:Ease(Easing.InOutQuad, game.Properties.FlyInDuration * 1000, 0.0, 1.0, sm)
end
function game.States.CombatFlyIn.Transitions.Combat.Evaluate(sm)
    return not sm.cameraAnimating
end

function game.States.CombatFlyIn.OnExit(sm)
    game.timer:Resume()
    Events:LuaEvent(Events.SetAnimationEnabled, game.Properties.Camera, true)
end

-------------------------------------------
--- Combat
-------------------------------------------
function game.States.Combat.OnEnter(sm)
    -- show combat UI
    Events:GlobalLuaEvent(Events.OnSetEnemyCardVisible, true)
    Events:GlobalLuaEvent(Events.OnSetPlayerCardsVisible, 1, true)

    local gridPosition = game.player1:DestinationGridPositionString()
    Events:LuaEvent(Events.OnEnterCombat, gridPosition)

    sm.inCombat = true
    sm.leaveCombatTime = 0

    sm.OnEnemyDefeated = function(_sm)
        Events:Disconnect(_sm, Events.OnEnemyDefeated)
        local x = game.player1.moveEnd.x
        local y = game.player1.moveEnd.y
        -- sanity check there is an enemy
        if game.grid[x][y].enemy then 
            game.grid[x][y].enemy = false
            game.currentEnemy = game.currentEnemy + 1
            game.totalEnemiesDefeated= game.totalEnemiesDefeated + 1
        end
        game.timer:Pause()
        local scriptTime = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
        _sm.leaveCombatTime = scriptTime:GetSeconds() + game.Properties.CombatEndingDuration
        _sm.inCombat = false
        game:Log(tostring(_sm.leaveCombatTime))
    end
    Events:Connect(sm, Events.OnEnemyDefeated)

    sm.OnRunAway = function(_sm)
        Events:Disconnect(_sm, Events.OnRunAway)
        local gridPosition = game.player1:DestinationGridPositionString()
        Events:LuaEvent(Events.OnExitCombat, gridPosition)
        game.player1:Move(game.player1.moveStart, true)
        _sm.inCombat = false
    end
    Events:Connect(sm, Events.OnRunAway)
end
function game.States.Combat.OnExit(sm)
    -- don't resume the timer until after fly-out
    Events:GlobalLuaEvent(Events.OnSetEnemyCardVisible, false)
    Events:GlobalLuaEvent(Events.OnSetPlayerCardsVisible, 1, false)
end
function game.States.Combat.Transitions.Lose.Evaluate(sm)
    return game.timer.timeLeft <= 0 
end
function game.States.Combat.Transitions.CombatFlyOut.Evaluate(sm)
    if game.timer.timeLeft > 0 and not sm.inCombat then
        local scriptTime = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
        return sm.leaveCombatTime < scriptTime:GetSeconds()
    else
        return false
    end
end

-------------------------------------------
--- CombatFlyOut
-------------------------------------------
function game.States.CombatFlyOut.OnEnter(sm)
    Events:LuaEvent(Events.SetAnimationEnabled, game.Properties.Camera, false)
    game.timer:Pause()
    local startPosition = TransformBus.Event.GetWorldTranslation(game.Properties.Camera)
    local endPosition = game.cameraTM:GetTranslation()
    local endLookAtPosition = endPosition + (game.cameraTM:GetBasisY() * 1000.0) 
    local startFOV = game.Properties.CameraCombatFOV
    local endFOV = game.cameraFOV

    sm.cameraAnimating = true
    sm.OnEasingUpdate = function(sm, jobId, value )
        game:CameraEasingUpdate(startPosition, endPosition, endLookAtPosition, startFOV, endFOV, value)
    end
    sm.OnEasingEnd = function(sm)
        sm.cameraAnimating = false
    end

	game.cameraEasingId = Easing:Ease(Easing.InOutQuad, game.Properties.FlyInDuration * 1000, 0.0, 1.0, sm)

end
function game.States.CombatFlyOut.Transitions.Win.Evaluate(sm)
    if sm.cameraAnimating then
        return false
    end

    local x = game.player1.moveEnd.x
    local y = game.player1.moveEnd.y
    if game.grid[x][y].boss then
        game:Log("Transitioning to Win after defeating boss")
    end
    return game.grid[x][y].boss or (game.totalEnemiesDefeated >= game.numEnemies)
end

function game.States.CombatFlyOut.Transitions.Navigation.Evaluate(sm)
    if sm.cameraAnimating then
        return false
    end

    local x = game.player1.moveEnd.x
    local y = game.player1.moveEnd.y
    return not game.grid[x][y].boss and (game.totalEnemiesDefeated < game.numEnemies)
end

function game.States.CombatFlyOut.OnExit(sm)
    game.timer:Resume()
    Events:LuaEvent(Events.SetAnimationEnabled, game.Properties.Camera, true)
    game.player1:SetVisible(true)
    local immediate = game.player1.moveStart == game.player1.moveEnd
    game.player1:Move(game.player1.moveEnd, immediate)
end

-------------------------------------------
--- Treasure
-------------------------------------------
function game.States.Treasure.OnEnter(sm)
    local gridPosition = game.player1:GridPositionString()
    game:Log("Treasure.OnEnter")

    sm.okPressed = false 
    sm.modalVisible = false

    -- HACK only wait for OK pressed if the canvas is shown
    sm.ShowUiCanvas = function(_sm, canvas)
        _sm.modalVisible = true
        game.timer:Pause()
        _sm.OnOKPressed = function(__sm)
            __sm.okPressed = true
        end
        Events:Connect(_sm, Events.OnOKPressed)
    end
    Events:Connect(sm, Events.ShowUiCanvas)
    Events:LuaEvent(Events.OnEnterTile, gridPosition)
end

function game.States.Treasure.OnExit(sm)
    Events:GlobalLuaEvent(Events.ShowUiCanvas, "None")
    Events:Disconnect(sm, Events.OnOKPressed)
    Events:Disconnect(sm, Events.ShowUiCanvas)
    game.timer:Resume()
end

function game.States.Treasure.Transitions.RevealTiles.Evaluate(sm)
    return sm.okPressed or not sm.modalVisible
end

-------------------------------------------
--- Lose
-------------------------------------------
function game.States.Lose.OnEnter(sm)
    game.timer:Pause()

    sm.OnRetryPressed = function(_sm)
        game:Log("OnRetryPressed")
        _sm:GotoState("LevelBuildOut")
        Events:Disconnect(_sm, Events.OnRetryPressed)
    end
    Events:Connect(sm, Events.OnRetryPressed)
    sm.OnQuitPressed = function(_sm)
        Events:Disconnect(_sm, Events.OnQuitPressed)
        ConsoleRequestBus.Broadcast.ExecuteConsoleCommand("quit")
    end
    Events:Connect(sm, Events.OnQuitPressed)

    sm.OnMenuPressed = function(_sm)
        game:Log("OnMenuPressed")
        _sm:GotoState("MainMenu")
        Events:Disconnect(_sm, Events.OnMenuPressed)
    end
    Events:Connect(sm, Events.OnMenuPressed)
end

function game.States.Lose.OnExit(sm)
    Events:LuaEvent(Events.SetAnimationEnabled, game.Properties.Camera, false)
    TransformBus.Event.SetWorldTM(game.Properties.Camera, game.cameraTM)
    CameraRequestBus.Event.SetFovDegrees(game.Properties.Camera, game.cameraFOV)
end

-------------------------------------------
--- Win
-------------------------------------------
function game.States.Win.OnEnter(sm)
    local timeLeft = game.timer:GetFormattedTimeLeft()
    game.timer:Pause()
    sm.OnRetryPressed = function(_sm)
        Events:Disconnect(_sm, "OnRetryPressed")
        _sm:GotoState("LevelBuildOut")
    end
    Events:Connect(sm, "OnRetryPressed")
    sm.OnQuitPressed = function(_sm)
        Events:Disconnect(_sm, "OnQuitPressed")
        ConsoleRequestBus.Broadcast.ExecuteConsoleCommand("quit")
    end
    Events:Connect(sm, "OnQuitPressed")

    sm.OnMenuPressed = function(_sm)
        Events:Disconnect(_sm, Events.OnMenuPressed)
        _sm:GotoState("MainMenu")
    end
    Events:Connect(sm, Events.OnMenuPressed)

    Utilities:ExecuteOnNextTick(sm, function()
        Events:GlobalLuaEvent(Events.OnUpdateTotalCardsCollected, game.totalCardsCollected)
        Events:GlobalLuaEvent(Events.OnUpdateTotalCoinsCollected, game.totalCoinsCollected)
        Events:GlobalLuaEvent(Events.OnUpdateTotalEnemiesDefeated, game.totalEnemiesDefeated)
        Events:GlobalLuaEvent(Events.OnUpdateTotalTimeLeft, timeLeft)
    end)
end

function game.States.Win.OnExit(sm)
    Events:LuaEvent(Events.SetAnimationEnabled, game.Properties.Camera, false)
    TransformBus.Event.SetWorldTM(game.Properties.Camera, game.cameraTM)
    CameraRequestBus.Event.SetFovDegrees(game.Properties.Camera, game.cameraFOV)
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
    self.timer = Timer(self.Properties.TimeLimit)
    self.player1 = {}
    self.tiles = {}
    self.numEnemies = 0

    self.tagListener = TagGlobalNotificationBus.Connect(self, Crc32("Tile"))
    Events:Connect(self, Events.GetTile)
    Events:Connect(self, Events.ModifyCoinAmount)
    Events:Connect(self, Events.AddCards)

    local time = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
    math.randomseed(math.ceil(time:GetSeconds()))

    Events.DebugEvents = self.Properties.DebugEvents

    self.stateMachine = {}
    setmetatable(self.stateMachine, StateMachine)

    while UiCursorBus.Broadcast.IsUiCursorVisible() == false do
        UiCursorBus.Broadcast.IncrementVisibleCounter()
    end

    UiCursorBus.Broadcast.SetUiCursor("ui/cursor.png")

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

function game:TestSaveAndLoad()
    -- NOTE This will NOT work in editor unless you add a Tools alias to the 
    -- GameState Gem's cmakelist.txt
    -- By default the gem is not loaded in editor
    local levelTile = LevelTile()
    levelTile.position = Vector3(2,3,4)
    levelTile.type = "UnknownType"
    local tiles = vector_LevelTile()
    tiles:PushBack(levelTile)

    local level = LevelData()
    level.name = "TestLevelName"
    level.tiles = tiles

    GameRequestBus.Broadcast.SaveLevel("TestLevel", level)

    game.OnLevelLoaded = function(_sm, levelData)
        game:Log("$5 OnLevelLoaded ")
        if levelData ~= nil then
            game:Log("LevelData.name " .. tostring(levelData.name))
            if levelData.tiles ~= nil then
                local tile = levelData.tiles[1]
                game:Log("LevelData.tiles[1] " .. tostring(tile.type))
            end
        end
    end
    GameNotificationBus.Connect(game)
    GameRequestBus.Broadcast.LoadLevel("TestLevel")
end

function game:ModifyCoinAmount(amount)
    self.totalCoinsCollected = self.totalCoinsCollected + amount
end

function game:AddCards(cards)
    self.totalCardsCollected = self.totalCardsCollected + #cards 
end


function game:OnEntityTagAdded(entityId)
    table.insert(self.tiles, entityId)
end

function game:OnEntityTagRemoved(entityId)
    table.remove(self.tiles, entityId)
end

function game.InputEvents.MouseLeftClick:OnPressed(value)
    -- TODO move player to selected tile
end

function game.InputEvents.Esc:OnPressed(value)
    game:Log("Esc:OnPressed")
    -- HACK just support pausing in navigation and combat
    local state = game.stateMachine.CurrentStateName
    if not game.paused and (state == "Navigation" or state == "Combat") then
        game:Log("$6 Pausing")
        game.paused = true
        game.timer:Pause()

        self.OnResumePressed = function(_self)
            game:Log("$6 Resuming")
            game.paused = false
            game.timer:Resume()
            Events:GlobalLuaEvent(Events.OnPauseChanged, "Unpaused")
        end

        self.OnMenuPressed = function(_self)
            Events:LuaEvent(Events.SetAnimationEnabled, game.Properties.Camera, false)
            TransformBus.Event.SetWorldTM(game.Properties.Camera, game.cameraTM)
            CameraRequestBus.Event.SetFovDegrees(game.Properties.Camera, game.cameraFOV)
            game.paused = false
            game:Log("Going to main menu")
            game.stateMachine:GotoState("MainMenu")
            Events:GlobalLuaEvent(Events.OnPauseChanged, "Unpaused")
        end

        self.OnQuitPressed = function(_self)
            ConsoleRequestBus.Broadcast.ExecuteConsoleCommand("quit")
        end
        Events:Connect(self, Events.OnResumePressed)
        Events:Connect(self, Events.OnMenuPressed)
        Events:Connect(self, Events.OnQuitPressed)

        Events:GlobalLuaEvent(Events.OnPauseChanged, "Paused")
    end
end

function game:GetTile(gridPosition)
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
            local isTreasure = TagComponentRequestBus.Event.HasTag(entityId, Crc32("Treasure"))

            self.grid[x][y] = {
                enemy = hasEnemy,
                boss = isBoss,
                miniBoss = isMiniBoss,
                walkable = isWalkable,
                treasure = isTreasure,
                revealed = false
            }

            if hasEnemy then
                self.numEnemies = self.numEnemies + 1
                local enemyCard = {
                    Name = 'Enemy',
                    Weaknesses = {}
                }
                if isBoss then
                    enemyCard.Name = 'Boss'
                elseif isMiniBoss then
                    enemyCard.Name = 'MiniBoss'
                else
                end
                self.grid[x][y].enemyCard = enemyCard
            end
        end
    end
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

    self.timer:Stop()

    self.spawnableMediator:Despawn(self.spawnTicket)
    self.stateMachine:Stop()
    self:UnBindInputEvents(self.InputEvents)
    while UiCursorBus.Broadcast.IsUiCursorVisible() == true do
        UiCursorBus.Broadcast.DecrementVisibleCounter()
    end
    Events:ClearAll()
end

return game