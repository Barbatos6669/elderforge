## Prototype auction house window.
##
## This panel is UI-only: it displays market state, reads the player's
## inventory, and sends commands to the AuctionMarket singleton.
class_name AuctionHousePanel
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const MAX_ORDER_QUANTITY := 999
const MAX_UNIT_PRICE := 999999

enum Mode {
	BUY,
	SELL_ORDER,
	BUY_ORDER,
	QUICK_SALE,
}

## Inventory node used for item/silver transactions.
@export var inventory_path: NodePath
## Shows the menu at scene start for isolated UI previews.
@export var start_visible := false

var _inventory: Node
var _market: Node
var _auctioneer: Node
var _root: Control
var _wallet_label: Label
var _status_label: Label
var _tab_buttons: Dictionary = {}
var _list_container: VBoxContainer
var _detail_container: VBoxContainer
var _right_container: VBoxContainer
var _mode := Mode.BUY
var _selected_listing_id := 0
var _selected_inventory_item_id := ""
var _selected_market_item_id := ""
var _block_world_input_until_mouse_release := false


func _ready() -> void:
	add_to_group("auction_house_panel")
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	visible = start_visible
	_build_window()
	_bind_inventory()
	_bind_market()
	_refresh()


func open_for_auctioneer(auctioneer: Node) -> void:
	_auctioneer = auctioneer
	visible = true
	_block_world_input_until_mouse_release = false
	_bind_inventory()
	_bind_market()
	_refresh()


func close() -> void:
	visible = false
	_block_world_input_until_mouse_release = _is_world_move_mouse_button_down()


func blocks_world_input() -> bool:
	if visible:
		return true

	if _block_world_input_until_mouse_release:
		if _is_world_move_mouse_button_down():
			return true
		_block_world_input_until_mouse_release = false

	return false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_window() -> void:
	if _root != null:
		return

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.32)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "Window"
	panel.custom_minimum_size = Vector2(980.0, 620.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -490.0
	panel.offset_top = -310.0
	panel.offset_right = 490.0
	panel.offset_bottom = 310.0
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	layout.add_child(_build_header())
	layout.add_child(_build_tabs())
	layout.add_child(_build_body())
	layout.add_child(_build_footer())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 42.0)
	header.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "AUCTION HOUSE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_primary(title, 26, 2)
	title.add_theme_color_override("font_color", UiStyle.COLOR_GOLD)
	header.add_child(title)

	_wallet_label = Label.new()
	_wallet_label.text = "Silver: 0"
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_primary(_wallet_label, 16, 1)
	header.add_child(_wallet_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(38.0, 34.0)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	return header


func _build_tabs() -> Control:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_add_tab_button(tabs, Mode.BUY, "Buy")
	_add_tab_button(tabs, Mode.SELL_ORDER, "Sell Order")
	_add_tab_button(tabs, Mode.BUY_ORDER, "Buy Order")
	_add_tab_button(tabs, Mode.QUICK_SALE, "Quick Sale")
	return tabs


func _add_tab_button(parent: Control, mode: int, text: String) -> void:
	var button := _make_button(text, Vector2(150.0, 38.0))
	button.pressed.connect(_set_mode.bind(mode))
	parent.add_child(button)
	_tab_buttons[mode] = button


func _build_body() -> Control:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)

	var list_panel := _make_section_panel("MarketList", Vector2(310.0, 0.0))
	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 8)
	list_panel.add_child(_with_margin(_list_container))
	body.add_child(list_panel)

	var detail_panel := _make_section_panel("MarketDetail", Vector2(330.0, 0.0))
	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", 10)
	detail_panel.add_child(_with_margin(_detail_container))
	body.add_child(detail_panel)

	var right_panel := _make_section_panel("MarketOrders", Vector2(270.0, 0.0))
	_right_container = VBoxContainer.new()
	_right_container.add_theme_constant_override("separation", 8)
	right_panel.add_child(_with_margin(_right_container))
	body.add_child(right_panel)
	return body


func _build_footer() -> Control:
	_status_label = Label.new()
	_status_label.text = "Choose a market action."
	_status_label.custom_minimum_size = Vector2(0.0, 28.0)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_muted(_status_label, 14)
	return _status_label


