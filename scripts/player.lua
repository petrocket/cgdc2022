local Events = require "scripts.events"
local Utilities = require "scripts.utilities"

local Player = {
    Properties = {
        Id = 1,
        Debug = true,
        MoveSpeed = 2.0,
        Health = 100,
        Mesh = EntityId()
    },
    cards = {
        max_active = 4,
        active = {},
        deck = {},
        discards = {}
    },
    InputEvents = {
        Player1Action0 = {},
        Player1Action1 = {},
        Player1Action2 = {},
        Player1Action3 = {},
        Player1Action4 = {},
        Player1Action5 = {},
        Player1UpDown = {},
        Player1LeftRight = {},
        MouseLeftClick = {},
        MouseMove = {}
    },
    health = 100,
    moving = false,
    moveAmount = 0,
    moveStartTime = 0,
    moveStart = Vector3(0,0,0),
    moveEnd = Vector3(0,0,0),
    movement = Vector2(0,0),
    Modes = {
        Combat = "Combat",
        VerseChallenge = "VerseChallenge",
        Navigation = "Navigation",
        Inactive = "Inactive"
    },
}

function Player:OnActivate ()
	--local self = setmetatable({}, Player)
    self.name = "Player"..tostring(math.floor(self.Properties.Id))
    Utilities:InitLogging(self, self.name)
    self:BindInputEvents(self.InputEvents)
    self:Log("OnActivate 2")

    --Events.DebugEvents = false
    Events:Connect(self, Events.GetPlayer, math.floor(self.Properties.Id))

    self.mode = Player.Modes.Inactive
    self.gridPosition = { x=0,y=0 }

    -- might need to persist coins later
    self.coins = 0

    Events:Connect(self, Events.OnStateChange)
    Events:Connect(self, Events.OnUseCard)
    Events:Connect(self, Events.OnVerseChallengeComplete)
    Events:Connect(self, Events.OnDiscard)
    Events:Connect(self, Events.ModifyCoinAmount)
    Events:Connect(self, Events.AddCards)
    Events:Connect(self, Events.OnPauseChanged)
end

function Player:OnPauseChanged(value)
    if value == "Paused" then
        self.previousMode = self.mode
        self.mode= self.Modes.Inactive
    elseif self.previousMode ~= nil then
        self.mode = self.previousMode
    end
end

function Player:AddCards(cards)
    for _,card in pairs(cards) do
        self:Log("Adding card " .. tostring(card.type))
        table.insert(self.cards.deck, card)
    end

    self:NotifyCardAmount()
end

function Player:SetCoinAmount(amount)
    self.coins = amount
    Events:GlobalLuaEvent(Events.OnUpdateCoinsAmount, self.coins)
end

function Player:ModifyCoinAmount(amount)
    self:SetCoinAmount(self.coins + amount)
end

function Player:OnStateChange(newState)
    self.moveAmount = 0
    if newState ~= 'Navigation' then
        self.moving = false
    end

    if newState == 'Navigation' then
        self.mode = self.Modes.Navigation
    elseif newState == 'Combat' then
        self.mode = self.Modes.Combat
    else
        self.mode = self.Modes.Inactive
    end

end

function Player:GridPosition()
    return self.gridPosition
end

function Player:GridPositionString()
    return tostring(self.gridPosition.x) .. "_" .. tostring(self.gridPosition.y)
end

function Player:DestinationGridPositionString()
    return tostring(math.ceil(self.moveEnd.x)) .. "_" .. tostring(math.ceil(self.moveEnd.y))
end

function Player:GetPlayer()
    self:Log("GetPlayer and self is " ..tostring(self))
    return self
end

function Player:Move(position, immediately)
    if not immediately then
        self.moving = true
        local scriptTime = TickRequestBus.Broadcast.GetTimeAtCurrentTick()
        self.moveStartTime = scriptTime:GetSeconds()
    end

    self.moveEnd = position 
    self.moveStart = TransformBus.Event.GetWorldTranslation(self.entityId)
    self.gridPosition.x = math.ceil(self.moveEnd.x)
    self.gridPosition.y = math.ceil(self.moveEnd.y)

    if immediately then
        TransformBus.Event.SetWorldTranslation(self.entityId, position)
        self.moveAmount = 1.0
    end
