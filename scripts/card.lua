local Card = {
    type = 0,
    color = Color(0.0,0.0,0.0),
    name = 'Card',
    Types = {
        Common = {
            Arrow = "Arrow",
            Sword = "Sword",
            Shield = "Shield",
            Scroll = "Scroll"
        },
        Special = {
            DoubleArrow = "DoubleArrow",
            DoubleSword = "DoubleSword",
            Bomb = "Bomb"
        }
    },
    Colors = {
        Arrow = Color(0, 172.0/255.0,34.0 / 255.0,1.0),
        DoubleArrow = Color(0, 172.0/255.0,34.0 / 255.0,1.0),
        Sword = Color(255.0 / 255.0, 0.0,0.0,1.0),
        DoubleSword = Color(255.0 / 255.0, 0.0,0.0,1.0),
        Shield = Color(0,150.0 / 255.0,210.0 / 255.0,1.0),
        Scroll = Color(217.0/ 255.0, 207.0 / 255.0,20.0 / 255.0,1.0),
        Bomb =  Color(0.0/ 255.0,0.0 / 255.0,0.0 / 255.0,1.0)
    },
    Weaknesses = {
        Sword = { Sword=1 },
        Arrow = { Arrow=1 },
        Shield = { Shield=1 },
        Scroll = { Scroll=1 },
        Bomb = { Sword=1,Arrow=1,Shield=1,Scroll=1 },
        DoubleSword = { Sword=2 },
        DoubleArrow = { Arrow=2 }
    }
}
Card.__index = Card
setmetatable(Card, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})
function Card.new (type)
	local self = setmetatable({}, Card)
	self.type = type
    self.color = Card.Colors[self.type]
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