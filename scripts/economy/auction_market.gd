## Prototype in-memory auction house market.
##
## This is intentionally a small economy service, not UI code. The auction UI
## asks this singleton to create orders, buy listings, or quick-sell into buy
## orders. Later this API can move behind server RPC/database calls without
## rewriting the panel.
extends Node

signal market_changed
signal transaction_message(message: String)

const MAX_ORDER_QUANTITY := 999
const MAX_UNIT_PRICE := 999999

var _next_order_id := 1
var _sell_listings: Array[Dictionary] = []
var _buy_orders: Array[Dictionary] = []


func _ready() -> void:
	if _sell_listings.is_empty() and _buy_orders.is_empty():
		_seed_market()


func get_sell_listings() -> Array[Dictionary]:
	return _sorted_orders(_sell_listings, true)


func get_buy_orders() -> Array[Dictionary]:
	return _sorted_orders(_buy_orders, false)


func get_market_item_ids() -> PackedStringArray:
	var ids := PackedStringArray([
		"timber_t1",
		"stone_t1",
		"ore_t1",
		"cotton_t1",
		"hide_t1",
		"planks_t1",
		"blocks_t1",
		"ingots_t1",
		"cloth_t1",
		"worked_leather_t1",
		"axe_t4",
		"hammer_t4",
		"pickaxe_t4",
		"sickle_t4",
		"skinning_knife_t4",
		"one_handed_sword_t1",
	])
	return ids


func get_best_buy_order(item_id: String) -> Dictionary:
	var clean_item_id := item_id.strip_edges()
	if clean_item_id.is_empty():
		return {}

	var best_order := {}
	for order in _buy_orders:
		if String(order.get("item_id", "")) != clean_item_id:
			continue
		if int(order.get("quantity", 0)) <= 0:
			continue
		if best_order.is_empty() or int(order.get("price_per_unit", 0)) > int(best_order.get("price_per_unit", 0)):
			best_order = order

	return best_order.duplicate(true)


func buy_listing(listing_id: int, quantity: int, inventory: Node) -> Dictionary:
	var listing := _find_order(_sell_listings, listing_id)
	var safe_quantity := _safe_quantity(quantity)
	if listing.is_empty() or safe_quantity <= 0:
		return _result(false, "That listing is no longer available.")
	if inventory == null:
		return _result(false, "No player inventory found.")

	var item_id := String(listing.get("item_id", ""))
	var available_quantity := int(listing.get("quantity", 0))
	var moved_quantity := mini(safe_quantity, available_quantity)
	var total_price := moved_quantity * int(listing.get("price_per_unit", 0))
	if moved_quantity <= 0:
		return _result(false, "That listing is empty.")
	if int(inventory.call("get_silver")) < total_price:
		return _result(false, "Not enough silver.")
	if int(inventory.call("get_addable_count", item_id)) < moved_quantity:
		return _result(false, "Not enough inventory space.")

	_set_inventory_silver(inventory, int(inventory.call("get_silver")) - total_price)
	var remainder := int(inventory.call("add_item", item_id, moved_quantity))
	if remainder > 0:
		# This should be rare because we preflight capacity. Refund anything that
		# did not fit so the prototype cannot eat items.
		var delivered := moved_quantity - remainder
		_set_inventory_silver(inventory, int(inventory.call("get_silver")) + remainder * int(listing.get("price_per_unit", 0)))
		moved_quantity = delivered

	listing["quantity"] = available_quantity - moved_quantity
	_prune_empty_orders(_sell_listings)
	_emit_market_message("Bought %d x %s." % [moved_quantity, item_id])
	return _result(true, "Bought %d item(s)." % moved_quantity)


func create_sell_order(item_id: String, quantity: int, price_per_unit: int, inventory: Node, seller_id := "player") -> Dictionary:
	var clean_item_id := item_id.strip_edges()
	var safe_quantity := _safe_quantity(quantity)
	var safe_price := _safe_price(price_per_unit)
	if clean_item_id.is_empty() or safe_quantity <= 0:
		return _result(false, "Choose an item and quantity.")
	if safe_price <= 0:
		return _result(false, "Price must be at least 1 silver.")
	if inventory == null:
		return _result(false, "No player inventory found.")
	if int(inventory.call("get_item_count", clean_item_id)) < safe_quantity:
		return _result(false, "You do not have enough of that item.")

	var not_removed := int(inventory.call("remove_item", clean_item_id, safe_quantity))
	if not_removed > 0:
		return _result(false, "Could not remove the full stack from inventory.")

	_sell_listings.append(_make_order(clean_item_id, safe_quantity, safe_price, seller_id))
	_emit_market_message("Posted %d x %s for %d silver each." % [safe_quantity, clean_item_id, safe_price])
	return _result(true, "Sell order posted.")


func create_buy_order(item_id: String, quantity: int, price_per_unit: int, inventory: Node, buyer_id := "player") -> Dictionary:
	var clean_item_id := item_id.strip_edges()
	var safe_quantity := _safe_quantity(quantity)
	var safe_price := _safe_price(price_per_unit)
	var total_price := safe_quantity * safe_price
	if clean_item_id.is_empty() or safe_quantity <= 0:
		return _result(false, "Choose an item and quantity.")
	if safe_price <= 0:
		return _result(false, "Price must be at least 1 silver.")
	if inventory == null:
		return _result(false, "No player inventory found.")
	if int(inventory.call("get_silver")) < total_price:
		return _result(false, "Not enough silver to reserve that order.")

	_set_inventory_silver(inventory, int(inventory.call("get_silver")) - total_price)
	_buy_orders.append(_make_order(clean_item_id, safe_quantity, safe_price, buyer_id))
	_emit_market_message("Posted buy order for %d x %s." % [safe_quantity, clean_item_id])
	return _result(true, "Buy order posted.")