end

function Player:SetCards(cards, max_active)
    self:Log("Giving player " .. tostring(#cards) .. " cards")
    self.cards.max_active = max_active
    self.cards.deck = cards
    self.cards.active = {}
    self.cards.discards = {}

    -- draw the active number of cards from the deck
    for cardIndex=1,self.cards.max_active do
        local card = table.remove(self.cards.deck)
        self.cards.active[cardIndex] = card
        Events:LuaEvent(Events.OnSetPlayerCard, self.name, cardIndex, card)
    end
    self:NotifyCardAmount()
end

function Player:UseCard(cardIndex)
    if self.mode ~= Player.Modes.Combat then
        return
    end

    local card = self.cards.active[cardIndex]
    if card ~= nil then
        -- check if the enemy has this weakness
        local canUseOnEnemy = Events:GlobalLuaEventResult(Events.CanUseCardOnEnemy, card)
        if canUseOnEnemy == true then
            self:Log("UseCard " ..tostring(card.verse.reference))
            Events:GlobalLuaEvent(Events.OnSetVerseChallengeVisible, true)
            Events:GlobalLuaEvent(Events.OnStartVerseChallenge, card)
            self.mode = Player.Modes.VerseChallenge
        else
            self:Log("UseCard cannot use " ..tostring(card.verse.reference) .. "("..tostring(cardIndex)..") on enemy")
        end
    end
end

function Player:NotifyCardAmount()
    local numCards = #self.cards.deck
    for i=1,#self.cards.active do
        if self.cards.active[i] ~= nil then
            numCards = numCards + 1
        end
    end
    Events:GlobalLuaEvent(Events.OnUpdateCardDeckAmount, #self.cards.deck)
    Events:GlobalLuaEvent(Events.OnUpdateCardDiscardsAmount, #self.cards.discards)
    Events:GlobalLuaEvent(Events.OnUpdateCardsAmount,numCards)
end

function Player:DiscardAll()
    if self.mode ~= Player.Modes.Combat then
        return
    end

    self:Log("$7 Discarding 4 cards with " ..tostring(#self.cards.deck) .. " cards remaining in deck")
    for cardIndex=1,self.cards.max_active do

        Events:LuaEvent(Events.OnCardDiscarded, self.name, cardIndex)
        if self.cards.active[cardIndex] ~= nil then
            table.insert(self.cards.discards, self.cards.active[cardIndex])
        end

        local card = nil
        if #self.cards.deck > 0 then
            card = table.remove(self.cards.deck)
        end 
        self.cards.active[cardIndex] = card
        Events:LuaEvent(Events.OnSetPlayerCard, self.name, cardIndex, card)
    end

    self:ReUseDiscardPileIfNoActiveCards()

    self:NotifyCardAmount()
end

function Player:ReUseDiscardPileIfNoActiveCards()
    if #self.cards.active == 0 then
        local cards = self.cards.discards
        Utilities:Shuffle(cards)
        self:SetCards(cards, self.cards.max_active)
    end
end

function Player:Update(deltaTime, scriptTime)
    if self.mode ~= Player.Modes.Navigation then
        return
    end

    if self.moving then
        local moveAmount = scriptTime:GetSeconds() - self.moveStartTime
        moveAmount = math.min(1.0,  moveAmount / (1.0 / self.Properties.MoveSpeed)) 
        local translation = self.moveStart:Lerp(self.moveEnd, moveAmount)
        TransformBus.Event.SetWorldTranslation(self.entityId, translation)
        self.moveAmount = moveAmount
    elseif self.movement:GetLengthSq() > 0 then
        self.moveStart = TransformBus.Event.GetWorldTranslation(self.entityId)
        if self.movement.x ~= 0 then
            if self.movement.x > 0 then
                self.movement.x = 1
            else
                self.movement.x = -1
            end
            self.moveEnd = self.moveStart + Vector3(self.movement.x, 0, 0)
        else
            if self.movement.y > 0 then
                self.movement.y = 1
            else
                self.movement.y = -1
            end
            self.moveEnd = self.moveStart + Vector3(0, self.movement.y, 0)
        end

        self:Log(tostring(self.movement.x) .. " " .. tostring(self.movement.y))

        if self.Properties.Mesh then
            local offset = TransformBus.Event.GetLocalTranslation(self.Properties.Mesh)
            self.meshTM = Transform.CreateLookAt(self.moveStart + offset, self.moveEnd + offset, AxisType.YPositive)
            TransformBus.Event.SetWorldTM(self.Properties.Mesh, self.meshTM)
        end

        local tile = Events:GlobalLuaEvent(Events.GetTile, Vector2(self.moveEnd.x, self.moveEnd.y))
        if tile.walkable and not tile.enemy then
            --self:Log("$3 player movement")
            self.moving = true
            self.moveStartTime = scriptTime:GetSeconds()
            self.gridPosition.x = math.ceil(self.moveEnd.x)
            self.gridPosition.y = math.ceil(self.moveEnd.y)
        end
        self.movement = Vector2(0,0)
    end
end

function Player:SetVisible(visible)
    RenderMeshComponentRequestBus.Event.SetVisibility(self.Properties.Mesh, visible)
    ActorComponentRequestBus.Event.SetRenderCharacter(self.Properties.Mesh, visible)
end

function Player:OnDiscard(value)
    self:DiscardAll()
end

function Player:OnUseCard(value)
    self:UseCard(math.floor(value))
end

function Player:OnVerseChallengeComplete(card)
    -- damage the enemy
    Events:GlobalLuaEvent(Events.OnTakeDamage, card)

    -- we are no longer in the verse challenge
    self.mode = Player.Modes.Combat

    -- find this card
    local cardIndex = 0 
    for i=1,#self.cards.active do
        if self.cards.active[i] ~= nil and self.cards.active[i].verse.reference == card.verse.reference then
            cardIndex = i
            break
        end
    end

    if cardIndex > 0 then
        Events:LuaEvent(Events.OnCardUsed, self.name, cardIndex)
        self:Log("Getting new card")
        if #self.cards.deck > 0 then
            card = table.remove(self.cards.deck)
        else
            self:Log("Draw deck empty")
            card = nil
        end
        self.cards.active[cardIndex] = card
        Events:LuaEvent(Events.OnSetPlayerCard, self.name, cardIndex, card)
    end

    Events:GlobalLuaEvent(Events.OnSetVerseChallengeVisible, false)

    self:ReUseDiscardPileIfNoActiveCards()

    self:NotifyCardAmount()
end

function Player.InputEvents.Player1Action0:OnPressed(value)
    self.Component:Log("Player1Action0")
    if self.Component.mode == Player.Modes.Combat or self.Component.mode == Player.Modes.VerseChallenge then
        Events:LuaEvent(Events.OnRunAway)
    end
end
function Player.InputEvents.Player1Action1:OnPressed(value)
    if self.Component.mode == Player.Modes.VerseChallenge then
        self.Component:Log("OnSelectFragment 1")
        Events:GlobalLuaEvent(Events.OnSelectFragment, 1)
    else
        self.Component:UseCard(1)
    end
end
function Player.InputEvents.Player1Action2:OnPressed(value)
    if self.Component.mode == Player.Modes.VerseChallenge then
        self.Component:Log("OnSelectFragment 2")
        Events:GlobalLuaEvent(Events.OnSelectFragment, 2)
    else
        self.Component:UseCard(2)
    end
end
function Player.InputEvents.Player1Action3:OnPressed(value)
    if self.Component.mode == Player.Modes.VerseChallenge then
        self.Component:Log("OnSelectFragment 3")
        Events:GlobalLuaEvent(Events.OnSelectFragment, 3)
    else
        self.Component:UseCard(3)
    end
end
function Player.InputEvents.Player1Action4:OnPressed(value)
    if self.Component.mode == Player.Modes.VerseChallenge then
        self.Component:Log("OnSelectFragment 4")
        Events:GlobalLuaEvent(Events.OnSelectFragment, 4)
    else
        self.Component:UseCard(4)
    end
end
function Player.InputEvents.Player1Action5:OnPressed(value)
    if self.Component.mode == Player.Modes.Combat or self.Component.mode == Player.Modes.VerseChallenge then
        self.Component:DiscardAll()
    end
end

function Player.InputEvents.Player1UpDown:OnPressed(value)
    self.Component.movement.y = value
end
function Player.InputEvents.Player1UpDown:OnHeld(value)
    self.Component.movement.y = value
end
function Player.InputEvents.Player1UpDown:OnReleased(value)
    self.Component.movement.y = 0
end
function Player.InputEvents.Player1LeftRight:OnPressed(value)
    self.Component.movement.x = value
end
function Player.InputEvents.Player1LeftRight:OnHeld(value)
    self.Component.movement.x = value
end
function Player.InputEvents.Player1LeftRight:OnReleased(value)
    self.Component.movement.x = 0
end

function RayPlaneIntersection(rayPosition, rayDirection, planePosition, planeNormal)
    local denom = planeNormal:Dot(rayDirection)
    if math.abs( denom ) < 0.001 then
        return false
    end

	-- distance of direction
	local d = planePosition - rayPosition
	local t = d:Dot(planeNormal) / denom

	if t < 0.001 then
		return false
	end

	-- Return collision point 
	return rayPosition + rayDirection * t
end

function Player.InputEvents.MouseLeftClick:OnPressed(value)
    local camera = Events:GlobalLuaEvent(Events.GetCamera)

    -- get mouse position
    --self.Component.movement.x = value
    local cursorPos = UiCursorBus.Broadcast.GetUiCursorPosition()
    if cursorPos ~= nil and camera ~= nil then
        local startPos = CameraRequestBus.Event.ScreenToWorld(camera, cursorPos, 0)
        local endPos = CameraRequestBus.Event.ScreenToWorld(camera, cursorPos, 1)

        -- ray/plane intersection
        local direction = (endPos - startPos):GetNormalized()
        local hit = RayPlaneIntersection(startPos, direction, Vector3(0,0,0), Vector3(0,0,1))

        if hit then
            local tile = Events:GlobalLuaEvent(Events.GetTile, Vector2(hit.x, hit.y))
            if tile.walkable then
                --self.Component:Log("tile pos " ..tostring(tile.pos))
                local delta = tile.pos - Vector2(self.Component.gridPosition.x, self.Component.gridPosition.y)
                self.Component:Log("delta " ..tostring(delta))
                -- don't allow diagonal movement
                if (math.abs(delta.x) == 1 and delta.y == 0) or (math.abs(delta.y) == 1 and delta.x == 0) then
                    self.Component.movement.x = delta.x
                    self.Component.movement.y = delta.y
                end
            --else
                --self.Component:Log("no tile hit")
            end
        end
        --self.Component:Log(tostring(hit))
    end
end

function Player.InputEvents.MouseMove:OnHeld(value)
    -- get mouse position
    --self.Component:Log(value)
end

function Player:BindInputEvents(events)
	for event, handler in pairs(events) do
		handler.Component = self
		handler.Listener = InputEventNotificationBus.Connect(handler, InputEventNotificationId(event))
	end
end

function Player:UnBindInputEvents(events)
	for event, handler in pairs(events) do
        if handler ~= nil and handler.Listener ~= nil then
            handler.Listener:Disconnect()
            handler.Listener = nil
        end
	end
end

function Player:OnDeactivate()
    self:Log("OnDeactivate")
    self:UnBindInputEvents(self.InputEvents)
    Events:Disconnect(self, Events.GetPlayer, math.floor(self.Properties.Id))
    Events:Disconnect(self, Events.OnUseCard)
    Events:Disconnect(self, Events.OnDiscard)
    Events:Disconnect(self, Events.ModifyCoinAmount)
end

return Player