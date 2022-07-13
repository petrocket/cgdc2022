local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local Card = require "scripts.card"

local Treasure = {
    Properties = {
        Debug = false,
        Mesh = EntityId(),
        CoinAmount = {
            Min = 3,
            Max = 10 
        },
        CardAmount = {
            Min = 3,
            Max = 5
        }
    }
}

function Treasure:OnActivate()
    Utilities:InitLogging(self, "Treasure")

    local translation = TransformBus.Event.GetWorldTranslation(self.entityId)
    local gridPosition = tostring(math.floor(translation.x)) .. "_" .. tostring(math.floor(translation.y))
    Events:Connect(self, Events.OnEnterTile, gridPosition)
    Events:Connect(self, Events.OnRevealTile, gridPosition)
    Events:Connect(self, Events.OnStateChange)
    self.treasureCollected = false
end

function Treasure:Reset()
    RenderMeshComponentRequestBus.Event.SetVisibility(self.Properties.Mesh, false)
    self.treasureCollected = false
end

function Treasure:OnStateChange(newState)
    if newState == 'LevelBuildOut' then
        self:Reset()
    end
end

function Treasure:OnEnterTile()
    if not self.treasureCollected then
        self.treasureCollected = true
        -- hide the chest 
        RenderMeshComponentRequestBus.Event.SetVisibility(self.Properties.Mesh, false)

        -- give the player loot
        local coinAmount = math.random(self.Properties.CoinAmount.Min, self.Properties.CoinAmount.Max)
        self:Log("Giving " .. tostring(coinAmount) .. " coins")
        Events:GlobalLuaEvent(Events.ModifyCoinAmount, coinAmount)

        local cardAmount = math.random(self.Properties.CardAmount.Min, self.Properties.CardAmount.Max)

        self:Log("Giving " .. tostring(cardAmount) .. " cards")
        local cards = {
            Card(Card.Types.Special.Bomb),
            Card(Card.Types.Special.DoubleArrow),
            Card(Card.Types.Special.DoubleSword)
        }

        Utilities:Shuffle(cards)

        -- always give at least 1 special card
        local specialCard =  table.remove(cards)
        Events:GlobalLuaEvent(Events.AddCards, {specialCard})

        -- add 4 of each common card
        for _,cardType in pairs(Card.Types.Common) do
            for i=1,4 do
                table.insert(cards, Card(cardType))
            end
        end

        Utilities:Shuffle(cards)
        for i=1,cardAmount-1 do
            if #cards <= 0 then
                break
            end

            local card = table.remove(cards)
            Events:GlobalLuaEvent(Events.AddCards, {card})
        end
    end
end

function Treasure:OnRevealTile()
    local visible = RenderMeshComponentRequestBus.Event.GetVisibility(self.Properties.Mesh)
    if not visible and not self.treasureCollected then
        RenderMeshComponentRequestBus.Event.SetVisibility(self.Properties.Mesh, true)
    end
end

function Treasure:OnDeactivate()
    local translation = TransformBus.Event.GetWorldTranslation(self.entityId)
    local gridPosition = tostring(math.floor(translation.x)) .. "_" .. tostring(math.floor(translation.y))
    Events:Disconnect(self, Events.OnRevealTile, gridPosition)
    Events:Disconnect(self, Events.OnStateChange)
end

return Treasure