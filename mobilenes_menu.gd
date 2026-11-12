class_name MobilenesMenu
extends Control
## MobilenesMenu - the settings screen of Mobilenes.
##
## Open it with F1 (or the Guide button on a gamepad), or - on a phone - PULL the red M circle from the
## bottom-left corner almost all the way to the opposite corner (see class Handle at the bottom). In it the player can:
##   * pick a gamepad skin from the skins folder,
##   * change the keyboard key and gamepad button of every button,
##   * switch turbo (autofire) on or off per button,
##   * switch vibration on or off,
##   * press "Reset this skin" to go back to that skin's own basic setup.
##
## Mobilenes creates the menu for you.
##
## The file has three parts:  1. THE MENU   2. THE SETTINGS FILE (class Settings)   3. THE PULL HANDLE (class Handle)

signal closed  # Emitted when the menu is closed.

# =================================================================================================================
# 1. THE MENU
# =================================================================================================================

var box: Control  # The Mobilenes that owns this menu. (Typed as Control to keep things simple.)

var _ui_root: Control
var _bg: ColorRect                  # the menu's background, in the handle's color
var _skin_picker: OptionButton
var _preview: TextureRect
var _rows: GridContainer
var _vibration_check: CheckBox
var _hint: Label
var _skin_folders: PackedStringArray = []

var _waiting_action: StringName = &""  # While we wait for the player to press a key: which action and which kind.
var _waiting_kind := ""
var _waiting_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# The background is the circle's own color (skin.ini menu_color): once the circle has grown over the screen
	# the menu simply stays on it. No dark layer, no panel.
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.visible = false
	add_child(_bg)

	_ui_root = Control.new()
	_ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_ui_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(center)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	center.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	# --- Skin picker ---
	var skin_row := HBoxContainer.new()
	skin_row.add_theme_constant_override("separation", 8)
	column.add_child(skin_row)
	var skin_label := Label.new()
	skin_label.text = "Skin:"
	skin_row.add_child(skin_label)
	_skin_picker = OptionButton.new()
	_skin_picker.custom_minimum_size = Vector2(180, 0)
	_skin_picker.item_selected.connect(_on_skin_selected)
	skin_row.add_child(_skin_picker)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(96, 45)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skin_row.add_child(_preview)

	# --- Button list ---
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = GridContainer.new()
	_rows.columns = 6
	_rows.add_theme_constant_override("h_separation", 8)
	_rows.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_rows)

	_hint = Label.new()
	_hint.text = "Tap \"Change\", then press the new key or gamepad button."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(430, 0)
	column.add_child(_hint)

	_vibration_check = CheckBox.new()
	_vibration_check.text = "Vibration (phones)"
	_vibration_check.toggled.connect(_on_vibration_toggled)
	column.add_child(_vibration_check)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(footer)
	var reset := Button.new()
	reset.text = "Reset this skin"
	reset.pressed.connect(_on_reset_pressed)
	footer.add_child(reset)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_menu)
	footer.add_child(close)

	resized.connect(_update_scale)
	_update_scale()


var is_open := false  # True once the menu is fully open (as opposed to just peeking out while the handle is pulled).


func open_menu() -> void:  # Shows the menu completely.
	_cancel_capture()
	_fill_content()
	_bg.color = box.skin.menu_color if box.skin != null else Color("e4002b")
	_bg.visible = true
	_ui_root.modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	is_open = true
	visible = true


func close_menu() -> void:  # Hides the menu.
	_cancel_capture()
	if visible or is_open:
		is_open = false
		visible = false
		_bg.visible = false
		closed.emit()


# ==============================
# While the handle is pulled the circle itself is the background; the menu's content fades in on top of it.
# `amount` is 0 (nothing) .. 1 (the line). Called by the pull handle on every move; it does not pause the game
# or take over the pad.
# ==============================
func peek(amount: float) -> void:
	if is_open:
		return
	if amount <= 0.0:
		visible = false
		return
	if not visible:
		_fill_content()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.visible = false
	_ui_root.modulate.a = clampf((amount / MobilenesMenu.Handle.OPEN_AT - 0.7) / 0.3, 0.0, 1.0)
	visible = true


