return {
	-- player events
	OnAttack = "OnAttack",
	OnLeftRight = "OnLeftRight",
	OnUpDown ="OnUpDown",

	SetGameState = "SetGameState",
	GetPlayer = "GetPlayer",
	GetEnemy = "GetEnemy",
    GetTile = "GetTile",
    ModifyCoinAmount = "ModifyCoinAmount",

    OnSetEnemies = 'OnSetEnemies',
    OnSetEnemy = 'OnSetEnemy',
    OnRevealTile = 'OnRevealTile',
    OnSetPlayerCard = 'OnSetPlayerCard',
    OnTakeDamage = 'OnTakeDamage',
    OnEnemyDefeated = 'OnEnemyDefeated',
    OnEnterCombat = 'OnEnterCombat',
    OnExitCombat = 'OnExitCombat',
    OnUpdateCoinsAmount = "OnUpdateCoinsAmount",
    OnUpdateTimeRemaining = "OnUpdateTimeRemaining",
    OnUpdateWeaknessAmount = "OnUpdateWeaknessAmount",
    OnTimerFinished = "OnTimerFinished",
	OnQuitGame = "OnQuitGame",
	OnRunAway = "OnRunAway",
    OnUseCard = "OnUseCard",
    OnDiscard = "OnDiscard",
    OnSetEnemyCardVisible = "OnSetEnemyCardVisible",
    OnSetPlayerCardsVisible = "OnSetPlayerCardsVisible"
}