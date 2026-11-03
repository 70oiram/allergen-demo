class_name DebugShot
## 測試用截圖工具，只在命令列帶 --shot 時使用。輸出到 user://shots/


static func save(vp: Viewport, name: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	var path := "user://shots/%s.png" % name
	vp.get_texture().get_image().save_png(path)
	print("SHOT ", ProjectSettings.globalize_path(path))