func _set_mode(mode: int) -> void:
	_mode = mode
	_status_label.text = _mode_help_text()
	_refresh()


func _refresh() -> void:
	if _root == null:
		return

	_refresh_wallet()
	_refresh_tabs()
	_clear_children(_list_container)
	_clear_children(_detail_container)
	_clear_children(_right_container)

	match _mode:
		Mode.BUY:
			_refresh_buy_mode()
		Mode.SELL_ORDER:
			_refresh_sell_order_mode()
		Mode.BUY_ORDER:
			_refresh_buy_order_mode()
		Mode.QUICK_SALE:
			_refresh_quick_sale_mode()


func _refresh_tabs() -> void:
	for mode in _tab_buttons.keys():
		var button := _tab_buttons[mode] as Button
		button.add_theme_stylebox_override("normal", UiStyle.master_menu_submenu_button_style(mode == _mode))


func _refresh_wallet() -> void:
	if _wallet_label == null:
		return

	var silver := int(_inventory.call("get_silver")) if _inventory != null and _inventory.has_method("get_silver") else 0
	_wallet_label.text = "Silver: %s" % _format_whole_number(silver)


func _refresh_buy_mode() -> void:
	_list_container.add_child(_section_title("Sell Listings"))
	var listings := _market_sell_listings()
	if listings.is_empty():
		_list_container.add_child(_muted_label("No sell listings yet."))
		_detail_container.add_child(_section_title("Buy"))
		_detail_container.add_child(_muted_label("Players can create sell orders from the Sell Order tab."))
		_refresh_buy_orders_sidebar()
		return

	if _selected_listing_id == 0:
		_selected_listing_id = int(listings[0].get("id", 0))

	for listing in listings:
		var id := int(listing.get("id", 0))
		var button := _make_list_button(
			"%s\n%d available | %s silver each" % [
				_item_name(String(listing.get("item_id", ""))),
				int(listing.get("quantity", 0)),
				_format_whole_number(int(listing.get("price_per_unit", 0))),
			],
			id == _selected_listing_id
		)
		button.pressed.connect(_select_listing.bind(id))
		_list_container.add_child(button)

	_build_buy_details(_selected_sell_listing())
	_refresh_buy_orders_sidebar()


func _build_buy_details(listing: Dictionary) -> void:
	_detail_container.add_child(_section_title("Buy Listing"))
	if listing.is_empty():
		_detail_container.add_child(_muted_label("Select a listing."))
		return

	var item_id := String(listing.get("item_id", ""))
	var price := int(listing.get("price_per_unit", 0))
	var available := int(listing.get("quantity", 0))
	_detail_container.add_child(_item_heading(item_id))
	_detail_container.add_child(_muted_label("Seller: %s" % String(listing.get("owner_id", "unknown"))))
	_detail_container.add_child(_muted_label("Unit price: %s silver" % _format_whole_number(price)))

	var quantity_spin := _make_spinbox(1, available, 1)
	_detail_container.add_child(_labeled_control("Quantity", quantity_spin))

	var buy_button := _make_button("Buy Listing", Vector2(0.0, 42.0))
	buy_button.pressed.connect(func() -> void:
		_run_market_action(_market.call("buy_listing", int(listing.get("id", 0)), int(quantity_spin.value), _inventory))
	)
	_detail_container.add_child(buy_button)

	var total_label := _muted_label("Total at max: %s silver" % _format_whole_number(available * price))
	_detail_container.add_child(total_label)


func _refresh_sell_order_mode() -> void:
	_list_container.add_child(_section_title("Your Items"))
	var rows := _inventory_item_rows()
	if rows.is_empty():
		_list_container.add_child(_muted_label("Your inventory is empty."))
		_detail_container.add_child(_section_title("Create Sell Order"))
		_detail_container.add_child(_muted_label("Gather or craft items first."))
		_refresh_sell_listings_sidebar()
		return

	if _selected_inventory_item_id.is_empty():
		_selected_inventory_item_id = String(rows[0].get("item_id", ""))

	for row in rows:
		var item_id := String(row.get("item_id", ""))
		var best_buy := _market_best_buy_order(item_id)
		var subtitle := "%d owned" % int(row.get("quantity", 0))
		if not best_buy.is_empty():
			subtitle += " | best buy %s" % _format_whole_number(int(best_buy.get("price_per_unit", 0)))
		var button := _make_list_button("%s\n%s" % [_item_name(item_id), subtitle], item_id == _selected_inventory_item_id)
		button.pressed.connect(_select_inventory_item.bind(item_id))
		_list_container.add_child(button)

	_build_sell_order_details(_selected_inventory_item())
	_refresh_sell_listings_sidebar()


