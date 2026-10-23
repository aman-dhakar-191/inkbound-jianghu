extends Node
## Speaks story lines. For each line it uses, in order:
##   1. a recorded clip at res://assets/audio/voice/<language>/<key>.ogg
##   2. the phone's text-to-speech in its default voice, pitched and paced
##      per speaker (data/voices.json)
##   3. nothing: say() returns false and the caller times the line itself
## Emits line_finished once when a spoken line ends on its own (not on stop()).
##
## Never call DisplayServer.tts_get_voices(): on some Android phones it aborts
## the whole app (a null array crosses JNI). That crashed v0.1.1 on start.
##
## Crash guard: text-to-speech runs in native code that GDScript can't catch.
## Before the first spoken line of a session a guard file is written, and it is
## removed once speech has started (or a few seconds passed without a crash).
## If the next launch still finds the file, crashed_last_time is set and the
## caller turns voice off, so a phone whose speech engine crashes falls back to
## subtitles instead of crashing on every launch.

signal line_finished

const CLIP_PATH := "res://assets/audio/voice/%s/%s.ogg"
const GUARD_PATH := "user://tts_guard"
## Seconds after the first spoken line before text-to-speech counts as safe.
const GUARD_SECONDS := 4.0
## Text-to-speech volume, 0-100.
const TTS_VOLUME := 80

## Off means subtitles only. Saved by the caller.
var enabled := true
var language := "en"
## Speaker id -> {"pitch": float, "rate": float}, from voices.json.
var speakers := {}
## True when the last session ended while text-to-speech was starting.
var crashed_last_time := false

var _player: AudioStreamPlayer
var _tts := false
var _guard_done := false
var _utterance := 0
var _speaking := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_finish)
	if FileAccess.file_exists(GUARD_PATH):
		crashed_last_time = true
		DirAccess.remove_absolute(GUARD_PATH)
	_tts = DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)
	if _tts:
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_STARTED, _on_tts_started)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_ended)


## True when this device can speak lines that have no recorded clip.
func has_tts() -> bool:
	return _tts


## Starts speaking a line, cutting off any line still playing. Returns false
## when nothing will be heard (voice off, no clip and no text-to-speech).
func say(key: String, text: String, speaker: String) -> bool:
	stop()
	if not enabled:
		return false
	var clip := CLIP_PATH % [language, key]
	if ResourceLoader.exists(clip):
		_player.stream = load(clip)
		_speaking = true
		_player.play()
		return true
	if not _tts:
		return false
	var s: Dictionary = speakers.get(speaker, speakers.get("narrator", {}))
	_utterance += 1
	_speaking = true
	_arm_guard()
	# An empty voice id means the phone's default voice.
	DisplayServer.tts_speak(text, "", TTS_VOLUME, float(s.get("pitch", 1.0)), float(s.get("rate", 1.0)), _utterance, true)
	return true


func stop() -> void:
	if not _speaking:
		return
	_speaking = false
	_player.stop()
	if _tts:
		DisplayServer.tts_stop()


func _arm_guard() -> void:
	if _guard_done:
		return
	_guard_done = true
	var f := FileAccess.open(GUARD_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("speaking")
		f.close()
	get_tree().create_timer(GUARD_SECONDS).timeout.connect(_clear_guard)


func _clear_guard() -> void:
	if FileAccess.file_exists(GUARD_PATH):
		DirAccess.remove_absolute(GUARD_PATH)


## Text-to-speech callbacks may arrive off the main thread.
func _on_tts_started(_id: int) -> void:
	_clear_guard.call_deferred()


func _on_tts_ended(id: int) -> void:
	if id == _utterance:
		_finish.call_deferred()


func _finish() -> void:
	if not _speaking:
		return
	_speaking = false
	line_finished.emit()
