extends Node
## Speaks story lines. For each line it uses, in order:
##   1. a recorded clip at res://assets/audio/voice/<language>/<key>.ogg
##   2. the phone's text-to-speech, pitched per speaker (data/voices.json)
##   3. nothing: say() returns false and the caller times the line itself
## Emits line_finished once when a spoken line ends on its own (not on stop()).

signal line_finished

const CLIP_PATH := "res://assets/audio/voice/%s/%s.ogg"
## Text-to-speech volume, 0-100.
const TTS_VOLUME := 80

## Off means subtitles only. Saved by the caller.
var enabled := true
var language := "en"
## Speaker id -> {"pitch": float, "rate": float, "voice": int}, from voices.json.
var speakers := {}

var _player: AudioStreamPlayer
var _tts_voices := PackedStringArray()
var _utterance := 0
var _speaking := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_finish)
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		_tts_voices = DisplayServer.tts_get_voices_for_language(language)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_ended)


## True when this device can speak lines that have no recorded clip.
func has_tts() -> bool:
	return not _tts_voices.is_empty()


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
	if _tts_voices.is_empty():
		return false
	var s: Dictionary = speakers.get(speaker, speakers.get("narrator", {}))
	var voice := _tts_voices[int(s.get("voice", 0)) % _tts_voices.size()]
	_utterance += 1
	_speaking = true
	DisplayServer.tts_speak(text, voice, TTS_VOLUME, float(s.get("pitch", 1.0)), float(s.get("rate", 1.0)), _utterance, true)
	return true


func stop() -> void:
	if not _speaking:
		return
	_speaking = false
	_player.stop()
	if has_tts():
		DisplayServer.tts_stop()


## Called by the text-to-speech engine, possibly off the main thread.
func _on_tts_ended(id: int) -> void:
	if id == _utterance:
		_finish.call_deferred()


func _finish() -> void:
	if not _speaking:
		return
	_speaking = false
	line_finished.emit()
