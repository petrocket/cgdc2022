local Events = require "scripts.events"
local Utilities = require "scripts.utilities"

local Player = {
    Properties = {
        Id = 1,
        Debug = true,
        MoveSpeed = 2.0,
        Health = 100
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

--Player.__index = Player 
--setmetatable(Player, {
--  __call = function (class, ...) return class.new(...) end
--})

function Player:SetInputMode(mode)
    self.mode = mode
end

--function Player.new (self, id)
function Player:OnActivate ()
	--local self = setmetatable({}, Player)
    self.name = "Player"..tostring(math.floor(self.Properties.Id))
    Utilities:InitLogging(self, self.name)
    self:BindInputEvents(self.InputEvents)
    self:Log("OnActivate")

    Events:Connect(self, Events.GetPlayer, math.floor(self.Properties.Id))

    self.mode = Player.Modes.Inactive

    Events:Connect(self, Events.OnStateChange)
    --return self
end

function Player:OnStateChange(newState)
    self.moveAmount = 0
    self.moving = false

    if newState == 'Navigation' then
        self.mode = self.Modes.Navigation
    elseif newState == 'Combat' then
        self.mode = self.Modes.Combat
    else
        self.mode = self.Modes.Inactive
    end
end

function Player:GetPlayer()
    self:Log("Returning self ")
    return self
end

function Player:Test(message)
    self:Log("Received message " .. message)
end

function Player:SetCards(cards, max_active)
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
end

function Player:UseCard(cardIndex)
    if self.mode ~= Player.Modes.Combat then
        return
    end

    local damageTaken = false
    local card = self.cards.active[cardIndex]
    if card ~= nil then
        self:Log("UseCard " ..tostring(card.Name))
        damageTaken = Events:GlobalLuaEvent(Events.OnTakeDamage, card.Weakness, 1)
    end

    if damageTaken then
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
end

function Player:DiscardAll()
    if self.mode ~= Player.Modes.Combat then
        return
    end

    self:Log("$7 Discarding 4 cards with " ..tostring(#self.cards.deck) .. " cards remaining in deck")
    for cardIndex=1,self.cards.max_active do
        local card = nil
        if #self.cards.deck > 0 then
            card = table.remove(self.cards.deck)
        end 
        self.cards.active[cardIndex] = card
        Events:LuaEvent(Events.OnSetPlayerCard, self.name, cardIndex, card)
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
            self.moveEnd = self.moveStart + Vector3(math.ceil(self.movement.x), 0, 0)
        else
            self.moveEnd = self.moveStart + Vector3(0, math.ceil(self.movement.y), 0)
        end

        local tile = Events:GlobalLuaEvent(Events.GetTile, Vector2(self.moveEnd.x, self.moveEnd.y))
        if tile.walkable then
            self:Log("$3 player movement")
            self.moving = true
            self.moveStartTime = scriptTime:GetSeconds()
        end
    end
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
end

return Player