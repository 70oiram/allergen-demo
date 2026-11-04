extends Node
## 玩家設定（自動載入）：主音量／音樂／音效三條音訊匯流排的音量，存於 user://settings.cfg

const PATH := "user://settings.cfg"
const MUSIC := "Music"
const SFX := "SFX"
const BUSES := ["Master", MUSIC, SFX]

var volumes := {"Master": 1.0, MUSIC: 1.0, SFX: 1.0}   # 0.0–1.0（線性）


func _ready() -> void:
	for b in [MUSIC, SFX]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for b in BUSES:
			volumes[b] = clampf(cfg.get_value("audio", b, 1.0), 0.0, 1.0)
	for b in BUSES:
		_apply(b)


func set_volume(bus: String, v: float) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	_apply(bus)


func save() -> void:
	var cfg := ConfigFile.new()
	for b in BUSES:
		cfg.set_value("audio", b, volumes[b])
	cfg.save(PATH)


func _apply(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	var v: float = volumes[bus]
	AudioServer.set_bus_mute(i, v <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
