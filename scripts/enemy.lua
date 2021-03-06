local Events = require "scripts.events"
local Utilities = require "scripts.utilities"

local Enemy = {
    Properties = {
        Debug = false,
        Name = "Enemy",
        MiniBoss = false,
        Boss = false,
        EnemyPrefab = {default=SpawnableScriptAssetRef(), description="Enemy Prefab to spawn"},
        Type = 0, -- mechanical, magical, natural
        Randomness = {
            Enabled = false,
            WeaknessTypes = {
                Min = 2,
                Max = 2
            },
            AmountPerType = {
                Min = 1,
                Max = 1
            }
        },
        Weaknesses = {
            Arrow = 0,
            Sword = 0,
            Shield = 0,
            Scroll = 0
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
    Events:Connect(self, Events.OnUpdateWeaknessAmount)
end

function Enemy:OnUpdateWeaknessAmount(weakness, amount)
    -- TODO FIX this is backwards... the UI is telling us what 
    -- the new weakness is, that logic should be here and
    -- the UI should reflect our data
    if self.data.Weaknesses[weakness] ~= nil then
        self.data.Weaknesses[weakness].Amount = amount
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
    Events:Disconnect(self, Events.OnUpdateWeaknessAmount)
    self.inCombat = false
end

function Enemy:Reset()
    self:Log("Reset")

    self.inCombat = false
    Events:Disconnect(self, Events.OnUpdateWeaknessAmount)

    self.revealed = false
    self.mesh = nil
    self.spawnableMediator:Despawn(self.spawnTicket)
    self.data = {
        Name = self.Properties.Name,
        MiniBoss = self.Properties.MiniBoss,
        Boss = self.Properties.Boss,
        Type = self.Properties.Type,
        Weaknesses = {}
    }

    if self.Properties.Randomness.Enabled then
        self:Log("Giving enemy random weaknesses")
        local weaknessTypes = {"Arrow","Sword","Shield","Scroll"}
        local rules = self.Properties.Randomness
        Utilities:Shuffle(weaknessTypes)
        local numWeaknessTypes = math.random(rules.WeaknessTypes.Min, rules.WeaknessTypes.Max)
        self:Log("Giving enemy " .. tostring(numWeaknessTypes) .. " random weakness types ")
        for i=1,numWeaknessTypes do
            local weaknessType = weaknessTypes[i]
            local amount = math.random(rules.AmountPerType.Min, rules.AmountPerType.Max)
            self.data.Weaknesses[weaknessType] =  { Amount=amount}
        end
    else
        self:Log("Giving enemy weaknesses from properties")
        self.data.Weaknesses.Arrow = { Amount=math.floor(self.Properties.Weaknesses.Arrow)}
        self.data.Weaknesses.Shield = { Amount=math.floor(self.Properties.Weaknesses.Shield)}
        self.data.Weaknesses.Sword = { Amount=math.floor(self.Properties.Weaknesses.Sword)}
        self.data.Weaknesses.Scroll = { Amount=math.floor(self.Properties.Weaknesses.Scroll)}
    end

    for type,weakness in pairs(self.data.Weaknesses) do
        self:Log(tostring(type) .. " " .. tostring(weakness.Amount))
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