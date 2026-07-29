class_name RecipeData
extends Resource
## A recipe that turns ingredient items into a servable menu item.
##
## Instances live as [code].tres[/code] files under
## [code]res://data/recipes/[/code] and are loaded by [code]GameManager[/code].

## Stable identifier used in saves and menus.
@export var id: StringName = &""

## Player-facing name shown on the menu.
@export var display_name: String = ""

@export_multiline var description: String = ""

## Item ids consumed when preparing this recipe.
@export var ingredient_ids: Array[StringName] = []

## Quantity required per ingredient, index-aligned with [member ingredient_ids].
@export var ingredient_counts: Array[int] = []

## Item id produced by the recipe.
@export var output_item_id: StringName = &""

## Real seconds of preparation work required.
@export_range(1.0, 600.0, 0.5) var prep_seconds: float = 10.0

## Menu price in copper coins.
@export_range(0, 10000) var sale_price: int = 5


## True when the ingredient arrays are consistent and the recipe is usable.
func is_valid() -> bool:
	if id == &"" or output_item_id == &"":
		return false
	return ingredient_ids.size() == ingredient_counts.size()
