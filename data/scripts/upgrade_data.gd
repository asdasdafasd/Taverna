class_name UpgradeData
extends Resource
## One purchasable tavern upgrade.
##
## Upgrades grant named numeric effects that systems query through
## [code]UpgradeManager.effect_value()[/code], so adding an upgrade never
## requires touching consumer code. Instances live under
## [code]res://data/upgrades/[/code].

## Shop grouping for the management screen.
enum Branch {
	CAPACITY,
	SERVICE,
	SAFETY,
	ECONOMY,
	ATMOSPHERE,
}

const BRANCH_NAMES: Dictionary[Branch, String] = {
	Branch.CAPACITY: "Capacity",
	Branch.SERVICE: "Service",
	Branch.SAFETY: "Safety",
	Branch.ECONOMY: "Economy",
	Branch.ATMOSPHERE: "Atmosphere",
}

## Stable identifier used in saves.
@export var id: StringName = &""

@export var display_name: String = ""

## What the upgrade concretely does, shown in the shop.
@export_multiline var description: String = ""

@export var branch: Branch = Branch.SERVICE

## Purchase price in copper.
@export_range(0, 100000) var cost_copper: int = 100

## Upgrade id that must be owned first ("" = none).
@export var requires_id: StringName = &""

## Named effect keys -> values granted while owned. Values for the same key
## from multiple upgrades are summed by UpgradeManager.
@export var effects: Dictionary[StringName, float] = {}


func branch_name() -> String:
	return BRANCH_NAMES[branch]
