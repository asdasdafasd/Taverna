class_name PatronOrder
extends RefCounted
## One patron's request for a drink or meal, tracked from placement to
## delivery. Orders flow over the [EventBus] so staff systems can pick them
## up without referencing patrons directly.

enum Kind {
	DRINK,
	FOOD,
}

enum Status {
	PLACED,
	IN_PREPARATION,
	DELIVERED,
	CANCELLED,
}

var kind: Kind = Kind.DRINK
var item_id: StringName = &""
var patron: PatronNPC = null
var status: Status = Status.PLACED

## Copper price charged on delivery (base value of the item).
var price_copper: int = 0


func _init(order_kind: Kind, ordered_item_id: StringName, ordering_patron: PatronNPC) -> void:
	kind = order_kind
	item_id = ordered_item_id
	patron = ordering_patron
	var item: ItemData = GameManager.get_item(item_id)
	if item != null:
		price_copper = item.base_value


func is_active() -> bool:
	return status == Status.PLACED or status == Status.IN_PREPARATION


## Human-readable summary for logs and debugging.
func describe() -> String:
	var kind_name: String = "drink" if kind == Kind.DRINK else "food"
	return "%s order: %s" % [kind_name, item_id]
