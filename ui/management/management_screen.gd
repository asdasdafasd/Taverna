class_name ManagementScreen
extends CanvasLayer
## The keeper's ledger: a tabbed management interface over live game state.
##
## Tabs: Overview (gold, tension, ledger), Menu & Stock (prices, restocking),
## Staff (roster and wages), Upgrades (shop), Reputation (per race), and
## Journal (running event log for future quest hooks). Opens with Tab,
## freezes the world while open, and rebuilds from the live managers every
## time it is shown or the underlying data changes.

const PANEL_COLOR: Color = Color(0.09, 0.065, 0.045, 0.97)
const HEADER_COLOR: Color = Color(0.96, 0.9, 0.78)
const ACCENT_COLOR: Color = Color(0.92, 0.78, 0.42)
const MUTED_COLOR: Color = Color(0.72, 0.66, 0.58)
const GOOD_COLOR: Color = Color(0.55, 0.8, 0.45)
const BAD_COLOR: Color = Color(0.9, 0.45, 0.35)
const TENSION_COLORS: Array[Color] = [
	Color(0.55, 0.8, 0.45), Color(0.95, 0.75, 0.3), Color(0.9, 0.35, 0.28),
]

const JOURNAL_LIMIT: int = 60
const LEDGER_ROWS_SHOWN: int = 12
const PRICE_STEP_COPPER: int = 1

var is_open: bool = false

var _journal_lines: Array[String] = []
var _tabs: TabContainer = null
var _gold_label: Label = null
var _tension_bar: ProgressBar = null
var _tension_label: Label = null
var _overview_box: VBoxContainer = null
var _menu_box: VBoxContainer = null
var _staff_box: VBoxContainer = null
var _upgrades_box: VBoxContainer = null
var _reputation_box: VBoxContainer = null
var _quests_box: VBoxContainer = null
var _journal_text: RichTextLabel = null
var _root: Control = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_root.visible = false
	EventBus.notification_posted.connect(_on_journal_event)
	EventBus.brawl_started.connect(_on_brawl_journal)
	EconomyManager.payment_missed.connect(_on_payment_missed_journal)
	InventoryManager.item_sold_out.connect(_on_sold_out_journal)
	TensionManager.warning_reached.connect(_on_tension_warning)
	TensionManager.critical_reached.connect(_on_tension_critical)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("management"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or GameManager.state != GameManager.State.PLAYING:
		return
	# A dialogue (or other system) may pause the tree while state stays
	# PLAYING; never open the ledger on top of that.
	if get_tree().paused:
		return
	AudioManager.play_cue(&"ui_click", -8.0)
	GameManager.open_management()
	is_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	if not is_open:
		return
	GameManager.close_management()
	is_open = false
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Rebuilds every tab from live manager state.
func refresh() -> void:
	_refresh_header()
	_refresh_overview()
	_refresh_menu()
	_refresh_staff()
	_refresh_upgrades()
	_refresh_reputation()
	_refresh_quests()
	_refresh_journal()


# --- Interface construction --------------------------------------------------


func _build_interface() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1080, 660)
	panel.position = Vector2(-540, -330)
	_root.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	column.add_child(_build_header())
	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)

	_overview_box = _add_tab("Overview")
	_menu_box = _add_tab("Menu & Stock")
	_staff_box = _add_tab("Staff")
	_upgrades_box = _add_tab("Upgrades")
	_reputation_box = _add_tab("Reputation")
	_quests_box = _add_tab("Quests")
	_journal_text = _add_journal_tab()

	var hint: Label = Label.new()
	hint.name = "Hint"
	hint.text = "Tab — close ledger    Esc — close"
	hint.add_theme_color_override("font_color", MUTED_COLOR)
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _build_header() -> Control:
	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 24)

	var title: Label = Label.new()
	title.text = "The Wandering Flagon — Keeper's Ledger"
	title.add_theme_color_override("font_color", HEADER_COLOR)
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", ACCENT_COLOR)
	_gold_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_gold_label)

	var tension_group: VBoxContainer = VBoxContainer.new()
	tension_group.custom_minimum_size = Vector2(220, 0)
	_tension_label = Label.new()
	_tension_label.add_theme_font_size_override("font_size", 13)
	tension_group.add_child(_tension_label)
	_tension_bar = ProgressBar.new()
	_tension_bar.min_value = TensionManager.MIN_TENSION
	_tension_bar.max_value = TensionManager.MAX_TENSION
	_tension_bar.show_percentage = false
	_tension_bar.custom_minimum_size = Vector2(0, 14)
	tension_group.add_child(_tension_bar)
	header.add_child(tension_group)
	return header


