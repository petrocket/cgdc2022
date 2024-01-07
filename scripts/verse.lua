local Utilities = require "scripts.utilities"
local Verse = {
    reference = 'Unknown',
    text = 'Unknown',
    topics =  {}
}

local VerseDatabase = {
    {"John 13:34-35","Love,Humility","A new command I give you: Love one another.| As I have loved you, so you must love one another.| By this everyone will know that you are my disciples,| if you love one another."},
    {"1 John 3:18","Love","Dear children, let us not love with| words or speech but with| actions and in truth."},
    {"Philippians 2:3-4","Humility,Purity","Do nothing out of selfish ambition or vain conceit.| Rather, in humility value others above yourselves,| not looking to your own interests but each of you to| the interests of the others."},
    {"1 Peter 5:5-6","Humility",'In the same way, you who are younger, submit yourselves| to your elders. All of you, clothe yourselves with humility| toward one another, because, "God opposes the proud but shows| favor to the humble." Humble yourselves, therefore,| under God’s mighty hand, that he may lift you up in due time.'},
    {"Ephesians 5:3","Purity,Faith","But among you there must not| be even a hint of sexual immorality, or of any kind of| impurity, or of greed, because| these are improper for God's holy people."},
    {"1 Peter 2:11","Purity",' Dear friends, I urge you, as foreigners and exiles,| to abstain from sinful desires, which wage war against your soul.'},
    {"Leviticus 19:11","Honesty,GoodWorks",'Do not steal.| Do not lie.| Do not deceive one another.'},
    {"Acts 24:16","Honesty",'So I strive always to| keep my conscience clear before| God and man.'},
    {"Hebrews 11:6","Faith,GoodWorks",'And without faith it is impossible to please God,| because anyone who comes to him must believe that he exists| and that he rewards those who earnestly seek him.'},
    {"Romans 4:20-21","Faith,Purity,Humility",'Yet he did not waver through unbelief regarding| the promise of God, but was strengthened in his faith| and gave glory to God, being fully persuaded that God| had power to do what he had promised.'},
    {"Galations 6:9-10","GoodWorks,Faith",'Let us not become weary in doing good,| for at the proper time we will reap a harvest if we| do not give up. Therefore, as we have opportunity, let us| do good to all people, especially to those who| belong to the family of believers.'},
    {"Matthew 5:16","GoodWorks,Honesty",'In the same way, let your light shine before others,| that they may see your good deeds and| glorify your Father in heaven.'},
}

Verse.__index = Verse
setmetatable(Verse, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})
function Verse.new (reference, text, topics)
	local self = setmetatable({}, Verse)
    self.topics = topics
    self.reference = reference
    self.text = text
    self.length = string.len(self.text)
	return self
end

function Verse:GetSections(numSections)
    if numSections == nil then
        return Utilities:Split(self.text, "|")
    end

    -- split the verse into numSections and return the sections
    local startIndex = 1
    local endIndex = self.length
    local sectionLength = math.floor(self.length / numSections)
    local sections = {}
    Debug.Log("getting " .. tostring(numSections).. " sections of verse: " .. self.text)
    for i=1,numSections do
        endIndex, _ = string.find(self.text,"%s",(sectionLength * i))
        Debug.Log("found space char at index " .. tostring(endIndex))
        Debug.Log("inserting section " .. tostring(i) .. ": " .. string.sub(self.text, startIndex, endIndex))
        table.insert(sections, string.sub(self.text, startIndex, endIndex))
        startIndex = endIndex + 1
    end
    return sections
end

function Verse:GetAllVerses()
    local verses = {}

    for _, verse in ipairs(VerseDatabase) do
        local topics = {}
        for str in string.gmatch(verse[2], "([^,]+)") do
            topics[str] = 1
        end
        table.insert(verses, Verse(verse[1], verse[3], topics))
    end

    return verses
end

return Verse