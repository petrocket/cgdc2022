local Events = require "scripts.events"
local Utilities = require "scripts.utilities"
local Topics = require "scripts.topics"
local TopicGroups = require "scripts.topicgroups"

local Enemy = {
    Properties = {
        Debug = false,
        Name = "Enemy",
        MiniBoss = false,
        Boss = false,
        EnemyPrefab = {default=SpawnableScriptAssetRef(), description="Enemy Prefab to spawn"},
        Type = 0, -- mechanical, magical, natural
        Randomness = { -- random topics
            Enabled = false,
            Topics = {
                Min = 2,
                Max = 2
            },
            AmountPerTopic = {
                Min = 1,
                Max = 1
            }
        },
        TopicGroup = '', -- optional topic group
        Topics = { -- specific topics
            Topic1='',
            Topic1Amount=0,
            Topic2='',
            Topic2Amount=0,
            Topic3='',
            Topic3Amount=0,
            Topic4='',
            Topic4Amount=0
        },
        Verses = { -- specific verses
            Verse1='',
            Verse2='',
            Verse3='',
            Verse4=''
        }
    }
}

function Enemy:OnActivate()
    Utilities:InitLogging(self, "Enemy")
    Events:Connect(self, Events.OnStateChange)

    self.spawnableMediator = SpawnableScriptMediator()
    self.spawnTicket = self.spawnableMediator:CreateSpawnTicket(self.Properties.EnemyPrefab)
    self.spawnableListener = SpawnableScriptNotificationsBus.Connect(self, self.spawnTicket:GetId())

    local translation = TransformBus.Event.GetWorldTranslation(self.entityId)
    local gridPosition = tostring(math.floor(translation.x)) .. "_" .. tostring(math.floor(translation.y))
    Events:Connect(self, Events.GetEnemy, gridPosition)
    Events:Connect(self, Events.OnEnterCombat, gridPosition)
    Events:Connect(self, Events.OnExitCombat, gridPosition)
    Events:Connect(self, Events.OnRevealTile, gridPosition)
    Events:Connect(self, Events.OnEnemyDefeated)

    self.mesh = nil
    self.playerPosition = nil
    self.playerTransformListener = nil
    self.tagListener = TagGlobalNotificationBus.Connect(self, Crc32("PlayerMesh"))
    self.revealed = false
end

function Enemy:OnEntityTagAdded(entityId)
    if self.playerTransformListener ~= nil then
        self.playerTransformListener:Disconnect()
    end
    self.playerTransformListener = TransformNotificationBus.Connect(self, entityId)
end

function Enemy:OnTransformChanged(localTM, worldTM)
    self.playerPosition = worldTM:GetTranslation()
    self.playerPosition.z = 0
    self:LookAtPlayer()
end

function Enemy:OnEnterCombat()
    self.inCombat = true 
    Events:GlobalLuaEvent(Events.OnSetEnemy, self.data)
    --Events:Connect(self, Events.OnUpdateTopicAmount)
    Events:Connect(self, Events.OnUpdateTopicAmount)
end

function Enemy:OnUpdateTopicAmount(topic, amount)
    -- TODO FIX this is backwards... the UI is telling us what 
    -- the new weakness is, that logic should be here and
    -- the UI should reflect our data
    if self.data.Topics[topic] ~= nil then
        self.data.Topics[topic].Amount = amount
    end
end

function Enemy:OnEnemyDefeated()
    if self.inCombat then
        self.inCombat = false
        self.mesh = nil
        self.spawnableMediator:Despawn(self.spawnTicket)
    end
end

function Enemy:LookAtPlayer()
    if self.revealed and self.playerPosition ~= nil and self.mesh then
        local selfPosition = TransformBus.Event.GetWorldTranslation(self.mesh)
        if selfPosition ~= nil then
            selfPosition.z = 0

            local tm = Transform.CreateLookAt(selfPosition, self.playerPosition, AxisType.XNegative)
            TransformBus.Event.SetWorldTM(self.mesh, tm)
        end
    end
end

function Enemy:OnSpawn(spawnTicket, entityList)
    self.mesh = entityList[1]

    for i=1,#entityList do
        local isEnemyMesh = TagComponentRequestBus.Event.HasTag(entityList[i], Crc32("EnemyMesh"))
        if isEnemyMesh then
            self.mesh = entityList[i]
        end
    end
    self:LookAtPlayer()
end

function Enemy:OnRevealTile()
    if not self.revealed then
        self.revealed = true
        self.spawnableMediator:SpawnAndParentAndTransform(
            self.spawnTicket,
            self.entityId,
            Vector3(0.0,0.0,0.0),
            Vector3(0,0,0),
            1.0
            )
    end
end

function Enemy:OnExitCombat()
    Events:Disconnect(self, Events.OnUpdateTopicAmount)
    self.inCombat = false
end

function Enemy:Reset()
    --self:Log("Reset")

    self.inCombat = false
    Events:Disconnect(self, Events.OnUpdateTopicAmount)

    self.revealed = false
    self.mesh = nil
    self.spawnableMediator:Despawn(self.spawnTicket)
    self.data = {
        Name = self.Properties.Name,
        MiniBoss = self.Properties.MiniBoss,
        Boss = self.Properties.Boss,
        Type = self.Properties.Type,
        Topics = {},
        Verses = {}
    }

    -- TODO topic group support
    if self.Properties.Randomness.Enabled then
        --self:Log("Giving enemy random topics")
        local topics = Utilities:GetKeyList(Topics)
        Utilities:Shuffle(topics)
        local rules = self.Properties.Randomness
        local numTopics = math.random(rules.Topics.Min, rules.Topics.Max)
        self:Log("Giving enemy " .. self.data.Name .. " "  .. tostring(numTopics) .. " random topics")
        for i=1,numTopics do
            local topic = topics[i]
            self.data.Topics[topic] = { Amount=math.random(rules.AmountPerTopic.Min, rules.AmountPerTopic.Max)}
        end
    else
        self:Log("Giving enemy " .. self.data.Name .. " topics/verses from properties")
        self.data.Topics[self.Properties.Topics.Topic1] = { Amount=math.floor(self.Properties.Topics.Topic1Amount)}
        self.data.Topics[self.Properties.Topics.Topic2] = { Amount=math.floor(self.Properties.Topics.Topic2Amount)}
        self.data.Topics[self.Properties.Topics.Topic3] = { Amount=math.floor(self.Properties.Topics.Topic3Amount)}
        self.data.Topics[self.Properties.Topics.Topic4] = { Amount=math.floor(self.Properties.Topics.Topic4Amount)}
        self.data.Verses = self.Properties.Verses
    end

    for type,topic in pairs(self.data.Topics) do
        self:Log(tostring(type) .. " " .. tostring(topic.Amount))
    end
    for key,verse in pairs(self.data.Verses) do
        self:Log(tostring(verse))
    end
end

function Enemy:GetEnemy()
    return self.data
end

function Enemy:OnStateChange(newState)
    if newState == 'LevelBuildOut' then
        self:Reset()
    end
end

function Enemy:OnDeactivate()
    self.tagListener:Disconnect()
    if self.playerTransformListener ~= nil then
        self.playerTransformListener:Disconnect()
    end
    self.spawnableListener:Disconnect()
    Events:Disconnect(self, Events.GetEnemy)
    Events:Disconnect(self, Events.OnStateChange)
    Events:Disconnect(self, Events.OnEnterCombat)
    Events:Disconnect(self, Events.OnExitCombat)
    Events:Disconnect(self, Events.OnEnemyDefeated)
end

return Enemy