func _add_tab(tab_title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = tab_title.replace(" & ", "And").replace(" ", "")
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, tab_title)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


func _add_journal_tab() -> RichTextLabel:
	var text: RichTextLabel = RichTextLabel.new()
	text.name = "Journal"
	text.bbcode_enabled = true
	text.scroll_following = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(text)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, "Journal")
	return text


# --- Tab refreshers ------------------------------------------------------------


func _refresh_header() -> void:
	_gold_label.text = StringUtils.format_coins(GameManager.funds_copper)
	_tension_bar.value = TensionManager.tension
	var level: int = TensionManager.level()
	var level_names: Array[String] = ["Calm", "Uneasy", "CRITICAL"]
	_tension_label.text = "Room tension: %s (%d)" % [
		level_names[level], int(TensionManager.tension),
	]
	_tension_label.add_theme_color_override("font_color", TENSION_COLORS[level])
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = TENSION_COLORS[level]
	_tension_bar.add_theme_stylebox_override("fill", fill)


func _refresh_overview() -> void:
	_clear(_overview_box)
	var today: Vector2i = EconomyManager.totals_for_day(TimeManager.day)
	var yesterday: Vector2i = EconomyManager.totals_for_day(TimeManager.day - 1)
	_overview_box.add_child(_section_label("House status"))
	_overview_box.add_child(_info_row(
		"Clock", TimeManager.clock_text()
		+ ("  (open hours)" if TimeManager.is_open_hours() else "  (quiet hours)")
	))
	_overview_box.add_child(_info_row(
		"Today", "+%s / -%s" % [
			StringUtils.format_coins(today.x), StringUtils.format_coins(today.y),
		]
	))
	_overview_box.add_child(_info_row(
		"Yesterday", "+%s / -%s" % [
			StringUtils.format_coins(yesterday.x), StringUtils.format_coins(yesterday.y),
		]
	))
	_overview_box.add_child(_info_row(
		"Daily wages", StringUtils.format_coins(EconomyManager.total_daily_wages())
	))
	_overview_box.add_child(_info_row(
		"Daily rent", StringUtils.format_coins(EconomyManager.DAILY_RENT_COPPER)
	))
	_overview_box.add_child(_info_row(
		"Reputation (overall)", "%d / 100" % int(ReputationManager.overall())
	))
	_overview_box.add_child(_info_row(
		"Active brawls", str(BrawlManager.active_brawl_count())
	))

	var damage: int = BrawlManager.damage_owed_copper
	var damage_row: HBoxContainer = HBoxContainer.new()
	damage_row.add_theme_constant_override("separation", 12)
	var damage_label: Label = Label.new()
	damage_label.text = "Furniture damage: %s" % StringUtils.format_coins(damage)
	damage_label.add_theme_color_override(
		"font_color", BAD_COLOR if damage > 0 else MUTED_COLOR
	)
	damage_row.add_child(damage_label)
	if damage > 0:
		var repair_button: Button = Button.new()
		repair_button.text = "Repair (%s)" % StringUtils.format_coins(damage)
		repair_button.pressed.connect(_on_repair_pressed)
		damage_row.add_child(repair_button)
	_overview_box.add_child(damage_row)

	_overview_box.add_child(_section_label("Recent ledger"))
	var recent: Array[LedgerEntry] = (
		EconomyManager.recent_entries(LEDGER_ROWS_SHOWN)
	)
	if recent.is_empty():
		_overview_box.add_child(_muted_label("No transactions recorded yet."))
	for entry: LedgerEntry in recent:
		var line: Label = Label.new()
		line.text = entry.describe()
		line.add_theme_font_size_override("font_size", 14)
		line.add_theme_color_override(
			"font_color", GOOD_COLOR if entry.amount >= 0 else BAD_COLOR
		)
		_overview_box.add_child(line)


