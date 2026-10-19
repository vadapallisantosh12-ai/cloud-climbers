extends "res://scripts/manus/preview/tuning_transport.gd"

func store() -> Variant:
	return get_node_or_null("/root/TuningStore")

func settings() -> Array:
	return store().descriptors()

func requested(setting: Dictionary) -> Variant:
	return store().get_requested_value(str(setting.id))

func active(setting: Dictionary) -> Variant:
	return store().get_value(str(setting.id))

func commit(patch: Dictionary) -> bool:
	return store().apply_preview_patch(patch)

func control_for(setting: Dictionary) -> Dictionary:
	var localized := setting.duplicate(true)
	localized["category_key"] = "tweak.category." + str(setting.category)
	if not str(setting.get("unit", "")).is_empty(): localized["unit_key"] = "tweak.unit." + str(setting.unit)
	return super.control_for(localized)