func _build_sell_order_details(row: Dictionary) -> void:
	_detail_container.add_child(_section_title("Create Sell Order"))
	if row.is_empty():
		_detail_container.add_child(_muted_label("Select an item."))
		return

	var item_id := String(row.get("item_id", ""))
	var owned := int(row.get("quantity", 0))
	_detail_container.add_child(_item_heading(item_id))
	_detail_container.add_child(_muted_label("Owned: %d" % owned))

	var quantity_spin := _make_spinbox(1, owned, mini(owned, 10))
	var price_spin := _make_spinbox(1, MAX_UNIT_PRICE, _suggest_sell_price(item_id))
	_detail_container.add_child(_labeled_control("Quantity", quantity_spin))
	_detail_container.add_child(_labeled_control("Unit Price", price_spin))

	var post_button := _make_button("Post Sell Order", Vector2(0.0, 42.0))
	post_button.pressed.connect(func() -> void:
		_run_market_action(_market.call(
			"create_sell_order",
			item_id,
			int(quantity_spin.value),
			int(price_spin.value),
			_inventory,
			"player"
		))
	)
	_detail_container.add_child(post_button)

	var quick_button := _make_button("Quick Sell Best Buy", Vector2(0.0, 38.0))
	quick_button.disabled = _market_best_buy_order(item_id).is_empty()
	quick_button.pressed.connect(func() -> void:
		_run_market_action(_market.call("quick_sell", item_id, int(quantity_spin.value), _inventory))
	)
	_detail_container.add_child(quick_button)


func _refresh_buy_order_mode() -> void:
	_list_container.add_child(_section_title("Market Items"))
	var item_ids := _market_item_ids()
	if _selected_market_item_id.is_empty() and item_ids.size() > 0:
		_selected_market_item_id = String(item_ids[0])

	for item_id in item_ids:
		var clean_item_id := String(item_id)
		var best_buy := _market_best_buy_order(clean_item_id)
		var subtitle := "no active buy order"
		if not best_buy.is_empty():
			subtitle = "best buy %s" % _format_whole_number(int(best_buy.get("price_per_unit", 0)))
		var button := _make_list_button("%s\n%s" % [_item_name(clean_item_id), subtitle], clean_item_id == _selected_market_item_id)
		button.pressed.connect(_select_market_item.bind(clean_item_id))
		_list_container.add_child(button)

	_build_buy_order_details(_selected_market_item_id)
	_refresh_buy_orders_sidebar()


func _build_buy_order_details(item_id: String) -> void:
	_detail_container.add_child(_section_title("Create Buy Order"))
	if item_id.is_empty():
		_detail_container.add_child(_muted_label("Choose an item."))
		return

	_detail_container.add_child(_item_heading(item_id))
	var quantity_spin := _make_spinbox(1, MAX_ORDER_QUANTITY, 10)
	var price_spin := _make_spinbox(1, MAX_UNIT_PRICE, _suggest_buy_price(item_id))
	_detail_container.add_child(_labeled_control("Quantity", quantity_spin))
	_detail_container.add_child(_labeled_control("Unit Price", price_spin))

	var reserve_label := _muted_label("Silver is reserved when the order is posted.")
	_detail_container.add_child(reserve_label)

	var post_button := _make_button("Post Buy Order", Vector2(0.0, 42.0))
	post_button.pressed.connect(func() -> void:
		_run_market_action(_market.call(
			"create_buy_order",
			item_id,
			int(quantity_spin.value),
			int(price_spin.value),
			_inventory,
			"player"
		))
	)
	_detail_container.add_child(post_button)


