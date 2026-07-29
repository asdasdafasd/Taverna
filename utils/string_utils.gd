class_name StringUtils
extends RefCounted
## String formatting helpers for UI and logging.

const COPPER_PER_SILVER: int = 10
const SILVER_PER_GOLD: int = 10
const COPPER_PER_GOLD: int = COPPER_PER_SILVER * SILVER_PER_GOLD


## Formats a copper amount as a compact coin string, e.g. 132 -> "1g 3s 2c".
## Zero denominations are omitted; zero total reads "0c".
static func format_coins(copper_total: int) -> String:
	if copper_total <= 0:
		return "0c"
	@warning_ignore("integer_division")
	var gold: int = copper_total / COPPER_PER_GOLD
	@warning_ignore("integer_division")
	var silver: int = (copper_total % COPPER_PER_GOLD) / COPPER_PER_SILVER
	var copper: int = copper_total % COPPER_PER_SILVER
	var parts: PackedStringArray = PackedStringArray()
	if gold > 0:
		parts.append("%dg" % gold)
	if silver > 0:
		parts.append("%ds" % silver)
	if copper > 0:
		parts.append("%dc" % copper)
	return " ".join(parts)


## Formats a 24h clock value like "18:05".
static func format_clock(hour: int, minute: int) -> String:
	return "%02d:%02d" % [hour, minute]


## Formats a full timestamp line for the HUD, e.g. "Day 3 - 18:05".
static func format_day_clock(day: int, hour: int, minute: int) -> String:
	return "Day %d - %s" % [day, format_clock(hour, minute)]
