extends SceneTree

const DIRECTOR := preload("res://scripts/audio_director.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("[AUDIO_FAIL] " + message)

func _run() -> void:
	var director = root.get_node_or_null("AudioDirector")
	if director == null:
		director = DIRECTOR.new()
		director.settings_path = "user://audio-test-%d.json" % Time.get_ticks_usec()
		root.add_child(director)
	else:
		director.settings_path = "user://audio-test-%d.json" % Time.get_ticks_usec()
		director.load_settings()
	await process_frame
	_expect(director.has_music(), "approved game-specific soundtrack is configured")
	_expect(director.music_stream is AudioStreamOggVorbis and director.music_stream.loop, "native soundtrack is an imported looping OGG")
	_expect(absf(director.music_stream.get_length() - 91.2) < 0.01, "runtime loop duration survives import")
	for channel: String in director.CHANNELS:
		_expect(AudioServer.get_bus_index(channel) >= 0, "bus exists: " + channel)
	_expect(director._voices.SFX.size() == 8 and director._voices.UI.size() == 3, "fixed separate SFX and UI pools")
	_expect(director._streams.size() == director.CUES.size(), "every semantic cue is cached")
	for cue: String in director._streams:
		var stream: AudioStreamWAV = director._streams[cue]
		_expect(stream.data.size() >= 400 and stream.get_length() < 0.5, "short nonempty PCM: " + cue)
		_expect(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, "clean attack/tail: " + cue)
		var peak := 0
		for offset in range(0, stream.data.size(), 2):
			peak = maxi(peak, absi(stream.data.decode_s16(offset)))
		_expect(peak > 500 and peak < 30000, "audible, unclipped source: " + cue)
	_expect(not director.play(&"missing"), "unknown cues fail safely")
	_expect(director.play(&"jump"), "gameplay cue starts")
	_expect(not director.play(&"jump"), "same-frame bounce is rate limited")
	for cue: String in director.CUES:
		director.play(StringName(cue))
	_expect(director._voices.SFX.filter(func(voice): return voice.playing).size() <= 8, "burst remains within SFX cap")
	_expect(director._voices.UI.filter(func(voice): return voice.playing).size() <= 3, "burst remains within UI cap")
	director.set_paused(true)
	_expect(not director.play(&"collect_star"), "paused gameplay emits no new cue")
	for voice: AudioStreamPlayer in director._voices.SFX:
		_expect(voice.stream_paused, "existing gameplay voice freezes")
	director._last_played.erase("ui_back")
	_expect(director.play(&"ui_back"), "pause menu UI remains audible")
	director.clear_run_audio()
	_expect(not director._paused, "retry clears audio pause")
	for voice: AudioStreamPlayer in director._voices.SFX:
		_expect(not voice.playing, "retry clears old gameplay voice")
	_expect(director.play(&"jump"), "retry clears old run cue cooldown")

	var button := Button.new()
	root.add_child(button)
	director.bind_ui(button)
	director.bind_ui(button)
	_expect(button.pressed.get_connections().size() == 1, "controls are wired once")
	_expect(button.mouse_entered.get_connections().size() == 1 and button.focus_entered.get_connections().size() == 1, "hover and focus wired once")
	director._last_played.erase("ui_confirm")
	button.pressed.emit()
	_expect(director._last_played.has("ui_confirm"), "button activation reaches semantic registry")
	button.disabled = true
	director._last_played.erase("ui_confirm")
	button.pressed.emit()
	_expect(not director._last_played.has("ui_confirm"), "disabled controls do not emit activation cues")
	button.queue_free()

	_expect(director.set_volume("SFX", 0.42) and director.set_muted(true), "player settings persist")
	_expect(not director.set_volume("SFX", -1.0) and not director.set_volume("SFX", NAN) and not director.set_volume("unrecognized", 0.5), "invalid volume never applies")
	_expect(is_equal_approx(director.get_volume("SFX"), 0.42), "invalid value preserves prior volume")
	director.volumes.SFX = 0.1
	director.muted = false
	director.load_settings()
	_expect(is_equal_approx(director.get_volume("SFX"), 0.42) and director.is_muted(), "saved mute/volume round trip")
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "mute reaches actual mix")
	var file := FileAccess.open(director.settings_path, FileAccess.WRITE)
	file.store_string('{"version":1,"volumes":{"Music":"loud","SFX":999,"UI":0.2},"muted":"yes"}')
	file.close()
	director.load_settings()
	_expect(director.get_volume("Music") == director.DEFAULT_VOLUMES.Music and director.get_volume("SFX") == director.DEFAULT_VOLUMES.SFX, "malformed settings restore safe per-field defaults")
	_expect(is_equal_approx(director.get_volume("UI"), 0.2) and not director.is_muted(), "valid settings survive malformed neighbors")
	var saved_path: String = director.settings_path
	director.settings_path = "user://audio-missing-%d/settings.json" % Time.get_ticks_usec()
	_expect(not director.set_volume("UI", 0.3) and not director.settings_saved, "failed persistence reports failure without losing session preference")
	_expect(is_equal_approx(director.get_volume("UI"), 0.3), "session preference remains active after failed save")

	director.configure_music(null)
	_expect(not director.has_music() and not director.start_music(), "missing approved music remains an empty safe route")
	# This short fixture is test-only. It is never configured as runtime music.
	director.configure_music(director._streams["collect_star"])
	var music_id: int = director._music.get_instance_id()
	director._unlocked = false
	_expect(not director.start_music(), "music waits for first gesture")
	var gesture := InputEventMouseButton.new()
	gesture.pressed = true
	director._input(gesture)
	_expect(director._music.playing, "gesture starts pending music")
	director.start_music()
	director.start_music()
	_expect(director._music.get_instance_id() == music_id, "repeated scene routes reuse one music voice")
	director.set_paused(true)
	_expect(director._music.stream_paused, "pause freezes music")
	director.set_paused(false)
	_expect(not director._music.stream_paused, "resume restores music")
	director.stop_music(0.0)
	_expect(not director._music.playing and not director._music_requested, "stop clears playback and pending request")
	director.configure_music(null)
	director.queue_free()
	await process_frame
	# Give the audio thread time to release stopped native playbacks.
	await create_timer(0.15).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
	print("[AUDIO_%s] cached semantic cues, bounded voices, pause/retry, UI wiring, settings and music lifecycle" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