func _refresh_quick_sale_mode() -> void:
	_list_container.add_child(_section_title("Quick Sale Items"))
	var rows := _inventory_item_rows()
	if rows.is_empty():
		_list_container.add_child(_muted_label("Your inventory is empty."))
		_detail_container.add_child(_section_title("Quick Sale"))
		_detail_container.add_child(_muted_label("Quick sale fills the best matching buy order."))
		_refresh_buy_orders_sidebar()
		return

	if _selected_inventory_item_id.is_empty():
		_selected_inventory_item_id = String(rows[0].get("item_id", ""))

	for row in rows:
		var item_id := String(row.get("item_id", ""))
		var best_buy := _market_best_buy_order(item_id)
		var subtitle := "%d owned" % int(row.get("quantity", 0))
		if best_buy.is_empty():
			subtitle += " | no buy order"
		else:
			subtitle += " | %s silver each" % _format_whole_number(int(best_buy.get("price_per_unit", 0)))
		var button := _make_list_button("%s\n%s" % [_item_name(item_id), subtitle], item_id == _selected_inventory_item_id)
		button.pressed.connect(_select_inventory_item.bind(item_id))
		_list_container.add_child(button)

	_build_quick_sale_details(_selected_inventory_item())
	_refresh_buy_orders_sidebar()


func _build_quick_sale_details(row: Dictionary) -> void:
	_detail_container.add_child(_section_title("Quick Sale"))
	if row.is_empty():
		_detail_container.add_child(_muted_label("Select an item."))
		return

	var item_id := String(row.get("item_id", ""))
	var owned := int(row.get("quantity", 0))
	var best_buy := _market_best_buy_order(item_id)
	_detail_container.add_child(_item_heading(item_id))
	_detail_container.add_child(_muted_label("Owned: %d" % owned))
	if best_buy.is_empty():
		_detail_container.add_child(_muted_label("No buy orders are waiting for this item."))
		return

	var price := int(best_buy.get("price_per_unit", 0))
	var max_sale := mini(owned, int(best_buy.get("quantity", 0)))
	_detail_container.add_child(_muted_label("Best buy: %s silver each" % _format_whole_number(price)))
	var quantity_spin := _make_spinbox(1, max_sale, max_sale)
	_detail_container.add_child(_labeled_control("Quantity", quantity_spin))

	var quick_button := _make_button("Quick Sell", Vector2(0.0, 42.0))
	quick_button.pressed.connect(func() -> void:
		_run_market_action(_market.call("quick_sell", item_id, int(quantity_spin.value), _inventory))
	)
	_detail_container.add_child(quick_button)


func _refresh_buy_orders_sidebar() -> void:
	_right_container.add_child(_section_title("Buy Orders"))
	var orders := _market_buy_orders()
	if orders.is_empty():
		_right_container.add_child(_muted_label("No buy orders."))
		return

	for index in range(mini(orders.size(), 8)):
		var order := orders[index] as Dictionary
		_right_container.add_child(_muted_label("%s x%d @ %s" % [
			_item_name(String(order.get("item_id", ""))),
			int(order.get("quantity", 0)),
			_format_whole_number(int(order.get("price_per_unit", 0))),
		]))


func _refresh_sell_listings_sidebar() -> void:
	_right_container.add_child(_section_title("Current Listings"))
	var listings := _market_sell_listings()
	if listings.is_empty():
		_right_container.add_child(_muted_label("No listings."))
		return

	for index in range(mini(listings.size(), 8)):
		var listing := listings[index] as Dictionary
		_right_container.add_child(_muted_label("%s x%d @ %s" % [
			_item_name(String(listing.get("item_id", ""))),
			int(listing.get("quantity", 0)),
			_format_whole_number(int(listing.get("price_per_unit", 0))),
		]))


func _select_listing(listing_id: int) -> void:
	_selected_listing_id = listing_id
	_refresh()


func _select_inventory_item(item_id: String) -> void:
	_selected_inventory_item_id = item_id
	_refresh()


func _select_market_item(item_id: String) -> void:
	_selected_market_item_id = item_id
	_refresh()


func _run_market_action(result_variant: Variant) -> void:
	if result_variant is Dictionary:
		_status_label.text = String((result_variant as Dictionary).get("message", "Done."))
	else:
		_status_label.text = "Market action complete."
	_selected_listing_id = 0
	_refresh()