# ==============================
# Builds the skin picker, the vibration box and the button list (needed before the menu is shown).
# ==============================
func _fill_content() -> void:
	_fill_skin_picker()
	_vibration_check.set_pressed_no_signal(box.vibration)
	_rebuild_rows()


func _update_scale() -> void:  # Makes the menu big enough to read on a phone and small enough on a computer.
	if _ui_root == null:
		return
	var factor := clampf(minf(size.x / 480.0, size.y / 400.0), 0.4, 4.0)  # the menu is about 460 x 330 pixels: shrink or grow it to fit the window
	_ui_root.scale = Vector2(factor, factor)
	_ui_root.size = size / factor


# ----------------------------------------------------------------------------
#  SKINS
# ----------------------------------------------------------------------------
func _fill_skin_picker() -> void:
	_skin_folders = box.list_skins()
	_skin_picker.clear()
	var current := -1
	for index in _skin_folders.size():
		_skin_picker.add_item(Settings.skin_display_name(_skin_folders[index]))
		if _skin_folders[index] == box.skin_folder:
			current = index
	if current >= 0:
		_skin_picker.select(current)
	_update_preview()


func _update_preview() -> void:
	_preview.texture = box.skin.preview if box.skin != null else null


func _on_skin_selected(index: int) -> void:
	_cancel_capture()
	if box.set_skin_folder(_skin_folders[index]):
		Settings.set_general("skin_folder", _skin_folders[index])
	_update_preview()
	_rebuild_rows()


func _on_reset_pressed() -> void:
	_cancel_capture()
	Settings.clear_skin(box.skin_folder)
	box.set_skin_folder(box.skin_folder)
	_rebuild_rows()
	_hint.text = "This skin is back to its basic setup."


func _on_vibration_toggled(enabled: bool) -> void:
	box.set_vibration_enabled(enabled)


# ----------------------------------------------------------------------------
#  THE BUTTON LIST
# ----------------------------------------------------------------------------
func _rebuild_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_rows.columns = 6
	for heading in ["Button", "Key", "", "Gamepad", "", "Turbo"]:
		var label := Label.new()
		label.text = heading
		label.modulate = Color(1, 1, 1, 0.6)
		_rows.add_child(label)

	if box.skin == null:
		return
	var done: Array[StringName] = []
	for piece in box.skin.controls:
		if piece == null:
			continue
		if piece.kind == MobilenesSkin.Piece.Kind.DPAD:
			for pair in [[&"pad_up", "Up"], [&"pad_down", "Down"], [&"pad_left", "Left"], [&"pad_right", "Right"]]:
				if not done.has(pair[0]):
					done.append(pair[0])
					_add_row(pair[0], pair[1], false)
		elif piece.kind == MobilenesSkin.Piece.Kind.BUTTON and not done.has(piece.action):
			done.append(piece.action)
			var name_text: String = String(piece.label).trim_prefix("Button ").capitalize()
			if name_text == "":
				name_text = String(piece.action).trim_prefix("pad_").capitalize()
			_add_row(piece.action, name_text, true)


func _add_row(action: StringName, name_text: String, allow_turbo: bool) -> void:
	var name_label := Label.new()
	name_label.text = name_text
	_rows.add_child(name_label)

	var keys := Label.new()
	keys.text = _names_of(Mobilenes.Actions.get_key_codes(action), false)
	keys.custom_minimum_size = Vector2(80, 0)
	_rows.add_child(keys)
	var change_key := Button.new()
	change_key.text = "Change"
	change_key.pressed.connect(_start_capture.bind(action, "keys", change_key, keys))
	_rows.add_child(change_key)

	var pads := Label.new()
	pads.text = _names_of(Mobilenes.Actions.get_button_codes(action), true)
	pads.custom_minimum_size = Vector2(70, 0)
	_rows.add_child(pads)
	var change_pad := Button.new()
	change_pad.text = "Change"
	change_pad.pressed.connect(_start_capture.bind(action, "buttons", change_pad, pads))
	_rows.add_child(change_pad)

	if allow_turbo:
		var turbo := CheckBox.new()
		turbo.set_pressed_no_signal(box.get_pad() != null and box.is_turbo(action))
		turbo.toggled.connect(_on_turbo_toggled.bind(action))
		_rows.add_child(turbo)
	else:
		_rows.add_child(Control.new())


