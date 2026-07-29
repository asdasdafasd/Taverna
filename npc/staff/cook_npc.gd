class_name CookNPC
extends ServerStaff
## Prepares and delivers food orders from the kitchen.


func _init() -> void:
	role_title = "Cook"
	handled_kind = PatronOrder.Kind.FOOD
	uniform_color = Color(0.85, 0.82, 0.75)
	wage_copper = 14