func _refresh_menu() -> void:
	_clear(_menu_box)
	_menu_box.add_child(_section_label("Menu prices and stock"))
	for item_id: StringName in InventoryManager.servable_item_ids():
		var item: ItemData = GameManager.get_item(item_id)
		if item == null:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_label: Label = Label.new()
		name_label.text = item.display_name
		name_label.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_label)

		var stock_units: int = InventoryManager.stock_of(item_id)
		var stock_label: Label = Label.new()
		stock_label.text = "stock %d" % stock_units
		stock_label.custom_minimum_size = Vector2(80, 0)
		stock_label.add_theme_color_override(
			"font_color", BAD_COLOR if stock_units == 0 else MUTED_COLOR
		)
		row.add_child(stock_label)

		var minus: Button = Button.new()
		minus.text = "-"
		minus.pressed.connect(_on_price_step.bind(item_id, -PRICE_STEP_COPPER))
		row.add_child(minus)

		var price_label: Label = Label.new()
		price_label.text = StringUtils.format_coins(InventoryManager.price_of(item_id))
		price_label.custom_minimum_size = Vector2(70, 0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if InventoryManager.is_gouging(item_id):
			price_label.add_theme_color_override("font_color", BAD_COLOR)
			price_label.tooltip_text = "Patrons resent this price."
		else:
			price_label.add_theme_color_override("font_color", ACCENT_COLOR)
		row.add_child(price_label)

		var plus: Button = Button.new()
		plus.text = "+"
		plus.pressed.connect(_on_price_step.bind(item_id, PRICE_STEP_COPPER))
		row.add_child(plus)

		var margin_label: Label = Label.new()
		margin_label.text = "(base %s)" % StringUtils.format_coins(item.base_value)
		margin_label.add_theme_color_override("font_color", MUTED_COLOR)
		margin_label.add_theme_font_size_override("font_size", 13)
		row.add_child(margin_label)

		var restock: Button = Button.new()
		restock.text = "Restock +%d (%s)" % [
			InventoryManager.RESTOCK_BATCH_UNITS,
			StringUtils.format_coins(InventoryManager.restock_cost(item_id)),
		]
		restock.pressed.connect(_on_restock_pressed.bind(item_id))
		row.add_child(restock)

		_menu_box.add_child(row)
	_menu_box.add_child(_muted_label(
		"Prices above double the base value count as gouging and sour moods."
	))


func _refresh_staff() -> void:
	_clear(_staff_box)
	_staff_box.add_child(_section_label("Roster"))
	var staff_nodes: Array[Node] = get_tree().get_nodes_in_group(
		EconomyManager.STAFF_GROUP
	)
	if staff_nodes.is_empty():
		_staff_box.add_child(_muted_label("No staff hired."))
	for node: Node in staff_nodes:
		var staff: StaffNPC = node as StaffNPC
		if staff == null:
			continue
		var status: String = "working" if staff.is_working else "idle"
		_staff_box.add_child(_info_row(
			"%s — %s" % [staff.role_title, staff.npc_name],
			"%s / day    %s" % [
				StringUtils.format_coins(staff.wage_copper), status,
			]
		))
	_staff_box.add_child(_section_label("Costs"))
	_staff_box.add_child(_info_row(
		"Total wages", "%s / day" % StringUtils.format_coins(
			EconomyManager.total_daily_wages()
		)
	))
	_staff_box.add_child(_info_row(
		"Rent", "%s / day" % StringUtils.format_coins(
			EconomyManager.DAILY_RENT_COPPER
		)
	))
	_staff_box.add_child(_muted_label(
		"Wages and rent are charged at midnight. Missing them hurts "
		+ "reputation and rattles the room."
	))


func _refresh_upgrades() -> void:
	_clear(_upgrades_box)
	var current_branch: int = -1
	for upgrade: UpgradeData in UpgradeManager.all_upgrades():
		if upgrade.branch != current_branch:
			current_branch = upgrade.branch
			_upgrades_box.add_child(_section_label(upgrade.branch_name()))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var text_box: VBoxContainer = VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label: Label = Label.new()
		name_label.text = upgrade.display_name
		name_label.add_theme_color_override("font_color", HEADER_COLOR)
		text_box.add_child(name_label)
		var description_label: Label = Label.new()
		description_label.text = upgrade.description
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.add_theme_font_size_override("font_size", 13)
		description_label.add_theme_color_override("font_color", MUTED_COLOR)
		text_box.add_child(description_label)
		row.add_child(text_box)

		if UpgradeManager.is_owned(upgrade.id):
			var owned_label: Label = Label.new()
			owned_label.text = "OWNED"
			owned_label.add_theme_color_override("font_color", GOOD_COLOR)
			row.add_child(owned_label)
		else:
			var buy: Button = Button.new()
			buy.text = "Buy (%s)" % StringUtils.format_coins(upgrade.cost_copper)
			var locked: bool = not UpgradeManager.can_purchase(upgrade.id)
			var unaffordable: bool = upgrade.cost_copper > GameManager.funds_copper
			buy.disabled = locked or unaffordable
			if locked and upgrade.requires_id != &"":
				var requirement: UpgradeData = UpgradeManager.get_upgrade(
					upgrade.requires_id
				)
				buy.tooltip_text = "Requires: %s" % (
					requirement.display_name if requirement != null
					else String(upgrade.requires_id)
				)
			elif unaffordable:
				buy.tooltip_text = "Not enough coin."
			buy.pressed.connect(_on_upgrade_pressed.bind(upgrade.id))
			row.add_child(buy)
		_upgrades_box.add_child(row)


func _refresh_reputation() -> void:
	_clear(_reputation_box)
	_reputation_box.add_child(_section_label("Standing by race"))
	for race: RaceData in GameManager.get_all_races():
		var value: float = ReputationManager.get_reputation(race.id)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label: Label = Label.new()
		name_label.text = race.display_name
		name_label.custom_minimum_size = Vector2(140, 0)
		row.add_child(name_label)
		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = ReputationManager.MIN_REPUTATION
		bar.max_value = ReputationManager.MAX_REPUTATION
		bar.value = value
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(260, 14)
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = GOOD_COLOR if value >= 50.0 else BAD_COLOR
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var value_label: Label = Label.new()
		value_label.text = "%d" % int(value)
		value_label.add_theme_color_override("font_color", MUTED_COLOR)
		row.add_child(value_label)
		var visits_label: Label = Label.new()
		visits_label.text = "visits x%.1f" % (
			ReputationManager.spawn_weight_multiplier(race.id)
		)
		visits_label.add_theme_font_size_override("font_size", 13)
		visits_label.add_theme_color_override("font_color", MUTED_COLOR)
		row.add_child(visits_label)
		_reputation_box.add_child(row)
	_reputation_box.add_child(_muted_label(
		"High standing brings more visits, better moods, and fatter tips."
	))


func _refresh_quests() -> void:
	_clear(_quests_box)
	var act_names: Dictionary[int, String] = {
		1: "Act I — The Inheritance",
		2: "Act II — What Sleeps Below",
		3: "Act III — The Accord",
	}
	var current_act: int = StoryManager.act()
	_quests_box.add_child(_info_row(
		"Story", "%s    (%d quests completed)" % [
			act_names[current_act], QuestManager.completed_count(),
		]
	))
	var status_colors: Dictionary[int, Color] = {
		QuestDefinition.Status.ACTIVE: HEADER_COLOR,
		QuestDefinition.Status.COMPLETED: GOOD_COLOR,
		QuestDefinition.Status.FAILED: BAD_COLOR,
	}
	var status_names: Dictionary[int, String] = {
		QuestDefinition.Status.ACTIVE: "ACTIVE",
		QuestDefinition.Status.COMPLETED: "DONE",
		QuestDefinition.Status.FAILED: "FAILED",
	}
	for act: int in [1, 2, 3]:
		var act_shown: bool = false
		for quest: QuestDefinition in QuestManager.all_quests():
			if quest.act != act:
				continue
			if quest.status == QuestDefinition.Status.LOCKED:
				continue
			if not act_shown:
				act_shown = true
				_quests_box.add_child(_section_label(act_names[act]))
			var row: VBoxContainer = VBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			var title_row: HBoxContainer = HBoxContainer.new()
			title_row.add_theme_constant_override("separation", 10)
			var title_label: Label = Label.new()
			title_label.text = quest.title
			title_label.add_theme_color_override(
				"font_color", status_colors[quest.status]
			)
			title_row.add_child(title_label)
			var status_label: Label = Label.new()
			status_label.text = status_names[quest.status]
			status_label.add_theme_font_size_override("font_size", 12)
			status_label.add_theme_color_override(
				"font_color", status_colors[quest.status]
			)
			title_row.add_child(status_label)
			row.add_child(title_row)
			var description_label: Label = Label.new()
			description_label.text = quest.description
			description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description_label.add_theme_font_size_override("font_size", 13)
			description_label.add_theme_color_override("font_color", MUTED_COLOR)
			row.add_child(description_label)
			if quest.is_active():
				for objective: QuestObjective in quest.objectives:
					var objective_label: Label = Label.new()
					var mark: String = "[x]" if objective.is_done() else "[ ]"
					objective_label.text = "  %s %s" % [
						mark, objective.progress_text(),
					]
					objective_label.add_theme_font_size_override("font_size", 13)
					objective_label.add_theme_color_override(
						"font_color",
						GOOD_COLOR if objective.is_done() else HEADER_COLOR
					)
					row.add_child(objective_label)
			_quests_box.add_child(row)
	if _quests_box.get_child_count() <= 1:
		_quests_box.add_child(_muted_label("No quests discovered yet."))


func _refresh_journal() -> void:
	var text: String = ""
	for line: String in _journal_lines:
		text += line + "\n"
	if text.is_empty():
		text = "[color=#b8a890]The journal is empty. Events will be noted here.[/color]"
	_journal_text.text = text


# --- Actions ---------------------------------------------------------------------


func _on_price_step(item_id: StringName, step: int) -> void:
	AudioManager.play_cue(&"ui_click", -10.0)
	InventoryManager.set_price(item_id, InventoryManager.price_of(item_id) + step)
	_refresh_menu()


func _on_restock_pressed(item_id: StringName) -> void:
	AudioManager.play_cue(&"ui_click", -10.0)
	if not InventoryManager.try_restock(item_id):
		EventBus.post_notification("Not enough coin to restock.")
	_refresh_menu()
	_refresh_header()
	_refresh_overview()


func _on_repair_pressed() -> void:
	AudioManager.play_cue(&"ui_click", -10.0)
	if not BrawlManager.try_repair_damage():
		EventBus.post_notification("Not enough coin for repairs.")
	_refresh_header()
	_refresh_overview()


func _on_upgrade_pressed(upgrade_id: StringName) -> void:
	AudioManager.play_cue(&"ui_click", -10.0)
	if UpgradeManager.try_purchase(upgrade_id):
		_refresh_header()
		_refresh_upgrades()
		_refresh_overview()


# --- Journal feed -----------------------------------------------------------------


func _on_journal_event(text: String) -> void:
	_append_journal(text)


func _on_brawl_journal(initiator: PatronNPC, target: PatronNPC) -> void:
	_append_journal("[color=#e0705a]Brawl: %s vs %s.[/color]" % [
		initiator.npc_name, target.npc_name,
	])


func _on_payment_missed_journal(category: int, shortfall: int) -> void:
	_append_journal("[color=#e0705a]Missed %s payment — short %s.[/color]" % [
		EconomyManager.CATEGORY_NAMES.get(category, "bill"),
		StringUtils.format_coins(shortfall),
	])


func _on_sold_out_journal(item_id: StringName, _units: int = 0) -> void:
	var item: ItemData = GameManager.get_item(item_id)
	var item_name: String = item.display_name if item != null else String(item_id)
	_append_journal("[color=#f2c04d]%s has sold out.[/color]" % item_name)


func _on_tension_warning() -> void:
	_append_journal("[color=#f2c04d]The room has grown uneasy.[/color]")


func _on_tension_critical() -> void:
	_append_journal("[color=#e0705a]The room is at a boiling point![/color]")


func _append_journal(line: String) -> void:
	_journal_lines.append("[color=#b8a890]Day %d %s[/color]  %s" % [
		TimeManager.day,
		StringUtils.format_clock(TimeManager.hour, TimeManager.minute),
		line,
	])
	if _journal_lines.size() > JOURNAL_LIMIT:
		_journal_lines.pop_front()
	if is_open:
		_refresh_journal()


# --- Small builders -----------------------------------------------------------------


func _section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ACCENT_COLOR)
	label.add_theme_font_size_override("font_size", 17)
	return label


func _info_row(key: String, value: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var key_label: Label = Label.new()
	key_label.text = key
	key_label.custom_minimum_size = Vector2(220, 0)
	key_label.add_theme_color_override("font_color", MUTED_COLOR)
	row.add_child(key_label)
	var value_label: Label = Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", HEADER_COLOR)
	row.add_child(value_label)
	return row


func _muted_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED_COLOR)
	return label


func _clear(box: Container) -> void:
	for child: Node in box.get_children():
		child.queue_free()