func _names_of(codes: Array, gamepad: bool) -> String:
	if codes.is_empty():
		return "-"
	var names: PackedStringArray = []
	for code in codes:
		names.append(Mobilenes.Actions.button_name(code) if gamepad else Mobilenes.Actions.key_name(code))
	return ", ".join(names)


func _on_turbo_toggled(enabled: bool, action: StringName) -> void:
	box.set_turbo(action, enabled)
	Settings.set_turbo(box.skin_folder, action, enabled)


# ----------------------------------------------------------------------------
#  CHANGING A KEY: wait for the next key or gamepad button
# ----------------------------------------------------------------------------
func _start_capture(action: StringName, kind: String, button: Button, _label: Label) -> void:
	_cancel_capture()
	_waiting_action = action
	_waiting_kind = kind
	_waiting_button = button
	button.text = "Press..."
	_hint.text = "Press the new %s now. (Esc cancels)" % ("key" if kind == "keys" else "gamepad button")


func _cancel_capture() -> void:
	if _waiting_button != null and is_instance_valid(_waiting_button):
		_waiting_button.text = "Change"
	_waiting_action = &""
	_waiting_kind = ""
	_waiting_button = null


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _waiting_action == &"":
		return

	if _waiting_kind == "keys" and event is InputEventKey and event.pressed and not event.is_echo():
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			_cancel_capture()
			_hint.text = "Cancelled."
			return
		_assign(int(event.physical_keycode))
	elif _waiting_kind == "buttons" and event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		_assign(int(event.button_index))
	elif _waiting_kind == "buttons" and event is InputEventKey and event.pressed \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancel_capture()
		_hint.text = "Cancelled."


# ==============================
# Gives "code" to the waiting action. If another button already used it, that
# button loses it (so one key never does two things).
# ==============================
func _assign(code: int) -> void:
	var kind := _waiting_kind
	var action := _waiting_action
	_cancel_capture()

	for other in Mobilenes.Actions.GAMEPLAY:
		if other == action:
			continue
		var codes: Array = Mobilenes.Actions.get_key_codes(other) if kind == "keys" else Mobilenes.Actions.get_button_codes(other)
		if codes.has(code):
			codes.erase(code)
			Mobilenes.Actions.apply_bindings({other: {kind: codes}})
			Settings.set_binding(box.skin_folder, other, kind, codes)

	# The chosen key REPLACES the old one for this button.
	Mobilenes.Actions.apply_bindings({action: {kind: [code]}})
	Settings.set_binding(box.skin_folder, action, kind, [code])
	_hint.text = "Saved."
	_rebuild_rows()


# =================================================================================================================
# 2. THE SETTINGS FILE - remembers what the player chose
# =================================================================================================================

