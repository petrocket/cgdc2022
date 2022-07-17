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
        Player1LeftRight = {}
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
        Navigation = "Navigation",
        Inactive = "Inactive"
    },
}

function Player:OnActivate ()
	--local self = setmetatable({}, Player)
    self.name = "Player"..tostring(math.floor(self.Properties.Id))
    Utilities:InitLogging(self, self.name)
    self:BindInputEvents(self.InputEvents)

    Events:Connect(self, Events.GetPlayer, math.floor(self.Properties.Id))

    self.mode = Player.Modes.Inactive
    self.gridPosition = { x=0,y=0 }

    -- might need to persist coins later
    self.coins = 0

    Events:Connect(self, Events.OnStateChange)
    Events:Connect(self, Events.OnUseCard)
    Events:Connect(self, Events.OnDiscard)
    Events:Connect(self, Events.ModifyCoinAmount)
    Events:Connect(self, Events.AddCards)
    Events:Connect(self, Events.OnPauseChanged)
    --return self
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

    local damageTaken = false
    local card = self.cards.active[cardIndex]
    if card ~= nil then
        self:Log("UseCard " ..tostring(card.type))
        damageTaken = Events:GlobalLuaEvent(Events.OnTakeDamage, card.type, 1)
    end

    if damageTaken then
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
    self:NotifyCardAmount()
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

    self:NotifyCardAmount()
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
            self.moveEnd = self.moveStart + Vector3(math.ceil(self.movement.x), 0, 0)
        else
            self.moveEnd = self.moveStart + Vector3(0, math.ceil(self.movement.y), 0)
        end

        if self.Properties.Mesh then
            local offset = TransformBus.Event.GetLocalTranslation(self.Properties.Mesh)
            self.meshTM = Transform.CreateLookAt(self.moveStart + offset, self.moveEnd + offset, AxisType.YPositive)
            TransformBus.Event.SetWorldTM(self.Properties.Mesh, self.meshTM)
        end

        local tile = Events:GlobalLuaEvent(Events.GetTile, Vector2(self.moveEnd.x, self.moveEnd.y))
        if tile.walkable and not tile.enemy then
            self:Log("$3 player movement")
            self.moving = true
            self.moveStartTime = scriptTime:GetSeconds()
            self.gridPosition.x = math.ceil(self.moveEnd.x)
            self.gridPosition.y = math.ceil(self.moveEnd.y)
        end
    end
end

function Player:SetVisible(visible)
    RenderMeshComponentRequestBus.Event.SetVisibility(self.Properties.Mesh, visible)
end

function Player:OnDiscard(value)
    self:DiscardAll()
end

function Player:OnUseCard(value)
    self:UseCard(math.floor(value))
end

function Player.InputEvents.Player1Action0:OnPressed(value)
    self.Component:Log("Player1Action0")
    if self.Component.mode == Player.Modes.Combat then
        Events:LuaEvent(Events.OnRunAway)
    end
end
function Player.InputEvents.Player1Action1:OnPressed(value)
    self.Component:UseCard(1)
end
function Player.InputEvents.Player1Action2:OnPressed(value)
    self.Component:UseCard(2)
end
function Player.InputEvents.Player1Action3:OnPressed(value)
    self.Component:UseCard(3)
end
function Player.InputEvents.Player1Action4:OnPressed(value)
    self.Component:UseCard(4)
end
function Player.InputEvents.Player1Action5:OnPressed(value)
    self.Component:DiscardAll()
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
    self:UnBindInputEvents(self.InputEvents)
    Events:Disconnect(self, Events.GetPlayer, math.floor(self.Properties.Id))
    Events:Disconnect(self, Events.OnUseCard)
    Events:Disconnect(self, Events.OnDiscard)
    Events:Disconnect(self, Events.ModifyCoinAmount)
end

return Player