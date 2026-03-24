class_name SurveyUiFeedback
extends Node

const GROUP_NAME := "survey_ui_feedback"
const MIX_RATE := 22050
const DEFAULT_SFX_VOLUME := 0.35
const MIN_AUDIBLE_VOLUME := 0.0001
const SILENT_DB := -80.0

var _hover_player: AudioStreamPlayer
var _select_player: AudioStreamPlayer
var _answer_player: AudioStreamPlayer
var _export_player: AudioStreamPlayer
var _gamble_player: AudioStreamPlayer
var _menu_open_player: AudioStreamPlayer
var _menu_close_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _sfx_volume := DEFAULT_SFX_VOLUME

func _ready() -> void:
	add_to_group(GROUP_NAME)
	_rng.randomize()
	_hover_player = _create_player(_build_tone_stream(PackedFloat32Array([920.0]), PackedFloat32Array([0.028]), 0.12))
	_select_player = _create_player(_build_tone_stream(PackedFloat32Array([620.0, 860.0]), PackedFloat32Array([0.038, 0.045]), 0.14))
	_answer_player = _create_player(_build_tone_stream(PackedFloat32Array([760.0, 1040.0]), PackedFloat32Array([0.03, 0.05]), 0.15))
	_export_player = _create_player(_build_tone_stream(PackedFloat32Array([560.0, 760.0, 1040.0]), PackedFloat32Array([0.04, 0.05, 0.07]), 0.18))
	_gamble_player = _create_player(_build_tone_stream(PackedFloat32Array([1120.0]), PackedFloat32Array([0.024]), 0.11))
	_menu_open_player = _create_player(_build_tone_stream(PackedFloat32Array([180.0, 240.0]), PackedFloat32Array([0.06, 0.08]), 0.18))
	_menu_close_player = _create_player(_build_tone_stream(PackedFloat32Array([240.0, 170.0]), PackedFloat32Array([0.05, 0.09]), 0.18))
	_apply_volume_to_players()

static func play_hover() -> void:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		hub._play_player(hub._hover_player, 0.94, 1.01)

static func play_option_hover() -> void:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		hub._play_player(hub._hover_player, 1.12, 1.22)

static func play_select() -> void:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		hub._play_player(hub._select_player, 0.96, 1.03)

static func play_answer_select() -> void:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		hub._play_player(hub._answer_player, 0.97, 1.05)

static func play_export() -> void:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		hub._play_player(hub._export_player, 0.985, 1.025)

static func play_gamble_spin_tick(progress: float) -> void:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		var resolved_progress: float = clampf(progress, 0.0, 1.0)
		var pitch: float = lerpf(1.42, 0.78, resolved_progress)
		hub._play_player(hub._gamble_player, pitch, pitch)

static func play_menu_open() -> void:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		hub._play_player(hub._menu_open_player, 0.99, 1.04)

static func play_menu_close() -> void:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		hub._play_player(hub._menu_close_player, 0.92, 0.98)

static func set_sfx_volume(volume: float) -> void:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		hub._set_sfx_volume(volume)

static func get_sfx_volume() -> float:
	var hub: SurveyUiFeedback = _get_hub()
	if hub != null:
		return hub._sfx_volume
	return DEFAULT_SFX_VOLUME

static func pulse(control: Control, scale_amount: float = 0.08, duration: float = 0.18) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var tween: Tween = control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * (1.0 + scale_amount), duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func _get_hub() -> SurveyUiFeedback:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP_NAME) as SurveyUiFeedback

func _set_sfx_volume(volume: float) -> void:
	_sfx_volume = clampf(volume, 0.0, 1.0)
	_apply_volume_to_players()

func _apply_volume_to_players() -> void:
	for player in [_hover_player, _select_player, _answer_player, _export_player, _gamble_player, _menu_open_player, _menu_close_player]:
		_apply_volume_to_player(player)

func _apply_volume_to_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.volume_db = SILENT_DB if _sfx_volume <= MIN_AUDIBLE_VOLUME else linear_to_db(_sfx_volume)

func _create_player(stream: AudioStream) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = &"Master"
	player.stream = stream
	add_child(player)
	return player

func _play_player(player: AudioStreamPlayer, min_pitch: float = 1.0, max_pitch: float = 1.0) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.pitch_scale = _rng.randf_range(min_pitch, max_pitch) if not is_equal_approx(min_pitch, max_pitch) else min_pitch
	player.play()

func _build_tone_stream(frequencies: PackedFloat32Array, durations: PackedFloat32Array, amplitude: float) -> AudioStreamWAV:
	var pcm: PackedByteArray = PackedByteArray()
	for index in range(mini(frequencies.size(), durations.size())):
		_append_tone(pcm, frequencies[index], durations[index], amplitude)
		_append_silence(pcm, 0.01)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.mix_rate = MIX_RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.data = pcm
	return stream

func _append_tone(pcm: PackedByteArray, frequency: float, duration: float, amplitude: float) -> void:
	var sample_count: int = int(MIX_RATE * duration)
	for sample_index in range(sample_count):
		var t: float = float(sample_index) / float(MIX_RATE)
		var envelope: float = 1.0
		if sample_count > 1:
			var edge: float = minf(t / duration, (duration - t) / duration) * 4.0
			envelope = clampf(edge, 0.0, 1.0)
		var sample_value: float = sin(TAU * frequency * t) * amplitude * envelope
		_append_sample(pcm, sample_value)

func _append_silence(pcm: PackedByteArray, duration: float) -> void:
	var sample_count: int = int(MIX_RATE * duration)
	for _i in range(sample_count):
		_append_sample(pcm, 0.0)

func _append_sample(pcm: PackedByteArray, sample_value: float) -> void:
	var clamped: float = clampf(sample_value, -1.0, 1.0)
	var sample_int: int = int(round(clamped * 32767.0))
	if sample_int < 0:
		sample_int += 65536
	pcm.append(sample_int & 255)
	pcm.append((sample_int >> 8) & 255)