func _bind_inventory() -> void:
	var next_inventory := _find_inventory()
	if next_inventory == _inventory:
		return

	if _inventory != null:
		_disconnect_inventory_signal("slots_changed", "_on_inventory_changed")
		_disconnect_inventory_signal("currency_changed", "_on_inventory_currency_changed")

	_inventory = next_inventory
	if _inventory != null:
		_connect_inventory_signal("slots_changed", "_on_inventory_changed")
		_connect_inventory_signal("currency_changed", "_on_inventory_currency_changed")


func _bind_market() -> void:
	var next_market := get_node_or_null("/root/AuctionMarket")
	if next_market == _market:
		return

	if _market != null:
		var changed_callable := Callable(self, "_on_market_changed")
		if _market.has_signal("market_changed") and _market.is_connected("market_changed", changed_callable):
			_market.disconnect("market_changed", changed_callable)
		var message_callable := Callable(self, "_on_market_message")
		if _market.has_signal("transaction_message") and _market.is_connected("transaction_message", message_callable):
			_market.disconnect("transaction_message", message_callable)

	_market = next_market
	if _market != null:
		var changed_callable := Callable(self, "_on_market_changed")
		if _market.has_signal("market_changed") and not _market.is_connected("market_changed", changed_callable):
			_market.connect("market_changed", changed_callable)
		var message_callable := Callable(self, "_on_market_message")
		if _market.has_signal("transaction_message") and not _market.is_connected("transaction_message", message_callable):
			_market.connect("transaction_message", message_callable)


func _connect_inventory_signal(signal_name: StringName, method_name: StringName) -> void:
	var callable := Callable(self, method_name)
	if _inventory.has_signal(signal_name) and not _inventory.is_connected(signal_name, callable):
		_inventory.connect(signal_name, callable)


func _disconnect_inventory_signal(signal_name: StringName, method_name: StringName) -> void:
	var callable := Callable(self, method_name)
	if _inventory.has_signal(signal_name) and _inventory.is_connected(signal_name, callable):
		_inventory.disconnect(signal_name, callable)


func _on_inventory_changed() -> void:
	_refresh()


func _on_inventory_currency_changed(_silver: int, _gold: int) -> void:
	_refresh_wallet()


func _on_market_changed() -> void:
	_refresh()


func _on_market_message(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _find_inventory() -> Node:
	if inventory_path != NodePath(""):
		var inventory := get_node_or_null(inventory_path)
		if inventory != null:
			return inventory

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("player_inventory")


func _market_sell_listings() -> Array:
	if _market != null and _market.has_method("get_sell_listings"):
		return _market.call("get_sell_listings")
	return []


func _market_buy_orders() -> Array:
	if _market != null and _market.has_method("get_buy_orders"):
		return _market.call("get_buy_orders")
	return []


func _market_item_ids() -> PackedStringArray:
	if _market != null and _market.has_method("get_market_item_ids"):
		return _market.call("get_market_item_ids")
	return PackedStringArray()


func _market_best_buy_order(item_id: String) -> Dictionary:
	if _market != null and _market.has_method("get_best_buy_order"):
		var order: Variant = _market.call("get_best_buy_order", item_id)
		if order is Dictionary:
			return order
	return {}


func _selected_sell_listing() -> Dictionary:
	for listing in _market_sell_listings():
		if int(listing.get("id", 0)) == _selected_listing_id:
			return listing
	return {}


func _selected_inventory_item() -> Dictionary:
	for row in _inventory_item_rows():
		if String(row.get("item_id", "")) == _selected_inventory_item_id:
			return row
	return {}


func _inventory_item_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _inventory == null or not _inventory.has_method("get_display_slots"):
		return rows

	var totals := {}
	for raw_slot in _inventory.call("get_display_slots"):
		if not (raw_slot is Dictionary):
			continue
		var slot := raw_slot as Dictionary
		var item_id := String(slot.get("id", slot.get("item_id", ""))).strip_edges()
		var quantity := int(slot.get("quantity", 0))
		if item_id.is_empty() or quantity <= 0:
			continue
		if not totals.has(item_id):
			totals[item_id] = {
				"item_id": item_id,
				"quantity": 0,
			}
		var row := totals[item_id] as Dictionary
		row["quantity"] = int(row.get("quantity", 0)) + quantity

	for item_id in totals.keys():
		rows.append(totals[item_id])
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _item_name(String(left.get("item_id", ""))) < _item_name(String(right.get("item_id", "")))
	)
	return rows


