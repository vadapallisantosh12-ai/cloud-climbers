extends SceneTree

const I18N_SCRIPT := preload("res://autoload/i18n.gd")
const FONT: Font = preload("res://assets/template/fonts/ui_regular.tres")
const TEST_PATH := "user://localization-test.cfg"
var failures: Array[String] = []
var changes := 0

class PinnedSystemI18n:
    extends "res://autoload/i18n.gd"
    var system := "en_US"

    func _system_locale() -> String:
        return system

func _init() -> void:
    call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[LOCALIZATION_FAIL] " + message)

func _tokens(text: String) -> PackedStringArray:
    var regex := RegEx.new()
    regex.compile("\\{([a-zA-Z0-9_]+)\\}")
    var result := PackedStringArray()
    for token: RegExMatch in regex.search_all(text):
        result.append(token.get_string(1))
    result.sort()
    return result

func _run() -> void:
    _expect(ProjectSettings.get_setting("application/config/name") == "Vertical Platformer", "project identity uses renamed template")
    var i18n := root.get_node("I18n")
    var old_locale: String = i18n.get_locale()
    var old_path: String = i18n.preference_path
    i18n.preference_path = TEST_PATH
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
    var english: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/en.json"))
    var chinese: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/zh-CN.json"))
    var english_keys := english.keys(); english_keys.sort()
    var chinese_keys := chinese.keys(); chinese_keys.sort()
    _expect(english_keys == chinese_keys, "catalog keys match")
    _expect(english_keys.size() >= 90, "title, gameplay, help, skins and tuning are cataloged")
    for key: String in english_keys:
        _expect(_tokens(english[key]) == _tokens(chinese[key]), "placeholder parity: " + key)
        for locale: Dictionary in [english, chinese]:
            for character: String in str(locale[key]):
                if character.unicode_at(0) > 32:
                    _expect(FONT.has_char(character.unicode_at(0)), "bundled font covers %s in %s" % [character, key])
    # First launch (no saved choice) follows the system/browser language: zh* -> Chinese, else English.
    for pair: Array in [["zh_CN", "zh-CN"], ["zh-TW", "zh-CN"], ["zh", "zh-CN"], ["ZH_hans", "zh-CN"], ["en_US", "en"], ["en", "en"], ["fr_FR", "en"], ["ja", "en"], ["", "en"]]:
        _expect(I18N_SCRIPT.locale_for_system(pair[0]) == pair[1], "system locale %s maps to %s" % pair)
    for system: String in ["en_US", "zh_CN"]:
        var fresh := PinnedSystemI18n.new()
        fresh.system = system
        fresh.preference_path = TEST_PATH
        root.add_child(fresh)
        _expect(fresh.get_locale() == I18N_SCRIPT.locale_for_system(system), "fresh preference follows the system language: " + system)
        fresh.queue_free()
    i18n.locale_changed.connect(func(_locale: String): changes += 1)
    i18n.set_locale("en", false)
    changes = 0
    _expect(i18n.set_locale("zh-CN"), "Chinese selection saves")
    _expect(changes == 1, "one signal for an actual locale change")
    _expect(root.title == "纵向平台跳跃", "Chinese window title updates without changing storage identity")
    _expect(i18n.t("skin.current", {"skin": "青柠"}) == "当前：青柠", "named Chinese placeholder")
    _expect(i18n.set_locale("zh-CN") and changes == 1, "reselecting active locale emits no redundant change")
    _expect(not i18n.set_locale("fr") and i18n.get_locale() == "zh-CN", "unsupported locale does not mutate selection")
    var resumed := I18N_SCRIPT.new()
    resumed.preference_path = TEST_PATH
    root.add_child(resumed)
    _expect(resumed.get_locale() == "zh-CN", "saved Chinese resumes in a new service instance")
    resumed.queue_free()
    var config := ConfigFile.new()
    config.set_value("language", "locale", "invalid")
    config.save(TEST_PATH)
    var invalid := PinnedSystemI18n.new()
    invalid.preference_path = TEST_PATH
    root.add_child(invalid)
    _expect(invalid.get_locale() == "en", "invalid persisted language falls back to the (English) system language")
    invalid.queue_free()
    i18n.set_locale("en")
    var title: Node = load("res://test/title_language_input_probe.gd").new()
    root.add_child(title)
    await process_frame
    await process_frame
    _expect(title.language_rects.size() == 2, "title exposes EN and CN hit targets")
    var selected_skin: String = root.get_node("SaveStore").selected_skin
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    mouse.position = (title.language_rects["zh-CN"] as Rect2).get_center()
    root.push_input(mouse, true)
    await process_frame
    _expect(i18n.get_locale() == "zh-CN", "mouse chooses Chinese")
    mouse.pressed = false
    root.push_input(mouse, true)
    await process_frame
    var touch := InputEventScreenTouch.new()
    touch.index = 1
    touch.pressed = true
    touch.position = (title.language_rects["en"] as Rect2).get_center()
    root.push_input(touch, true)
    await process_frame
    touch.pressed = false
    root.push_input(touch, true)
    touch.pressed = true
    await process_frame
    _expect(i18n.get_locale() == "en", "touch chooses English")
    var key := InputEventKey.new()
    key.keycode = KEY_L
    key.pressed = true
    root.push_input(key)
    await process_frame
    _expect(i18n.get_locale() == "zh-CN", "keyboard L toggles language")
    key.echo = true
    root.push_input(key)
    await process_frame
    _expect(i18n.get_locale() == "zh-CN", "key repeat does not repeatedly toggle")
    var controller := InputEventJoypadButton.new()
    controller.button_index = JOY_BUTTON_Y
    controller.pressed = true
    root.push_input(controller)
    await process_frame
    _expect(i18n.get_locale() == "en", "controller Y toggles language")
    _expect(title.start_requests == 0, "language inputs never start gameplay")
    _expect(root.get_node("SaveStore").selected_skin == selected_skin, "language inputs never change equipped skin")
    _expect(i18n.t("skin.current", {"skin": "Lime"}) == "Wearing: Lime", "named English placeholder")
    _expect(root.title == "Vertical Platformer", "English window title updates without changing storage identity")
    var missing_directory := "user://localization-missing-%d" % Time.get_ticks_usec()
    _expect(not DirAccess.dir_exists_absolute(missing_directory), "failed-save fixture has no parent directory")
    i18n.preference_path = missing_directory + "/language.cfg"
    var changes_before_failed_save := changes
    _expect(i18n.set_locale("zh-CN"), "valid selection succeeds when preference cannot be saved")
    _expect(i18n.get_locale() == "zh-CN" and changes == changes_before_failed_save + 1, "failed save still changes session locale and emits its signal")
    _expect(root.title == "纵向平台跳跃" and i18n.t("skin.current", {"skin": "青柠"}) == "当前：青柠", "failed save still updates visible translated text and window title")
    root.push_input(touch, true)
    await process_frame
    touch.pressed = false
    root.push_input(touch, true)
    touch.pressed = true
    await process_frame
    _expect(i18n.get_locale() == "en" and root.title == "Vertical Platformer", "title selector still changes language when preference storage is unavailable")
    _expect(title.start_requests == 0 and root.get_node("SaveStore").selected_skin == selected_skin, "failed-save selector input still has no gameplay or skin side effects")
    _expect(config.load(TEST_PATH) == OK and config.get_value("language", "locale") == "en", "failed save leaves existing valid preference unchanged")
    _expect(not DirAccess.dir_exists_absolute(missing_directory), "failed save does not create its missing parent directory")
    i18n.preference_path = TEST_PATH
    title.queue_free()
    await process_frame
    i18n.set_locale(old_locale, false)
    i18n.preference_path = old_path
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
    print("[LOCALIZATION_%s] %d paired keys, glyphs, persistence and four selector inputs" % ["PASS" if failures.is_empty() else "FAIL", english_keys.size()])
    quit(0 if failures.is_empty() else 1)