class Settings extends RefCounted:
	## Remembers what the PLAYER chose in the Mobilenes menu: which skin, remapped
	## buttons, turbo and vibration.
	##
	## Everything is stored in one small file (user://mobilepad_settings.cfg). On a
	## computer that is in the game's user data folder; in a web build it lives in
	## the browser's storage.
	##
	## Remapped buttons and turbo are remembered PER SKIN, so each skin keeps its
	## own setup and "Reset" only affects the skin you are looking at.

	const PATH := "user://mobilepad_settings.cfg"  # Where the settings file is stored.


	# ==============================
	# Reads a general setting (for example "skin_folder").
	# ==============================
	static func get_general(key: String, default_value: Variant) -> Variant:
		return _open().get_value("general", key, default_value)


	static func set_general(key: String, value: Variant) -> void:  # Saves a general setting.
		var file := _open()
		file.set_value("general", key, value)
		file.save(PATH)


	# ==============================
	# The player's remapped buttons for one skin.
	# Format: { action_name: { "keys": [...], "buttons": [...] } }
	# ==============================
	static func get_bindings(skin_folder: String) -> Dictionary:
		return _open().get_value(_section(skin_folder), "bindings", {})


	# ==============================
	# Remembers new keys (kind = "keys") or gamepad buttons (kind = "buttons") for an action.
	# ==============================
	static func set_binding(skin_folder: String, action: StringName, kind: String, codes: Array) -> void:
		var file := _open()
		var bindings: Dictionary = file.get_value(_section(skin_folder), "bindings", {})
		var entry: Dictionary = bindings.get(String(action), {})
		entry[kind] = codes
		bindings[String(action)] = entry
		file.set_value(_section(skin_folder), "bindings", bindings)
		file.save(PATH)


	# ==============================
	# The turbo choices of the player for one skin. Format: { action_name: true/false }
	# ==============================
	static func get_turbo(skin_folder: String) -> Dictionary:
		return _open().get_value(_section(skin_folder), "turbo", {})


	static func set_turbo(skin_folder: String, action: StringName, enabled: bool) -> void:
		var file := _open()
		var turbo: Dictionary = file.get_value(_section(skin_folder), "turbo", {})
		turbo[String(action)] = enabled
		file.set_value(_section(skin_folder), "turbo", turbo)
		file.save(PATH)


	# ==============================
	# Forgets everything the player changed for one skin (the "Reset" button).
	# ==============================
	static func clear_skin(skin_folder: String) -> void:
		var file := _open()
		if file.has_section(_section(skin_folder)):
			file.erase_section(_section(skin_folder))
			file.save(PATH)


	# ==============================
	# The display name of a skin folder (the "name =" line in its skin.ini).
	# ==============================
	static func skin_display_name(skin_folder: String) -> String:
		var ini_path := skin_folder.path_join(MobilenesSkin.SKIN_FILE)
		if FileAccess.file_exists(ini_path):
			var in_skin_section := false
			for raw_line in FileAccess.get_file_as_string(ini_path).split("\n"):
				var line := raw_line.strip_edges()
				if line.begins_with("["):
					in_skin_section = line.to_lower() == "[skin]"
				elif in_skin_section and line.to_lower().begins_with("name"):
					var equals := line.find("=")
					if equals > 0:
						return line.substr(equals + 1).strip_edges()
		return skin_folder.get_file()


	static func _section(skin_folder: String) -> String:
		return "skin " + skin_folder


	static func _open() -> ConfigFile:
		var file := ConfigFile.new()
		file.load(PATH)  # It is fine if the file does not exist yet.
		return file


# =================================================================================================================
# 3. THE PULL HANDLE - the red M circle that opens the menu (phones)
# =================================================================================================================


