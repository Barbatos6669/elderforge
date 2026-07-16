extends SceneTree

const AbilityTooltipPanelScript := preload("res://scripts/ui/hud/ability_tooltip_panel.gd")
const WeaponAbilityHudScript := preload("res://scripts/ui/hud/weapon_ability_hud.gd")
const MOONLEAF_BINDING := preload("res://assets/combat/abilities/moonleaf_binding.tres")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	root.size = Vector2i(1024, 768)

	var fixture := Control.new()
	fixture.name = "AbilityTooltipLayoutFixture"
	fixture.size = Vector2(1024.0, 768.0)
	root.add_child(fixture)
	current_scene = fixture

	var tooltip := AbilityTooltipPanelScript.new() as AbilityTooltipPanel
	tooltip.set_ability(MOONLEAF_BINDING)
	fixture.add_child(tooltip)

	await process_frame
	await process_frame

	if not _tooltip_panel_wraps_details(tooltip):
		return
	if not await _hud_hint_can_expand_past_center_cell(fixture):
		return

	fixture.queue_free()
	await process_frame
	print("Ability tooltip layout tests passed.")
	quit(0)


func _tooltip_panel_wraps_details(tooltip: AbilityTooltipPanel) -> bool:
	var description := tooltip.get_node_or_null(
		"ContentMargin/TooltipContent/AbilityDescription"
	) as Label
	var effects := tooltip.get_node_or_null(
		"ContentMargin/TooltipContent/AbilityEffects"
	) as GridContainer
	var stats := tooltip.get_node_or_null(
		"ContentMargin/TooltipContent/CombatStats"
	) as GridContainer
	if description == null or effects == null or stats == null:
		_fail("Ability tooltip did not build the expected detail nodes.")
		return false

	if description.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART:
		_fail("Ability tooltip descriptions should wrap instead of clipping.")
		return false
	if effects.columns != 1:
		_fail("Ability tooltip effects should use one full-width column.")
		return false
	if stats.columns != 2:
		_fail("Ability tooltip stats should use one label/value pair per row.")
		return false

	for effect_panel in effects.get_children():
		var row := effect_panel.get_child(0) as GridContainer
		var value := row.get_child(1) as Label
		if value.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART:
			_fail("Ability tooltip effect values should wrap instead of clipping.")
			return false
		if value.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS:
			_fail("Ability tooltip effect values should not trim with ellipsis.")
			return false

	var minimum := tooltip.get_combined_minimum_size()
	if minimum.x < AbilityTooltipPanelScript.TOOLTIP_WIDTH:
		_fail("Ability tooltip minimum width should preserve the authored wrap width.")
		return false
	if minimum.y <= 0.0:
		_fail("Ability tooltip should report enough height for its contents.")
		return false
	return true


func _hud_hint_can_expand_past_center_cell(parent: Node) -> bool:
	var hud := WeaponAbilityHudScript.new() as WeaponAbilityHud
	parent.add_child(hud)
	await process_frame
	await process_frame

	var hint_root := hud.get_node_or_null("AbilityHintRoot") as Control
	if hint_root == null:
		_fail("Weapon ability HUD did not build the hint root.")
		return false
	var hint_panel := hint_root.get_node_or_null("AbilityHintPanel") as Control
	if hint_panel == null:
		_fail("Weapon ability HUD did not build the hint layer.")
		return false
	if hint_root.clip_contents:
		_fail("Ability hint root should allow long tooltips to extend past its cell.")
		return false

	hint_panel.call("set_ability", MOONLEAF_BINDING)
	hint_panel.visible = true
	hud.call("_layout_hint_panel")
	await process_frame

	if (
		hint_root.size.x < AbilityTooltipPanelScript.TOOLTIP_WIDTH
		and hint_panel.size.x <= hint_root.size.x
	):
		_fail("Ability hint panel should size against the viewport, not the center cell.")
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
