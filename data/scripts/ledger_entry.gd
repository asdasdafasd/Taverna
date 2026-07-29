class_name LedgerEntry
extends RefCounted
## One dated line in the tavern's account book.
##
## Created exclusively by [code]EconomyManager[/code]; UI reads these for
## history lists and daily summaries.

var day: int = 1
var hour: int = 0
var minute: int = 0

## Positive for income, negative for expenses, in copper.
var amount: int = 0

## EconomyManager.Category value.
var category: int = 0
var note: String = ""


func describe() -> String:
	var sign_text: String = "+" if amount >= 0 else "-"
	var category_name: String = EconomyManager.CATEGORY_NAMES.get(category, "Other")
	return "Day %d %s  %s%s  %s%s" % [
		day,
		StringUtils.format_clock(hour, minute),
		sign_text,
		StringUtils.format_coins(absi(amount)),
		category_name,
		"" if note.is_empty() else " — " + note,
	]
