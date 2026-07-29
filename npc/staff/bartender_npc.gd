class_name BartenderNPC
extends ServerStaff
## Pours and delivers drink orders from behind the bar counter.


func _init() -> void:
	role_title = "Bartender"
	handled_kind = PatronOrder.Kind.DRINK
	uniform_color = Color(0.45, 0.28, 0.16)
	wage_copper = 14
