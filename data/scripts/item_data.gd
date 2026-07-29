class_name ItemData
extends Resource
## Definition of a single item the tavern can stock, serve, or sell.
##
## Instances live as [code].tres[/code] files under [code]res://data/items/[/code]
## and are loaded into the catalog by [code]GameManager[/code] at boot.

## Broad gameplay category used for sorting and behavior branching.
enum Category {
	DRINK,
	FOOD,
	INGREDIENT,
	TABLEWARE,
	FURNISHING,
}

## Stable identifier used in saves and recipes. Never rename after shipping.
@export var id: StringName = &""

## Player-facing name.
@export var display_name: String = ""

## Short flavor / tooltip text.
@export_multiline var description: String = ""

@export var category: Category = Category.INGREDIENT

## Base value in copper coins.
@export_range(0, 10000) var base_value: int = 1

## Physical weight in kilograms, used for carry physics mass.
@export_range(0.05, 50.0, 0.05) var weight: float = 0.5

@export var stackable: bool = false

## Maximum stack size when [member stackable] is true.
@export_range(1, 99) var max_stack: int = 1


## True when the item can be consumed by patrons (drink or food).
func is_servable() -> bool:
	return category == Category.DRINK or category == Category.FOOD
