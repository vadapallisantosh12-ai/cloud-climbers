extends SceneTree

const Store = preload("res://scripts/tuning_store.gd")
const Catalog = preload("res://scripts/tweak_catalog.gd")
var failures: Array[String] = []

class OverlayOwner extends Node:
    var overlay := ""
    func open_overlay(id: String) -> void:
        overlay = id
    func close_overlay(id: String) -> void:
        if overlay == id:
            overlay = ""

func _init() -> void:
    call_deferred("_run")

func _check(condition: bool, description: String) -> void:
    if not condition:
        failures.append(description)
        push_error(description)

func _run() -> void:
    var store := Store.new()
    var seen: Dictionary = {}
    for spec: Dictionary in store.descriptors():
        seen[spec.category] = true
        for field: String in ["id", "category", "type", "default", "min", "max", "step", "unit", "apply_mode", "integrity", "label_key", "description_key"]:
            _check(spec.has(field), "Descriptor missing " + field)
    _check(seen.size() == 6, "All six categories are present")
    _check(store.get_value("jump_speed") == 820.0, "Original jump baseline preserved")
    _check(store.get_value("gravity") == 1780.0, "Original gravity baseline preserved")
    if not store.is_available():
        _check(not store.set_value("jump_speed", 1000.0), "Release rejects tuning writes")
        store.free()
        _finish()
        return
    _check(not store.set_value("move_speed", "500"), "Numeric strings rejected")
    _check(not store.set_value("move_speed", NAN), "NaN rejected")
    _check(not store.set_value("unknown", 5.0), "Unknown descriptors rejected")
    store.begin_run()
    store.set_value("filter_intensity", 0.3)
    _check(not store.is_run_tainted(), "Cosmetic change preserves integrity")
    store.set_value("jump_speed", 900.0)
    _check(store.get_value("jump_speed") == 820.0, "Deferred request does not apply immediately")
    _check(store.get_requested_value("jump_speed") == 900.0, "Requested value retained")
    _check(not store.is_run_tainted(), "Pending change does not taint early")
    store.apply_boundary("NEXT_SPAWN")
    _check(store.get_value("jump_speed") == 820.0, "Wrong boundary cannot apply jump")
    store.apply_boundary("NEXT_ACTION")
    _check(store.get_value("jump_speed") == 900.0, "Action boundary applies jump")
    _check(store.is_run_tainted(), "Applied gameplay request taints run")
    store.reset_value("jump_speed")
    store.apply_boundary("NEXT_ACTION")
    _check(store.is_run_tainted(), "Reset cannot erase taint")
    store.begin_run()
    _check(not store.is_run_tainted(), "New baseline run clears taint")
    var baseline := store.configuration_marker()
    store.set_value("platform_gap", 152.0)
    store.apply_boundary("NEXT_STAGE")
    _check(store.configuration_marker() != baseline, "Configuration records applied gameplay values")
    store.set_value("move_speed", 99999.0)
    _check(store.get_value("move_speed") == 760.0, "Values clamp to safe upper bound")
    store.free()
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("TUNING_CONTRACT_OK")
    quit(0 if failures.is_empty() else 1)
