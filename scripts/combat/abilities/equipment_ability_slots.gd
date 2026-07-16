## Canonical action-bar ownership for equipment-provided active abilities.
##
## Weapons own Q/W/E, chest armor owns R, helmets own D, and boots own F.
## Weapon passives are intentionally absent because they do not require a cast
## key. The two numbered HUD entries remain reserved for future utility slots.
class_name EquipmentAbilitySlots
extends RefCounted

const WEAPON_SLOT_IDS: Array[StringName] = [&"q", &"w", &"e"]
const CHEST_SLOT_ID := &"r"
const HELMET_SLOT_ID := &"d"
const BOOTS_SLOT_ID := &"f"
const ACTIVE_SLOT_IDS: Array[StringName] = [
	&"q",
	&"w",
	&"e",
	CHEST_SLOT_ID,
	HELMET_SLOT_ID,
	BOOTS_SLOT_ID,
]
const HUD_SLOT_IDS: Array[StringName] = [
	&"q",
	&"w",
	&"e",
	CHEST_SLOT_ID,
	HELMET_SLOT_ID,
	BOOTS_SLOT_ID,
	&"1",
	&"2",
]
const INPUT_KEY_BY_SLOT := {
	&"q": KEY_Q,
	&"w": KEY_W,
	&"e": KEY_E,
	CHEST_SLOT_ID: KEY_R,
	HELMET_SLOT_ID: KEY_D,
	BOOTS_SLOT_ID: KEY_F,
}
const KEY_HINT_BY_SLOT := {
	&"q": "Q",
	&"w": "W",
	&"e": "E",
	CHEST_SLOT_ID: "R",
	HELMET_SLOT_ID: "D",
	BOOTS_SLOT_ID: "F",
	&"1": "1",
	&"2": "2",
}
const EQUIPMENT_SLOT_BY_ABILITY := {
	"q": "main_hand",
	"w": "main_hand",
	"e": "main_hand",
	"r": "chest",
	"d": "head",
	"f": "shoes",
}