func quick_sell(item_id: String, quantity: int, inventory: Node) -> Dictionary:
	var clean_item_id := item_id.strip_edges()
	var safe_quantity := _safe_quantity(quantity)
	if clean_item_id.is_empty() or safe_quantity <= 0:
		return _result(false, "Choose an item and quantity.")
	if inventory == null:
		return _result(false, "No player inventory found.")
	if int(inventory.call("get_item_count", clean_item_id)) < safe_quantity:
		return _result(false, "You do not have enough of that item.")

	var best_order := _find_best_buy_order(clean_item_id)
	if best_order.is_empty():
		return _result(false, "No buy order exists for that item.")

	var moved_quantity := mini(safe_quantity, int(best_order.get("quantity", 0)))
	var not_removed := int(inventory.call("remove_item", clean_item_id, moved_quantity))
	if not_removed > 0:
		return _result(false, "Could not remove the full stack from inventory.")

	var payout := moved_quantity * int(best_order.get("price_per_unit", 0))
	_set_inventory_silver(inventory, int(inventory.call("get_silver")) + payout)
	best_order["quantity"] = int(best_order.get("quantity", 0)) - moved_quantity
	_prune_empty_orders(_buy_orders)
	_emit_market_message("Quick sold %d x %s for %d silver." % [moved_quantity, clean_item_id, payout])
	return _result(true, "Quick sale complete: +%d silver." % payout)


func _seed_market() -> void:
	_add_seed_sell("timber_t1", 80, 8)
	_add_seed_sell("stone_t1", 80, 7)
	_add_seed_sell("ore_t1", 60, 11)
	_add_seed_sell("cotton_t1", 80, 8)
	_add_seed_sell("hide_t1", 40, 10)
	_add_seed_sell("planks_t1", 25, 36)
	_add_seed_sell("blocks_t1", 25, 32)
	_add_seed_sell("ingots_t1", 25, 44)
	_add_seed_sell("cloth_t1", 25, 34)
	_add_seed_sell("axe_t4", 2, 240)
	_add_seed_sell("pickaxe_t4", 2, 240)

	_add_seed_buy("timber_t1", 100, 5)
	_add_seed_buy("stone_t1", 100, 4)
	_add_seed_buy("ore_t1", 80, 7)
	_add_seed_buy("cotton_t1", 100, 5)
	_add_seed_buy("hide_t1", 60, 6)


func _add_seed_sell(item_id: String, quantity: int, price_per_unit: int) -> void:
	_sell_listings.append(_make_order(item_id, quantity, price_per_unit, "market_seed"))


func _add_seed_buy(item_id: String, quantity: int, price_per_unit: int) -> void:
	_buy_orders.append(_make_order(item_id, quantity, price_per_unit, "market_seed"))


func _make_order(item_id: String, quantity: int, price_per_unit: int, owner_id: String) -> Dictionary:
	var order := {
		"id": _next_order_id,
		"item_id": item_id.strip_edges(),
		"quantity": _safe_quantity(quantity),
		"price_per_unit": _safe_price(price_per_unit),
		"owner_id": owner_id.strip_edges(),
	}
	_next_order_id += 1
	return order


func _find_order(orders: Array[Dictionary], order_id: int) -> Dictionary:
	for order in orders:
		if int(order.get("id", 0)) == order_id:
			return order

	return {}


func _find_best_buy_order(item_id: String) -> Dictionary:
	var best_order := {}
	for order in _buy_orders:
		if String(order.get("item_id", "")) != item_id:
			continue
		if int(order.get("quantity", 0)) <= 0:
			continue
		if best_order.is_empty() or int(order.get("price_per_unit", 0)) > int(best_order.get("price_per_unit", 0)):
			best_order = order

	return best_order


func _sorted_orders(source_orders: Array[Dictionary], cheapest_first: bool) -> Array[Dictionary]:
	var orders := source_orders.duplicate(true)
	orders.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_price := int(left.get("price_per_unit", 0))
		var right_price := int(right.get("price_per_unit", 0))
		if left_price == right_price:
			return int(left.get("id", 0)) < int(right.get("id", 0))
		return left_price < right_price if cheapest_first else left_price > right_price
	)
	return orders


func _prune_empty_orders(orders: Array[Dictionary]) -> void:
	for index in range(orders.size() - 1, -1, -1):
		if int(orders[index].get("quantity", 0)) <= 0:
			orders.remove_at(index)


func _set_inventory_silver(inventory: Node, silver: int) -> void:
	inventory.call("set_currency", maxi(silver, 0), int(inventory.call("get_gold")))


func _emit_market_message(message: String) -> void:
	market_changed.emit()
	transaction_message.emit(message)


func _result(ok: bool, message: String) -> Dictionary:
	if not ok:
		transaction_message.emit(message)
	return {
		"ok": ok,
		"message": message,
	}


func _safe_quantity(quantity: int) -> int:
	return clampi(quantity, 0, MAX_ORDER_QUANTITY)


func _safe_price(price_per_unit: int) -> int:
	return clampi(price_per_unit, 0, MAX_UNIT_PRICE)
