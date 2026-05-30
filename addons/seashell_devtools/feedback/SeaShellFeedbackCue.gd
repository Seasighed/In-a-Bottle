@tool
extends Resource
class_name SeaShellFeedbackCue

const VISUAL_NONE := "None"
const VISUAL_PULSE := "Pulse"
const VISUAL_SHAKE := "Shake"
const VISUAL_FLASH := "Flash"

@export var CueId := ""
@export var EventIds := PackedStringArray()
@export var Description := ""
@export var AudioFrequencies := PackedFloat32Array()
@export var AudioDurations := PackedFloat32Array()
@export var AudioWaveforms := PackedStringArray()
@export_range(0.0, 1.0, 0.01) var AudioAmplitude := 0.12
@export var PitchMin := 1.0
@export var PitchMax := 1.0
@export var VolumeMultiplier := 1.0
@export_enum("None", "Pulse", "Shake", "Flash") var VisualEffect := VISUAL_NONE
@export var Duration := 0.18
@export var ScaleAmount := 0.08
@export var ShakeAmplitude := 5.0
@export var FlashColor := Color(1.0, 1.0, 1.0, 0.92)
@export var ProtectedTime := 0.0

func matches_event(event_id: String) -> bool:
	return EventIds.has(event_id)

func estimated_duration() -> float:
	return maxf(Duration, ProtectedTime)