# ==============================
# The red circle with an M. Its CENTER stays on the BOTTOM-LEFT corner of the screen (so a quarter of it shows) and
# never moves. PULL it with a finger (or the mouse) toward the opposite corner: the circle's DIAMETER grows so that
# its edge follows the finger, and the menu's content fades in on top of it. At OPEN_AT of the way (85 %) the
# circle swells over the whole screen and the menu opens on its color, even if the finger is still down. Let go
# before that and it shrinks back into the corner.
# Mobilenes places it and listens to `opened`; the colour comes from the skin (skin.ini: menu_color).
# ==============================
class Handle extends Control:
	signal opened  # Emitted when the pop is over: open the menu.
	signal pulled(amount: float)  # Emitted on every move: how far it is pulled, 0 (in the corner) .. 1 (the opposite corner).
	signal crossed  # Emitted once at the moment of the pop (a good moment for a short buzz).

	const OPEN_AT := 0.85  # How far along the diagonal the circle pops open. 0.85 = 85 %.
	const POP_TIME := 0.16  # How long the final swell over the screen lasts, in seconds.
	const MOUSE_FINGER := -1  # Finger number used for the mouse (so the handle can be tried on a computer).
	const NO_FINGER := -99

	var radius := 14.0:  # The circle's radius when it rests in the corner.
		set(v):
			radius = v
			queue_redraw()
	var color := Color("e4002b"):                 # NES red
		set(v):
			color = v
			queue_redraw()

	var _finger := NO_FINGER
	var _pop := 0.0                              # 0..1 while the circle swells over the whole screen at the end
	var _pop_from := 0.0                         # the radius the swell starts from
	var _amount := 0.0
	var _popping := false
	var _tween: Tween


	# ==============================
	# The circle's CENTER never moves: it stays on the bottom-left corner. Only its diameter grows.
	# ==============================
	func center() -> Vector2:
		return Vector2(0.0, size.y)


	# ==============================
	# The radius that covers the whole screen (from the bottom-left corner to the opposite corner).
	# ==============================
	func cover_radius() -> float:
		return size.length()


	# ==============================
	# The radius the circle is drawn with right now: its edge follows the finger (the radius is the distance from
	# the corner to the finger). At the line it swells over the whole screen.
	# ==============================
	func drawn_radius() -> float:
		if _popping:
			return lerpf(_pop_from, cover_radius(), _pop)
		return maxf(radius, _amount * cover_radius())


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visibility_changed.connect(func(): if not visible: _release())
		resized.connect(queue_redraw)


	func _draw() -> void:
		var r := drawn_radius()
		var t := 1.0 if _popping else clampf(_amount / OPEN_AT, 0.0, 1.0)
		var c := center()
		draw_circle(c, r, color)
		if t < 1.0:
			draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.9 * (1.0 - t)), maxf(1.0, radius * 0.1), true)
		var font := ThemeDB.fallback_font  # the M sits in the visible quarter of the circle by the corner and fades as the circle grows
		var font_size := int(radius * 1.3)
		var letter_size := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var m_center := c + Vector2(radius, -radius) * 0.5
		draw_string(font, m_center + Vector2(-letter_size.x / 2.0, letter_size.y * 0.32), "M",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 1.0 - t))


	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree() or _popping:
			return
		if event is InputEventScreenTouch:
			if event.pressed:
				_try_grab(event.index, event.position)
			elif event.index == _finger:
				_release()
				get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			if event.index == _finger:
				_move_to(event.position)
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
				and event.device != InputEvent.DEVICE_ID_EMULATION:
			if event.pressed:
				_try_grab(MOUSE_FINGER, event.position)
			elif _finger == MOUSE_FINGER:
				_release()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and _finger == MOUSE_FINGER \
				and event.device != InputEvent.DEVICE_ID_EMULATION:
			_move_to(event.position)
			get_viewport().set_input_as_handled()


	# ==============================
	# A touch started: grab the handle if it landed on the circle (a little generous, fingers are big).
	# ==============================
	func _try_grab(finger: int, screen_position: Vector2) -> void:
		if _finger != NO_FINGER:
			return
		var local := make_canvas_position_local(screen_position)
		if local.distance_to(center()) <= radius * 1.5:
			if _tween != null:
				_tween.kill()
			_finger = finger
			get_viewport().set_input_as_handled()


	# ==============================
	# The finger moved: follow it, grow, and pop when the line is reached.
	# ==============================
	func _move_to(screen_position: Vector2) -> void:
		var local := make_canvas_position_local(screen_position)
		var point := Vector2(clampf(local.x, 0.0, size.x), clampf(local.y, 0.0, size.y))
		_amount = _amount_of(point)
		pulled.emit(_amount)
		queue_redraw()
		if _amount >= OPEN_AT:
			_start_pop()


	# ==============================
	# 0 (at the bottom-left corner) .. 1 (as far away as the opposite corner): how far `point` is from the corner.
	# ==============================
	func _amount_of(point: Vector2) -> float:
		return clampf(point.distance_to(center()) / cover_radius(), 0.0, 1.0)


	# ==============================
	# The finger reached the line: the circle swells over the whole screen, then the menu opens on its color.
	# ==============================
	func _start_pop() -> void:
		_pop_from = drawn_radius()
		_pop = 0.0
		_popping = true
		_finger = NO_FINGER
		crossed.emit()
		if _tween != null:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_method(func(t: float):
			_pop = t
			queue_redraw(), 0.0, 1.0, POP_TIME)
		_tween.tween_callback(func():
			opened.emit()                          # the menu is open (it draws the same color), now rest the circle
			_pop = 0.0
			_amount = 0.0
			_popping = false
			pulled.emit(0.0)
			queue_redraw())


	func _release() -> void:  # The finger let go before the line: the circle shrinks and springs back to the corner.
		if _finger == NO_FINGER:
			return
		_finger = NO_FINGER
		if _tween != null:
			_tween.kill()
		var start_amount := _amount
		_tween = create_tween()
		_tween.tween_method(func(t: float):
			_amount = lerpf(start_amount, 0.0, t)
			pulled.emit(_amount)
			queue_redraw(), 0.0, 1.0, 0.18).set_ease(Tween.EASE_OUT)
