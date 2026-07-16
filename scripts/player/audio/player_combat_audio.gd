## Plays positional combat one-shots for the reusable player prefab.
##
## Swing playback follows attack-start signals. Impact playback follows landed
## signals, so rapid input cannot create extra hit sounds between animations.
## Hurt playback follows confirmed health loss and therefore also works for
## replicated damage on remote player copies.
class_name PlayerCombatAudio
extends Node

signal sound_played(sound_type: StringName)

@export var sound_set: CombatSoundSet

@export_group("Sources")
@export var auto_attack_path := NodePath("../AutoAttack")
@export var weapon_abilities_path := NodePath("../WeaponAbilities")
@export var health_path := NodePath("../Health")

@export_group("Players")
@export var swing_player_path := NodePath("Swing")
@export var impact_player_path := NodePath("Impact")
@export var hurt_player_path := NodePath("Hurt")

@onready var _swing_player := get_node_or_null(swing_player_path) as AudioStreamPlayer3D
@onready var _impact_player := get_node_or_null(impact_player_path) as AudioStreamPlayer3D
@onready var _hurt_player := get_node_or_null(hurt_player_path) as AudioStreamPlayer3D

var _next_stream_indices := {
	&"swing": 0,
	&"impact": 0,
	&"hurt": 0,
}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_bind_combat_signals()


## Plays the active weapon's swing cue. Remote-player replication can call this
## directly because visual-only copies do not run their local attack component.
func play_swing() -> void:
	if sound_set == null or not sound_set.has_swing_streams():
		return
	_play_one_shot(
		&"swing",
		_swing_player,
		sound_set.swing_streams,
		sound_set.swing_volume_db
	)


## Plays the weapon-on-target layer after confirmed damage.
func play_impact() -> void:
	if sound_set == null or not sound_set.has_impact_streams():
		return
	_play_one_shot(
		&"impact",
		_impact_player,
		sound_set.impact_streams,
		sound_set.impact_volume_db
	)


## Plays a non-voiced hurt layer after this character loses health.
func play_hurt() -> void:
	if sound_set == null or not sound_set.has_hurt_streams():
		return
	_play_one_shot(
		&"hurt",
		_hurt_player,
		sound_set.hurt_streams,
		sound_set.hurt_volume_db
	)


func _bind_combat_signals() -> void:
	var auto_attack := get_node_or_null(auto_attack_path)
	_connect_if_available(auto_attack, &"attack_started", _on_attack_started)
	_connect_if_available(auto_attack, &"attack_landed", _on_attack_landed)

	var weapon_abilities := get_node_or_null(weapon_abilities_path)
	_connect_if_available(
		weapon_abilities,
		&"ability_cast_started",
		_on_ability_cast_started
	)
	_connect_if_available(
		weapon_abilities,
		&"ability_cast_landed",
		_on_ability_cast_landed
	)

	var health := get_node_or_null(health_path)
	_connect_if_available(health, &"damage_taken", _on_damage_taken)


func _connect_if_available(source: Node, signal_name: StringName, callback: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _on_attack_started(_target: Node) -> void:
	play_swing()


func _on_attack_landed(_target: Node, _damage: float) -> void:
	play_impact()


func _on_ability_cast_started(
	_slot_id: StringName,
	_target: Node,
	definition: Resource
) -> void:
	if definition != null and String(definition.get("execution_type")) == "dodge":
		return
	play_swing()


func _on_ability_cast_landed(
	_slot_id: StringName,
	_target: Node,
	_damage: float
) -> void:
	play_impact()


func _on_damage_taken(_amount: float) -> void:
	play_hurt()


func _play_one_shot(
	sound_type: StringName,
	player: AudioStreamPlayer3D,
	streams: Array[AudioStream],
	volume_db: float
) -> void:
	if player == null or streams.is_empty():
		return

	var stream_index := int(_next_stream_indices.get(sound_type, 0)) % streams.size()
	player.stream = streams[stream_index]
	_next_stream_indices[sound_type] = (stream_index + 1) % streams.size()
	player.volume_db = volume_db
	player.pitch_scale = _rng.randf_range(
		1.0 - sound_set.pitch_variation,
		1.0 + sound_set.pitch_variation
	)
	player.stop()
	player.play()
	sound_played.emit(sound_type)
