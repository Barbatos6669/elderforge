## Small shared helper for temporary mouse cursor overrides.
##
## Hover and UI systems can request a custom cursor without knowing who else
## might be using one. Only the node that owns the active override can clear it.
class_name CursorOverride
extends RefCounted

static var _owner: Object
static var _cursor_shape := Input.CURSOR_ARROW


## Applies a custom cursor while `owner` is active.
static func request(owner: Object, texture: Texture2D, hotspot: Vector2, cursor_shape := Input.CURSOR_ARROW) -> void:
	if owner == null or texture == null:
		return

	_owner = owner
	_cursor_shape = cursor_shape
	Input.set_custom_mouse_cursor(texture, cursor_shape, hotspot)


## Clears the cursor only when `owner` currently owns the override.
static func release(owner: Object) -> void:
	if owner != _owner:
		return

	var previous_shape := _cursor_shape
	_owner = null
	_cursor_shape = Input.CURSOR_ARROW
	Input.set_custom_mouse_cursor(null, previous_shape)


## Clears the cursor regardless of owner. Use this sparingly for scene teardown.
static func release_all() -> void:
	var previous_shape := _cursor_shape
	_owner = null
	_cursor_shape = Input.CURSOR_ARROW
	Input.set_custom_mouse_cursor(null, previous_shape)