func _suggest_sell_price(item_id: String) -> int:
	var best_buy := _market_best_buy_order(item_id)
	if not best_buy.is_empty():
		return maxi(int(best_buy.get("price_per_unit", 1)) + 2, 1)
	return _fallback_price(item_id)


func _suggest_buy_price(item_id: String) -> int:
	var best_buy := _market_best_buy_order(item_id)
	if not best_buy.is_empty():
		return maxi(int(best_buy.get("price_per_unit", 1)), 1)
	return maxi(_fallback_price(item_id) - 2, 1)


func _fallback_price(item_id: String) -> int:
	var definition := _definition(item_id)
	var tier := int(definition.get("tier")) if definition != null else 1
	var category := String(definition.get("category")).to_lower() if definition != null else ""
	var family_id := String(definition.get("family_id")) if definition != null else ""
	var base_price := 8
	if category.contains("tool") or category.contains("weapon"):
		base_price = 60
	elif family_id in ["planks", "blocks", "ingots", "cloth", "worked_leather"]:
		base_price = 30
	return base_price * maxi(tier, 1)


func _definition(item_id: String) -> Resource:
	if _inventory != null and _inventory.has_method("get_definition"):
		return _inventory.call("get_definition", item_id) as Resource
	return null


func _item_name(item_id: String) -> String:
	var definition := _definition(item_id)
	if definition != null:
		return String(definition.get("display_name"))
	return _prettify_id(item_id)


func _item_heading(item_id: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = _item_name(item_id)
	UiStyle.label_primary(title, 22, 1)
	box.add_child(title)

	var definition := _definition(item_id)
	if definition != null:
		var description := Label.new()
		description.text = String(definition.get("description"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiStyle.label_muted(description, 13)
		box.add_child(description)
	return box


func _make_section_panel(panel_name: String, minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.custom_minimum_size = minimum_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiStyle.master_menu_detail_panel_style())
	return panel


func _with_margin(child: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.add_child(child)
	return margin


func _make_button(text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_PRIMARY)
	button.add_theme_stylebox_override("normal", UiStyle.master_menu_submenu_button_style(false))
	button.add_theme_stylebox_override("hover", UiStyle.master_menu_submenu_button_style(true))
	button.add_theme_stylebox_override("pressed", UiStyle.master_menu_submenu_button_style(true))
	button.add_theme_stylebox_override("disabled", UiStyle.master_menu_submenu_button_style(false))
	return button


func _make_list_button(text: String, selected: bool) -> Button:
	var button := _make_button(text, Vector2(0.0, 62.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_stylebox_override("normal", UiStyle.master_menu_detail_item_style(selected))
	return button


func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	UiStyle.label_primary(label, 18, 1)
	return label


func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.label_muted(label, 14)
	return label


func _make_spinbox(min_value: int, max_value: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = maxi(max_value, min_value)
	spin.step = 1
	spin.value = clampi(value, min_value, int(spin.max_value))
	spin.custom_minimum_size = Vector2(120.0, 34.0)
	return spin


func _labeled_control(label_text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(95.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_muted(label, 14)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _clear_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _mode_help_text() -> String:
	match _mode:
		Mode.BUY:
			return "Buy from active sell orders."
		Mode.SELL_ORDER:
			return "Post your own item for sale."
		Mode.BUY_ORDER:
			return "Reserve silver to request an item from other players."
		Mode.QUICK_SALE:
			return "Instantly sell into the best matching buy order."
	return ""


func _format_whole_number(value: int) -> String:
	var digits := str(maxi(value, 0))
	var formatted := ""
	var group_count := 0

	for index in range(digits.length() - 1, -1, -1):
		if group_count > 0 and group_count % 3 == 0:
			formatted = ",%s" % formatted
		formatted = "%s%s" % [digits.substr(index, 1), formatted]
		group_count += 1

	return formatted


func _prettify_id(item_id: String) -> String:
	var words := item_id.replace("_", " ").split(" ", false)
	for index in range(words.size()):
		words[index] = String(words[index]).capitalize()
	return " ".join(words)


func _is_world_move_mouse_button_down() -> bool:
	return (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)
