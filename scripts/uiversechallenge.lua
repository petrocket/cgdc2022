local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local Easing = require "scripts.easing"

local UiVerseChallenge = {
    Properties = {
        Debug = false
    }
}
function UiVerseChallenge:OnActivate()
    Utilities:InitLogging(self, "UiVerseChallenge")
    Events:Connect(self, Events.OnStartVerseChallenge)
    self.currentSection = 1
    self.verseSections = {}
    self.maxSectionLength = 60
    self.correctFragmentIndex = -1

    Events:Connect(self, Events.OnSelectFragment)
end

function UiVerseChallenge:HideAllChildren(parent)
    local children = UiElementBus.Event.GetChildren(parent)
    for i=1,#children do
        UiElementBus.Event.SetIsEnabled(children[i], false)
    end
end

function UiVerseChallenge:HideAllChildrenExcept(parent, skipEntityName)
    local children = UiElementBus.Event.GetChildren(parent)
    for i=1,#children do
        local name = UiElementBus.Event.GetName(children[i])
        if name ~= skipEntityName then
            UiElementBus.Event.SetIsEnabled(children[i], false)
        end
    end
end

function UiVerseChallenge:OnStartVerseChallenge(card)
    self.card = card
    self.verse = card.verse
    local titleTextEntityId = UiElementBus.Event.FindDescendantByName(self.entityId, "VerseTitleText")

    --local numSections = math.max(3, math.ceil(string.len(self.verse.text) / self.maxSectionLength))
    --self:Log("Dividing verse into " .. tostring(numSections) .. " section(s)")

    -- 1. break up verse into sections
    self.verseSections = self.verse:GetSections()

    -- 2. TODO create alternates for each section

    -- 3. show first section 
    self:ShowVerseSection(1)
end

function UiVerseChallenge:OnSelectFragment(value)
    local index = math.floor(value)

    if index == self.correctFragmentIndex then
        self:Log("Correct verse fragment selected " .. tostring(value))
        if self.currentSection < #self.verseSections then
            self:ShowVerseSection(self.currentSection + 1)
        elseif self.currentSection == #self.verseSections then
            self:Log("No more verse fragments. Showing reference hint.")
            self:ShowVerseReference()
        else
            self:Log("Completed verse challenge")
            Events:GlobalLuaEvent(Events.OnVerseChallengeComplete, self.card)
        end
    else
        self:Log("Incorrect verse fragment selected " .. tostring(value))
    end
end

function UiVerseChallenge:ShowVerseReference()
    self.currentSection = #self.verseSections + 1
    -- pick a random correct answer
    self.correctFragmentIndex = math.random(1,4)
    for i=1,4 do
        local textEntityId = UiElementBus.Event.FindDescendantByName(self.entityId, "VerseFragment"..tostring(i).."Text")
        if textEntityId ~= nil then
            if i == self.correctFragmentIndex then
                UiTextBus.Event.SetText(textEntityId, self.verse.reference)
            else
                UiTextBus.Event.SetText(textEntityId, "Incorrect answer " .. tostring(i))
            end
        end
    end
end

function UiVerseChallenge:ShowVerseSection(section)
    self.currentSection = section
    -- pick a random correct answer
    self.correctFragmentIndex = math.random(1,4)
    for i=1,4 do
        local textEntityId = UiElementBus.Event.FindDescendantByName(self.entityId, "VerseFragment"..tostring(i).."Text")
        if textEntityId ~= nil then
            if i == self.correctFragmentIndex then
                UiTextBus.Event.SetText(textEntityId, self.verseSections[section])
            else
                UiTextBus.Event.SetText(textEntityId, "Incorrect answer " .. tostring(i))
            end
        end
    end
end

function UiVerseChallenge:OnCardUsed(cardIndex)
    self:FlashCard(cardIndex)
end

function UiVerseChallenge:FlashCard(cardIndex)
    local entityId = UiElementBus.Event.FindChildByName(self.entityId, "Card"..tostring(cardIndex))
    if entityId == nil or not entityId:IsValid() then
        self:Log("$5 Card entity not found for index "..tostring(cardIndex))
        return
    end

    local fadeEntityId = UiElementBus.Event.FindChildByName(entityId, "White")
    if fadeEntityId == nil or not fadeEntityId:IsValid() then
        self:Log("$5 White fade entity not found for card index "..tostring(cardIndex))
        return
    end

    self:Log("OnCardUsed")
    UiElementBus.Event.SetIsEnabled(fadeEntityId, true)
    UiImageBus.Event.SetAlpha(fadeEntityId, 1.0)
    local anim = {
        FadeEntityId = fadeEntityId,
        Animating = true,
        Card = nil,
        UiVerseChallenge = self
    }
    anim.OnEasingUpdate = function(_self, jobId, value)
        UiImageBus.Event.SetAlpha(_self.FadeEntityId, value)
    end
    anim.OnEasingEnd = function(_self, jobId)
        UiElementBus.Event.SetIsEnabled(_self.FadeEntityId, false)
        _self.Animating = false
    end
    anim.jobId = Easing:Ease(Easing.OutCubic, 1000, 1, 0 ,anim)
    self.anims["Card"..cardIndex] = anim
end

function UiVerseChallenge:OnCardDiscarded(cardIndex)
    self:FlashCard(cardIndex)
end

function UiVerseChallenge:OnSetPlayerCard(cardIndex, card)
    self:Log("OnSetPlayerCard " .. tostring(cardIndex))

    local entityId = UiElementBus.Event.FindChildByName(self.entityId, "Card"..tostring(cardIndex))
    if entityId == nil then
        self:Log("$5 Card entity not found for index "..tostring(cardIndex))
        return
    end

    if card ~= nil and card.color ~= nil then
        local anim = self.anims["Card"..cardIndex]
        if  anim ~= nil and anim.Animating then
            -- disable all except the animating entity
            self:HideAllChildrenExcept(entityId, "White")
        else
            UiElementBus.Event.SetIsEnabled(entityId, true)
            self:HideAllChildren(entityId)
        end

        local child = UiElementBus.Event.FindChildByName(entityId, card.type)
        if child ~= nil and child:IsValid() then
            --self:Log("Found card image of type " .. tostring(card.type))
            UiElementBus.Event.SetIsEnabled(child, true)
        else
            self:Log("$7 Did not find card image of type " .. tostring(card.type))
        end

        child  = UiElementBus.Event.FindChildByName(entityId, "Text")
        if child ~= nil and child:IsValid() then
            UiElementBus.Event.SetIsEnabled(child, true)
        end 

        UiImageBus.Event.SetColor(entityId, card.color)
    else
        UiElementBus.Event.SetIsEnabled(entityId, false)
    end
end

function UiVerseChallenge:OnDeactivate()
    Events:Disconnect(self)
end

return UiVerseChallenge