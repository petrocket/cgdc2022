local TopicColors = require "scripts.topicscolors"

local Card = {
    type = 0,
    color = Color(0.0,0.0,0.0,0.0),
    name = 'Card',
    verse = {}
}
Card.__index = Card
setmetatable(Card, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})
function Card.new (verse)
	local self = setmetatable({}, Card)
	self.verse = verse
    if verse ~= nil and verse.topics ~= nil then
        for topic, amount in pairs(verse.topics) do
            if TopicColors[topic] ~= nil then
                self.color =  TopicColors[topic]
            end
            break
        end
    else
        -- just use a grey color till we know what to do
        self.color = TopicColors.Unknown
    end
	return self
end

function Card:GetWeaknessesForCard(type)
    if Card.Weaknesses[type] ~= nil then
        return Card.Weaknesses[type]
    else
        -- TODO special card
        return { EnemyType1=1 }
    end
end

return Card