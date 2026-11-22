class_name Mobilenes
extends Control
## Mobilenes - an on-screen gamepad around your game, in three files:
##
##     mobilenes.gd        THIS file: the node you put in your scene, the layout, the touch pad, the button list
##     mobilenes_menu.gd   the menu (skins, button remapping, turbo, vibration), what the player chose, and the
##                         red "M" handle you pull open from the bottom-left corner
##     mobilenes_skin.gd   a gamepad look: the pictures, where each button is, and the reader of skin.ini files
##
## QUICK START (no code):
##   1. Make Mobilenes.tscn your main scene (or add it to your own scene).
##   2. Drag your game scene into the "Game Scene" slot in the Inspector.
##   3. Press Play. That's it!
##
## Your game gets a screen of "Game Size" pixels (0,0 = the size in Project Settings > Display > Window).
## On a computer you see only the game. On a phone (or in a web page) the game is shown between an on-screen gamepad.
## Mobilenes PRESSES BUTTONS (the pad_* actions below). Your game decides what each button means.
##
## This file has these parts, in this order:
##     1. SETTINGS         everything you can change in the Inspector
##     2. STARTING UP      building the screen, the pad, the menu and the pull handle
##     3. SKIN AND MENU    switching skins, turbo, vibration, opening the menu
##     4. LAYOUT           putting the game and the pad where they belong
##     5. THE TOUCH PAD    class Pad: draws the buttons and turns touches into button presses
##     6. SIDE PANELS      class SidePanel: the stretchy pad body on each side
##     7. THE BUTTON LIST  class Actions: the pad_* buttons and their default keys

signal layout_changed(is_mobile: bool)  # Emitted whenever the layout changes. true = phone layout with the pad.

# ==============================
# Which layout to use.
#   AUTO    = phone layout on phones / mobile browsers, otherwise computer layout.
#   DESKTOP = always only the game screen.
#   MOBILE  = always the screen with the gamepad (handy to test on a computer).
# ==============================
enum LayoutMode { AUTO, DESKTOP, MOBILE }

const DEFAULT_SKIN_FOLDER := "res://addons/mobilenes/skins/ascii"  # The skin used when yours cannot be loaded.
const SKINS_DIRECTORY := "res://addons/mobilenes/skins"  # Where the skins that come with Mobilenes live.


# =================================================================================================================
# 1. SETTINGS - everything you can change in the Inspector
# =================================================================================================================

@export_group("Your game")
@export var game_scene: PackedScene  # Drag your game scene here. (Or drop it on DropYourGameHere in the scene tree.)

@export_group("Screen")
@export var screen_layout: LayoutMode = LayoutMode.AUTO  # Computer layout, phone layout, or let Mobilenes decide.
@export var web_always_shows_pad := true  # in a web page, show the pad on both sides instead of deciding by the device
# ==============================
# ON = while testing in Godot, F2 switches between the computer and phone layout, and F3 shows or hides the
# touch areas. Never active in exported games.
# ==============================
@export var debug_keys := true
@export var background_color := Color.BLACK  # Color of the empty bars around the game.

@export_group("On-screen gamepad")
# ==============================
# The folder of the gamepad skin. It must contain a skin.ini file.
# To use another skin: drop its folder into your project and pick it here.
# ==============================
@export_dir var skin_folder := DEFAULT_SKIN_FOLDER
@export var vibration := true  # Short buzz when a finger moves onto a new button.
@export_range(5, 100) var vibration_ms: int = 20  # How long the buzz lasts (milliseconds).
@export_range(1.0, 30.0) var turbo_rate := 15.0  # How many presses per second turbo (autofire) makes.
@export var show_touch_areas := false  # Show the invisible touch areas in teal. Great for designing a skin.

@export_group("Menu")
@export var remember_player_settings := true  # ON = the player's choices (skin, buttons, turbo, vibration) are saved for next time
@export var pause_game_in_menu := true  # ON = the game freezes while the menu is open.
@export var show_menu_handle := true  # Show the red "M" pull handle in the bottom-left corner of the phone layout.

@export_group("Keyboard and gamepad")
@export var add_default_controls := true  # ON = Mobilenes creates the pad_* buttons for you (arrow keys, X, Z, Enter...).

@onready var _screen: SubViewportContainer = %Screen
@onready var _slot: Node2D = %DropYourGameHere

var skin: MobilenesSkin  # The skin currently in use.

var _background: ColorRect
var _back_picture: TextureRect  # the skin's background picture, behind the game and the panels (phone layout only)
var _pad: Pad                  # the whole pad - or, in the sides layout, the LEFT half
var _pad_right: Pad            # sides layout only: the right half
var _panel_left: SidePanel
var _panel_right: SidePanel
var _menu: MobilenesMenu
var _handle: MobilenesMenu.Handle


# =================================================================================================================
# 2. STARTING UP
# =================================================================================================================

func _ready() -> void:
	if OS.has_feature("web") and web_always_shows_pad:
		screen_layout = LayoutMode.MOBILE
	# Mobilenes keeps running while the game is paused, so the menu still works.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if add_default_controls:
		Actions.ensure_defaults()

	# Use the skin and vibration the player picked last time.
	if remember_player_settings:
		var saved_skin: String = MobilenesMenu.Settings.get_general("skin_folder", "")
		if saved_skin != "" and FileAccess.file_exists(saved_skin.path_join(MobilenesSkin.SKIN_FILE)):
			skin_folder = saved_skin
		vibration = MobilenesMenu.Settings.get_general("vibration", vibration)

	# Anything you placed directly under Mobilenes is moved onto the game screen.
	for child in get_children():
		if child != _screen:
			child.reparent(_slot, false)
	if game_scene != null:
		_slot.add_child(game_scene.instantiate())
	# Only the game freezes when the menu is open, not Mobilenes itself.
	_slot.process_mode = Node.PROCESS_MODE_PAUSABLE

	# Black bars behind everything.
	_background = ColorRect.new()
	_background.color = background_color
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	move_child(_background, 0)
	_back_picture = TextureRect.new()
	_back_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # fills the window, cut at the edges if needed
	_back_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_back_picture)
	move_child(_back_picture, 1)

	# The on-screen gamepad. (Sides layout: two panels with a pad half on each.)
	_panel_left = SidePanel.new()
	_panel_right = SidePanel.new()
	for panel in [_panel_left, _panel_right]:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(panel)
	_pad = _make_pad()
	_pad_right = _make_pad()
	for i in 4:                                        # behind the game screen: panels, then the two pad halves
		move_child([_panel_left, _panel_right, _pad, _pad_right][i], 2 + i)

	if not set_skin_folder(skin_folder) and skin_folder != DEFAULT_SKIN_FOLDER:
		push_warning("Mobilenes: could not use the skin '%s', using the default skin instead." % skin_folder)
		set_skin_folder(DEFAULT_SKIN_FOLDER)

	# The menu, and the red pull handle on top of everything.
	_menu = MobilenesMenu.new()
	_menu.box = self
	_menu.closed.connect(_on_menu_closed)
	add_child(_menu)
	_handle = MobilenesMenu.Handle.new()
	_handle.opened.connect(open_menu)
	_handle.pulled.connect(_menu.peek)
	_handle.crossed.connect(_vibrate_once)
	add_child(_handle)
	move_child(_handle, _menu.get_index())            # the menu's content is drawn on top of the grown circle

	resized.connect(_relayout)
	_relayout()


func _make_pad() -> Pad:
	var pad := Pad.new()
	pad.vibration = vibration
	pad.vibration_ms = vibration_ms
	pad.turbo_rate = turbo_rate
	pad.show_touch_areas = show_touch_areas
	add_child(pad)
	return pad


# =================================================================================================================
# 3. SKIN AND MENU
# =================================================================================================================

# ==============================
# Turns turbo on or off for a button (on both halves of the pad).
# ==============================
func set_turbo(action: StringName, enabled: bool) -> void:
	_pad.set_turbo(action, enabled)
	_pad_right.set_turbo(action, enabled)


func is_turbo(action: StringName) -> bool:
	return _pad.is_turbo(action) or _pad_right.is_turbo(action)


# ==============================
# Switches to the skin in "folder" (it must contain a skin.ini).
# The player's saved buttons for that skin are applied on top.
# Returns true if it worked.
# ==============================
func set_skin_folder(folder: String) -> bool:
	var loaded := MobilenesSkin.load_folder(folder)
	if loaded == null:
		return false
	skin = loaded
	skin_folder = folder

	# 1) factory buttons, 2) the skin's own buttons, 3) what the player changed.
	Actions.reset_to_defaults()
	Actions.apply_bindings(skin.bindings)
	var turbo_choices: Dictionary = {}
	if remember_player_settings:
		Actions.apply_bindings(MobilenesMenu.Settings.get_bindings(folder))
		turbo_choices = MobilenesMenu.Settings.get_turbo(folder)

	if _pad != null:
		_pad.skin = skin
		_pad_right.skin = skin
		_pad.size = skin.design_size
		_pad_right.size = skin.design_size
		_panel_left.body = skin.body
		_panel_right.body = skin.body
		for action in turbo_choices:
			set_turbo(StringName(action), turbo_choices[action])
		if _handle != null:
			_handle.color = skin.menu_color
		_relayout()
	return true


# ==============================
# All the skin folders the player can choose from: the ones inside the Mobilenes skins folder,
# plus any inside user://skins (so players can add their own).
# ==============================
func list_skins() -> PackedStringArray:
	var found := MobilenesSkin.list_skins(SKINS_DIRECTORY)
	if DirAccess.dir_exists_absolute("user://skins"):
		found.append_array(MobilenesSkin.list_skins("user://skins"))
	return found


func open_menu() -> void:  # Opens the menu (the game freezes behind it if "Pause Game In Menu" is on).
	if _menu == null or _menu.is_open:
		return
	_menu.open_menu()
	_pad.set_input_enabled(false)
	_pad_right.set_input_enabled(false)
	_handle.visible = false
	if pause_game_in_menu:
		get_tree().paused = true


func close_menu() -> void:  # Closes the menu.
	if _menu != null:
		_menu.close_menu()


func set_vibration_enabled(enabled: bool) -> void:  # Turns vibration on or off (the menu uses this).
	vibration = enabled
	if _pad != null:
		_pad.vibration = enabled
		_pad_right.vibration = enabled
	if remember_player_settings:
		MobilenesMenu.Settings.set_general("vibration", enabled)


func _on_menu_closed() -> void:
	_pad.set_input_enabled(true)
	_pad_right.set_input_enabled(true)
	get_tree().paused = false
	_relayout()


func _vibrate_once() -> void:  # One short buzz (the pull handle uses it when it passes the "open" line).
	if _pad != null:
		_pad.buzz()


func is_mobile_layout() -> bool:  # True when the phone layout (screen + gamepad) is being used.
	match screen_layout:
		LayoutMode.DESKTOP:
			return false
		LayoutMode.MOBILE:
			return skin != null
		_:
			return skin != null and _looks_like_phone()


func get_game_viewport() -> SubViewport:  # The SubViewport your game runs in (useful for effects like palettes).
	return _slot.get_parent() as SubViewport


func get_game_slot() -> Node2D:  # The node your game lives under.
	return _slot


func get_pad() -> Pad:  # The on-screen gamepad (for example to switch turbo on a button).
	return _pad


func _input(event: InputEvent) -> void:
	if not InputMap.has_action(&"pad_menu") or event.is_echo():
		return
	if debug_keys and OS.is_debug_build() and event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_F2:
			screen_layout = LayoutMode.DESKTOP if is_mobile_layout() else LayoutMode.MOBILE
			_relayout()
		elif event.physical_keycode == KEY_F3:
			show_touch_areas = not show_touch_areas
			_pad.show_touch_areas = show_touch_areas
			_pad_right.show_touch_areas = show_touch_areas
	if event.is_action_pressed(&"pad_menu"):
		if _menu != null and _menu.is_open:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()


func _looks_like_phone() -> bool:  # True on a phone or tablet: an app on one, or a web page opened in the browser of one.
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):   # a tablet that says it is a computer (an iPad, a phone set to "Desktop site"): its main pointer is a finger
		return JavaScriptBridge.eval("matchMedia('(pointer: coarse)').matches") == true
	return false


# =================================================================================================================
# 4. LAYOUT - putting the game and the pad where they belong
# =================================================================================================================
# Mobilenes decides how much room the game gets inside whatever space it has. The window itself belongs to the
# Screen (screen/screen.gd).

# ==============================
# Mobilenes only decides how much room the game gets: it sizes the SubViewport (Screen) to the free area and puts
# the game inside at 1:1 pixels. The Screen looks at the size of the room it is given and zooms the picture by a
# whole number (see screen/screen.gd).
# ==============================
func _relayout() -> void:
	if _pad == null or _menu == null:
		return
	var mobile := is_mobile_layout()
	_back_picture.texture = skin.screen_background
	_back_picture.visible = mobile and skin.screen_background != null
	if mobile and skin.sides:
		_relayout_sides()
		return
	_panel_left.visible = false
	_panel_right.visible = false
	_pad_right.visible = false
	_pad.x_min = -INF
	_pad.x_max = INF
	_pad.visible = mobile
	if not mobile:
		_screen.position = Vector2.ZERO
		_screen.size = size                            # the game gets the whole window
		_place_handle(false, 1.0)
		layout_changed.emit(false)
		return
	var base := skin.design_size  # the pad is drawn as big as fits (whole numbers); the game gets the skin's screen hole
	var fit := minf(size.x / base.x, size.y / base.y)
	var zoom := floorf(fit) if fit >= 1.0 else fit
	var top_left := ((size - base * zoom) / 2.0).floor()
	_pad.position = top_left
	_pad.scale = Vector2(zoom, zoom)
	_screen.position = top_left + skin.screen_rect.position * zoom
	_screen.size = (skin.screen_rect.size * zoom).floor()
	_place_handle(true, zoom)
	layout_changed.emit(true)


# ==============================
# SIDES layout: the pad is drawn as big as the window height allows; whatever is left between the left and right
# panels is the game's screen. The game then fits itself into that room; the empty space it leaves around its picture
# is measured: the width goes to the side panels and the room shrinks to the picture's height, so the skin's
# background picture shows above and below the game.
# ==============================
func _relayout_sides() -> void:  # Lays out the sides, then gives the game's unused space to the panels and the background.
	_place_sides(Vector2.ZERO)
	var gap := _game_gap()
	if gap.x >= 1.0 or gap.y >= 1.0:
		_place_sides(gap)
	layout_changed.emit(true)


func _game_gap() -> Vector2:  # The empty space the game left beside (x) and above (y) its picture (0 when it fills the room).
	var view := get_game_viewport()
	if view == null:
		return Vector2.ZERO
	var t := view.global_canvas_transform
	if t.x.y != 0.0 or t.y.x != 0.0 or t.x.x <= 0.0:   # a turned or mirrored picture is left as it is
		return Vector2.ZERO
	return Vector2(floorf(clampf(t.origin.x, 0.0, _screen.size.x / 4.0)),  # never more than a quarter of the room per side
			floorf(clampf(t.origin.y, 0.0, _screen.size.y / 4.0)))


func _place_sides(gap: Vector2) -> void:  # Sizes both panels (each widened by gap.x) and the game between them (gap.y shorter at top and bottom).
	var left_w := skin.left_width
	var right_w := skin.design_size.x - skin.right_start
	var design_h := skin.design_size.y
	var p := size.y / design_h                         # how big the pad pieces are drawn
	p = minf(p, size.x * 0.4 / (left_w + right_w))     # the pad never takes more than 40% of the width
	var left_px := floorf(left_w * p) + gap.x
	var right_px := floorf(right_w * p) + gap.x
	p = minf(size.y / design_h, minf(left_px / left_w, right_px / right_w))  # wider panels may draw the pad a bit bigger
	_screen.position = Vector2(left_px, gap.y)
	_screen.size = Vector2(maxf(size.x - left_px - right_px, 1.0), maxf(size.y - 2.0 * gap.y, 1.0))
	var sides := [
		[_panel_left, _pad, 0.0, left_px, left_w, 0.0, -INF, skin.left_width],
		[_panel_right, _pad_right, size.x - right_px, right_px, right_w, skin.right_start, skin.right_start, INF],
	]
	for entry in sides:
		var panel: SidePanel = entry[0]
		var pad: Pad = entry[1]
		var x0: float = entry[2]
		var side_w: float = entry[3]
		var design_w: float = entry[4]
		var design_x0: float = entry[5]
		panel.visible = true
		panel.position = Vector2(x0, 0)
		panel.size = Vector2(side_w, size.y)
		panel.source_x = design_x0
		panel.source_width = design_w
		panel.pixel_scale = p
		pad.visible = true
		pad.x_min = entry[6]
		pad.x_max = entry[7]
		pad.scale = Vector2(p, p)
		pad.position = Vector2(x0 + side_w / 2.0 - (design_x0 + design_w / 2.0) * p, size.y / 2.0 - design_h / 2.0 * p)
	_place_handle(true, maxf(p, 1.0))


# ==============================
# The red pull handle: only on the phone layout, only while the menu is closed. Its size follows the zoom.
# ==============================
func _place_handle(mobile: bool, zoom: float) -> void:
	if _handle == null:
		return
	_handle.visible = mobile and show_menu_handle and not _menu.is_open
	_handle.radius = maxf(16.0, 14.0 * maxf(zoom, 1.0))


# =================================================================================================================
# 5. THE TOUCH PAD
# =================================================================================================================

class Pad extends Control:
	## Pad - draws the on-screen gamepad and turns touches into button presses.
	##
	## Mobilenes creates the pad for you.
	##
	## What it does, in plain words:
	##   * Draws the pictures from the skin.
	##   * Watches fingers (or the mouse, for testing on a computer).
	##   * Works out which button each finger is on.
	##   * Presses and releases the matching action, so your game reacts exactly
	##     as if a keyboard key or a real gamepad button was used.
	##   * Gives a tiny vibration when a finger moves onto a new button.
	##   * Repeats buttons that have turbo (autofire) turned on.

	var skin: MobilenesSkin:  # The skin (pictures + button positions) to use. Mobilenes sets this.
		set(value):
			skin = value
			_rebuild_from_skin()
			queue_redraw()

	var vibration := true  # Short buzz when a finger enters a new button.
	var vibration_ms := 20  # Length of that buzz, in milliseconds.
	var turbo_rate := 15.0  # How many presses per second turbo makes.
	var show_touch_areas := false:  # Draws the invisible touch areas in teal. Handy while designing a skin.
		set(value):
			show_touch_areas = value
			queue_redraw()

	var input_enabled := true  # False while the menu is open.

	var x_min := -INF  # only pieces whose center lies between x_min and x_max (design space) are drawn and touchable
	var x_max := INF

	var _fingers: Dictionary = {}  # Finger number -> list of actions that finger is currently holding.
	var _touch_counts: Dictionary = {}  # Action -> how many fingers hold it right now.
	var _sent: Dictionary = {}  # Action -> what we last told the game (so we only send changes).
	var _turbo_flags: Dictionary = {}  # Action -> true if that button has turbo turned on.
	var _actions: Array[StringName] = []  # Every action this pad can press (taken from the skin).

	var _turbo_clock := 0.0
	var _turbo_down := true
	var _use_real_mouse := true

	const MOUSE_FINGER := -1  # The mouse is treated as "finger number -1" so you can test on a computer.


	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# If the project already turns mouse clicks into fake touches, we must not
		# count the same click twice.
		_use_real_mouse = not bool(ProjectSettings.get_setting(
			"input_devices/pointing/emulate_touch_from_mouse", false))
		visibility_changed.connect(_on_visibility_changed)


	# ==============================
	# Turn turbo on or off for one button, for example set_turbo(&"pad_a", true).
	# ==============================
	func set_turbo(action: StringName, enabled: bool) -> void:
		_turbo_flags[action] = enabled


	func is_turbo(action: StringName) -> bool:  # Is turbo on for this button?
		return _turbo_flags.get(action, false)


	# ==============================
	# While the menu is open the pad ignores fingers. Switching it off also
	# lets go of every button that is currently held.
	# ==============================
	func set_input_enabled(enabled: bool) -> void:
		input_enabled = enabled
		if not enabled:
			_fingers.clear()
			_touch_counts.clear()
			queue_redraw()


	# ----------------------------------------------------------------------------
	#  DRAWING
	# ----------------------------------------------------------------------------
	func _draw() -> void:
		if skin == null:
			return
		for piece in skin.controls:
			if piece == null or piece.texture == null or not _mine(piece):
				continue
			var tex: Texture2D = piece.texture
			var is_down := _is_button_down(piece)
			var tint := Color.WHITE
			if is_down:
				if piece.pressed_texture != null:
					tex = piece.pressed_texture
				else:
					tint = Color(0.7, 0.7, 0.7)
			var piece_size := piece.get_size()
			var top_left := (piece.position - piece_size / 2.0).round()
			if piece.draw_size != Vector2.ZERO:
				_draw_nine_patch(tex, Rect2(top_left, piece_size), piece.patch_margins, tint)
			else:
				draw_texture(tex, top_left, tint)
			if piece.legend != null:   # a pressed key's top sits one pixel lower, and its legend with it
				draw_texture(piece.legend, top_left + piece.legend_offset + Vector2(0, 1 if is_down else 0))
			if piece.kind == MobilenesSkin.Piece.Kind.DPAD:
				_draw_dpad_highlight(top_left, tex.get_size())

		if show_touch_areas:
			for piece in skin.controls:
				if piece != null and piece.kind != MobilenesSkin.Piece.Kind.DECORATION and _mine(piece):
					var rect := piece.get_touch_rect()
					draw_rect(rect, Color(0.0, 0.8, 0.9, 0.3))
					draw_rect(rect, Color(0.0, 0.8, 0.9, 0.9), false, 1.0)


	func _draw_nine_patch(tex: Texture2D, rect: Rect2, margins: Vector4, tint: Color) -> void:  # Stretches a picture to `rect`, keeping its four borders as drawn.
		var source := [0.0, margins.x, tex.get_width() - margins.z, tex.get_width()]  # column edges in the picture
		var source_y := [0.0, margins.y, tex.get_height() - margins.w, tex.get_height()]
		var target := [rect.position.x, rect.position.x + margins.x, rect.end.x - margins.z, rect.end.x]  # column edges on the pad
		var target_y := [rect.position.y, rect.position.y + margins.y, rect.end.y - margins.w, rect.end.y]
		for column in 3:
			for row in 3:
				var to := Rect2(target[column], target_y[row], target[column + 1] - target[column], target_y[row + 1] - target_y[row])
				var from := Rect2(source[column], source_y[row], source[column + 1] - source[column], source_y[row + 1] - source_y[row])
				if to.size.x > 0.0 and to.size.y > 0.0 and from.size.x > 0.0 and from.size.y > 0.0:
					draw_texture_rect_region(tex, to, from, tint)


	func _mine(piece: MobilenesSkin.Piece) -> bool:
		return piece.position.x >= x_min and piece.position.x < x_max


	func _is_button_down(piece: MobilenesSkin.Piece) -> bool:
		return piece.kind == MobilenesSkin.Piece.Kind.BUTTON \
			and _touch_counts.get(piece.action, 0) > 0


	# ==============================
	# The D-pad picture has no "pressed" version, so we lighten the arm being pressed.
	# ==============================
	func _draw_dpad_highlight(top_left: Vector2, tex_size: Vector2) -> void:
		var glow := Color(1, 1, 1, 0.25)
		var third := tex_size / 3.0
		if _touch_counts.get(&"pad_up", 0) > 0:
			draw_rect(Rect2(top_left + Vector2(third.x, 0), Vector2(third.x, tex_size.y / 2.0)), glow)
		if _touch_counts.get(&"pad_down", 0) > 0:
			draw_rect(Rect2(top_left + Vector2(third.x, tex_size.y / 2.0), Vector2(third.x, tex_size.y / 2.0)), glow)
		if _touch_counts.get(&"pad_left", 0) > 0:
			draw_rect(Rect2(top_left + Vector2(0, third.y), Vector2(tex_size.x / 2.0, third.y)), glow)
		if _touch_counts.get(&"pad_right", 0) > 0:
			draw_rect(Rect2(top_left + Vector2(tex_size.x / 2.0, third.y), Vector2(tex_size.x / 2.0, third.y)), glow)


	# ----------------------------------------------------------------------------
	#  TOUCH / MOUSE INPUT
	# ----------------------------------------------------------------------------
	func _input(event: InputEvent) -> void:
		if not input_enabled or not is_visible_in_tree() or skin == null:
			return

		if event is InputEventScreenTouch:
			if event.pressed:
				_finger_moved(event.index, event.position)
			else:
				_finger_lifted(event.index)
		elif event is InputEventScreenDrag:
			_finger_moved(event.index, event.position)
		elif _use_real_mouse and event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and event.device != InputEvent.DEVICE_ID_EMULATION:
			if event.pressed:
				_finger_moved(MOUSE_FINGER, event.position)
			else:
				_finger_lifted(MOUSE_FINGER)
		elif _use_real_mouse and event is InputEventMouseMotion \
				and _fingers.has(MOUSE_FINGER) \
				and event.device != InputEvent.DEVICE_ID_EMULATION:
			_finger_moved(MOUSE_FINGER, event.position)


	func _finger_moved(finger: int, screen_position: Vector2) -> void:  # A finger touched down or slid to a new place.
		var local_position := make_canvas_position_local(screen_position)
		var now_holding := _buttons_under(local_position)
		var before: Array = _fingers.get(finger, [])

		if _same_buttons(now_holding, before):
			return

		var entered_new_button := false
		for action in now_holding:
			if not before.has(action):
				entered_new_button = true

		_fingers[finger] = now_holding
		for action in before:
			_touch_counts[action] = maxi(0, _touch_counts.get(action, 0) - 1)
		for action in now_holding:
			_touch_counts[action] = _touch_counts.get(action, 0) + 1

		if entered_new_button:
			buzz()
		queue_redraw()


	func _finger_lifted(finger: int) -> void:  # A finger left the screen.
		var before: Array = _fingers.get(finger, [])
		_fingers.erase(finger)
		for action in before:
			_touch_counts[action] = maxi(0, _touch_counts.get(action, 0) - 1)
		queue_redraw()


	# ==============================
	# Which buttons are under this point? (The D-pad can return two, for diagonals.)
	# ==============================
	func _buttons_under(point: Vector2) -> Array:
		for piece in skin.controls:
			if piece == null or piece.kind == MobilenesSkin.Piece.Kind.DECORATION or not _mine(piece):
				continue
			var area := piece.get_touch_rect()
			if not area.has_point(point):
				continue
			if piece.kind == MobilenesSkin.Piece.Kind.BUTTON:
				return [piece.action]
			return _dpad_directions(point, area, piece.dpad_dead_zone)
		return []


	func _dpad_directions(point: Vector2, area: Rect2, dead_zone: float) -> Array:
		var offset := (point - area.get_center()) / (area.size / 2.0)  # -1 .. +1 across the touch area, 0 in the middle.
		var result: Array = []
		if offset.y < -dead_zone:
			result.append(&"pad_up")
		elif offset.y > dead_zone:
			result.append(&"pad_down")
		if offset.x < -dead_zone:
			result.append(&"pad_left")
		elif offset.x > dead_zone:
			result.append(&"pad_right")
		return result


	func _same_buttons(first: Array, second: Array) -> bool:
		if first.size() != second.size():
			return false
		for action in first:
			if not second.has(action):
				return false
		return true


	# ----------------------------------------------------------------------------
	#  SENDING BUTTON PRESSES TO THE GAME (+ TURBO)
	# ----------------------------------------------------------------------------
	func _process(delta: float) -> void:
		var turbo_running := false  # the turbo clock runs only while a turbo button is active, so the first press is instant
		for action in _actions:
			if _turbo_wanted(action):
				turbo_running = true
				break
		if turbo_running:
			_turbo_clock += delta
		else:
			_turbo_clock = 0.0
		_turbo_down = int(_turbo_clock * turbo_rate * 2.0) % 2 == 0

		for action in _actions:
			_send_if_changed(action, _should_be_down(action))


	func _turbo_wanted(action: StringName) -> bool:
		# Touch button with turbo switched on in the skin / settings.
		if _touch_counts.get(action, 0) > 0 and _turbo_flags.get(action, false):
			return true
		# Keyboard turbo keys (default: C = turbo A, V = turbo B).
		if action == &"pad_a" and InputMap.has_action(&"pad_turbo_a") \
				and Input.is_action_pressed(&"pad_turbo_a"):
			return true
		if action == &"pad_b" and InputMap.has_action(&"pad_turbo_b") \
				and Input.is_action_pressed(&"pad_turbo_b"):
			return true
		return false


	func _should_be_down(action: StringName) -> bool:
		if _turbo_wanted(action):
			return _turbo_down
		return _touch_counts.get(action, 0) > 0


	func _send_if_changed(action: StringName, down: bool) -> void:
		if _sent.get(action, false) == down:
			return
		_sent[action] = down
		var press := InputEventAction.new()
		press.action = action
		press.pressed = down
		press.strength = 1.0 if down else 0.0
		Input.parse_input_event(press)


	func _rebuild_from_skin() -> void:  # Collects every action the skin can press, and the turbo settings.
		_actions.clear()
		_turbo_flags.clear()
		if skin == null:
			return
		for piece in skin.controls:
			if piece == null:
				continue
			if piece.kind == MobilenesSkin.Piece.Kind.BUTTON:
				_add_action(piece.action)
				_turbo_flags[piece.action] = piece.turbo
			elif piece.kind == MobilenesSkin.Piece.Kind.DPAD:
				for direction in [&"pad_up", &"pad_down", &"pad_left", &"pad_right"]:
					_add_action(direction)
		# The keyboard turbo keys always act on A and B.
		_add_action(&"pad_a")
		_add_action(&"pad_b")


	func _add_action(action: StringName) -> void:
		if not _actions.has(action):
			_actions.append(action)


	# ----------------------------------------------------------------------------
	#  VIBRATION
	# ----------------------------------------------------------------------------
	## One short buzz (if vibration is on). The pull handle uses it when it passes the "open" line.
	func buzz() -> void:
		if not vibration:
			return
		if OS.has_feature("web"):
			# Works in Chrome on Android. iPhones do not allow web vibration.
			JavaScriptBridge.eval("if (navigator.vibrate) { navigator.vibrate(%d); }" % vibration_ms)
		else:
			# Android / iOS apps. Does nothing on a normal computer.
			Input.vibrate_handheld(vibration_ms)


	# ==============================
	# If the pad gets hidden (for example the window switches to desktop mode),
	# let go of everything so no button stays stuck.
	# ==============================
	func _on_visibility_changed() -> void:
		if not visible:
			_fingers.clear()
			_touch_counts.clear()
			queue_redraw()


# =================================================================================================================
# 6. SIDE PANELS
# =================================================================================================================

class SidePanel extends Control:
	## One side of the gamepad in the "sides" layout: draws its half of the skin's body picture
	## (top band, stretchy middle, bottom band) so it fills any size, and holds the Pad on top.

	var body: Texture2D  # The skin's body picture and the part of it (in picture pixels) this panel shows.
	var source_x := 0.0
	var source_width := 128.0
	var band_top := 22.0  # Heights (picture pixels) of the bands at the top and bottom that must not be stretched.
	var band_bottom := 6.0
	var pixel_scale := 1.0:  # How many screen pixels one picture pixel is.
		set(v):
			pixel_scale = v
			queue_redraw()


	func _draw() -> void:
		if body == null:
			return
		var h := body.get_height()
		var top := band_top * pixel_scale
		var bottom := band_bottom * pixel_scale
		draw_texture_rect_region(body, Rect2(0, 0, size.x, top), Rect2(source_x, 0, source_width, band_top))
		draw_texture_rect_region(body, Rect2(0, top, size.x, size.y - top - bottom),
				Rect2(source_x, band_top, source_width, h - band_top - band_bottom))
		draw_texture_rect_region(body, Rect2(0, size.y - bottom, size.x, bottom),
				Rect2(source_x, h - band_bottom, source_width, band_bottom))


# =================================================================================================================
# 7. THE BUTTON LIST
# =================================================================================================================

class Actions extends RefCounted:
	## The list of pad buttons, and their default keyboard / gamepad keys.
	##
	## Your game should read these actions (they work for keyboard, gamepad AND
	## the on-screen touch pad all at once):
	##
	##   pad_up  pad_down  pad_left  pad_right   -> the direction cross
	##   pad_a   pad_b                           -> the two round buttons
	##   pad_start   pad_select                  -> the two small buttons
	##   pad_x   pad_y                           -> two more face buttons
	##   pad_l1 pad_l2 pad_r1 pad_r2             -> shoulder buttons / triggers
	##   pad_l3 pad_r3                           -> stick clicks
	##   pad_rs_up/down/left/right               -> the right stick (the left stick is the direction cross)
	## (A skin only SHOWS the buttons it has pictures for; a keyboard or real gamepad can use them all.)
	## Your game does not have to use these names: it can turn each pad button into its own button name with a
	## table of its own, one line per button (for example pad_a -> attack).
	##
	## Example inside a game script:
	##   if Input.is_action_just_pressed("pad_a"):
	##       jump()
	##
	## Extra buttons Mobilenes handles for you:
	##   pad_menu                     -> opens the Mobilenes menu (F1; on a phone, pull the red M)
	##   pad_turbo_a / pad_turbo_b    -> hold to rapid-fire A or B
	##
	## Mobilenes adds any of these that are missing when the game starts, so you do
	## not have to set up the Input Map yourself. The skin's skin.ini can then
	## change the keys of the buttons it lists, and the player can change them
	## again in the Mobilenes menu.

	const GAMEPLAY: Array[StringName] = [  # The pad buttons a game can listen to (all of them are created for you).
		&"pad_up", &"pad_down", &"pad_left", &"pad_right",
		&"pad_a", &"pad_b", &"pad_x", &"pad_y", &"pad_start", &"pad_select",
		&"pad_l1", &"pad_l2", &"pad_r1", &"pad_r2", &"pad_l3", &"pad_r3",
		&"pad_rs_up", &"pad_rs_down", &"pad_rs_left", &"pad_rs_right",
	]

	const DEFAULTS := {  # Default keys. "axes" are analog stick directions: [axis, direction].
		&"pad_up": {"keys": [KEY_UP, KEY_W], "buttons": [JOY_BUTTON_DPAD_UP], "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
		&"pad_down": {"keys": [KEY_DOWN, KEY_S], "buttons": [JOY_BUTTON_DPAD_DOWN], "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
		&"pad_left": {"keys": [KEY_LEFT, KEY_A], "buttons": [JOY_BUTTON_DPAD_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
		&"pad_right": {"keys": [KEY_RIGHT, KEY_D], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
		&"pad_a": {"keys": [KEY_X, KEY_K], "buttons": [JOY_BUTTON_A], "axes": []},
		&"pad_b": {"keys": [KEY_Z, KEY_J], "buttons": [JOY_BUTTON_B], "axes": []},
		&"pad_start": {"keys": [KEY_ENTER], "buttons": [JOY_BUTTON_START], "axes": []},
		&"pad_select": {"keys": [KEY_BACKSPACE, KEY_SHIFT], "buttons": [JOY_BUTTON_BACK], "axes": []},
		&"pad_x": {"keys": [KEY_U], "buttons": [JOY_BUTTON_X], "axes": []},
		&"pad_y": {"keys": [KEY_O], "buttons": [JOY_BUTTON_Y], "axes": []},
		&"pad_l1": {"keys": [KEY_Q], "buttons": [JOY_BUTTON_LEFT_SHOULDER], "axes": []},
		&"pad_r1": {"keys": [KEY_E], "buttons": [JOY_BUTTON_RIGHT_SHOULDER], "axes": []},
		&"pad_l2": {"keys": [KEY_F], "buttons": [], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
		&"pad_r2": {"keys": [KEY_G], "buttons": [], "axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
		&"pad_l3": {"keys": [], "buttons": [JOY_BUTTON_LEFT_STICK], "axes": []},
		&"pad_r3": {"keys": [], "buttons": [JOY_BUTTON_RIGHT_STICK], "axes": []},
		&"pad_rs_up": {"keys": [], "buttons": [], "axes": [[JOY_AXIS_RIGHT_Y, -1.0]]},
		&"pad_rs_down": {"keys": [], "buttons": [], "axes": [[JOY_AXIS_RIGHT_Y, 1.0]]},
		&"pad_rs_left": {"keys": [], "buttons": [], "axes": [[JOY_AXIS_RIGHT_X, -1.0]]},
		&"pad_rs_right": {"keys": [], "buttons": [], "axes": [[JOY_AXIS_RIGHT_X, 1.0]]},
		&"pad_menu": {"keys": [KEY_F1], "buttons": [JOY_BUTTON_GUIDE], "axes": []},
		&"pad_turbo_a": {"keys": [KEY_C], "buttons": [], "axes": []},
		&"pad_turbo_b": {"keys": [KEY_V], "buttons": [], "axes": []},
	}

	const GAMEPAD_BUTTON_NAMES := {  # Short names for gamepad buttons (used in the menu).
		0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 5: "Guide", 6: "Start",
		7: "LeftStick", 8: "RightStick", 9: "LB", 10: "RB",
		11: "DpadUp", 12: "DpadDown", 13: "DpadLeft", 14: "DpadRight",
	}


	static func ensure_defaults() -> void:  # Creates every pad_* action that does not exist yet.
		for action in DEFAULTS:
			if not InputMap.has_action(action):
				InputMap.add_action(action, 0.5)
				_fill_with_defaults(action)


	static func reset_to_defaults() -> void:  # Puts EVERY pad_* action back to its default keys and buttons.
		for action in DEFAULTS:
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
			else:
				InputMap.add_action(action, 0.5)
			_fill_with_defaults(action)


	# ==============================
	# Applies the keys / gamepad buttons in "bindings" (a skin's, or a player's).
	# Format: { action: { "keys": [key codes], "buttons": [gamepad button codes] } }
	# Only the parts that are mentioned are replaced; the rest stays as it was.
	# ==============================
	static func apply_bindings(bindings: Dictionary) -> void:
		for action_key in bindings:
			var action := StringName(action_key)
			var entry: Dictionary = bindings[action_key]
			if not InputMap.has_action(action):
				InputMap.add_action(action, 0.5)
			if entry.has("keys"):
				_remove_events(action, InputEventKey)
				for code in entry["keys"]:
					var key_event := InputEventKey.new()
					key_event.physical_keycode = int(code) as Key
					InputMap.action_add_event(action, key_event)
			if entry.has("buttons"):
				_remove_events(action, InputEventJoypadButton)
				for code in entry["buttons"]:
					var button_event := InputEventJoypadButton.new()
					button_event.button_index = int(code) as JoyButton
					InputMap.action_add_event(action, button_event)


	static func get_key_codes(action: StringName) -> Array:  # The key codes currently assigned to an action.
		var codes: Array = []
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				if event is InputEventKey:
					codes.append(int(event.physical_keycode) if event.physical_keycode != KEY_NONE else int(event.keycode))
		return codes


	# ==============================
	# The gamepad button numbers currently assigned to an action.
	# ==============================
	static func get_button_codes(action: StringName) -> Array:
		var codes: Array = []
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadButton:
					codes.append(int(event.button_index))
		return codes


	static func key_name(code: int) -> String:  # A readable name for a key code, for example "Enter" or "X".
		return OS.get_keycode_string(code as Key)


	static func button_name(code: int) -> String:  # A readable name for a gamepad button number, for example "Start".
		return GAMEPAD_BUTTON_NAMES.get(code, "Button %d" % code)


	static func _fill_with_defaults(action: StringName) -> void:
		var defaults: Dictionary = DEFAULTS[action]
		for key in defaults["keys"]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = key as Key
			InputMap.action_add_event(action, key_event)
		for button in defaults["buttons"]:
			var button_event := InputEventJoypadButton.new()
			button_event.button_index = button as JoyButton
			InputMap.action_add_event(action, button_event)
		for axis in defaults["axes"]:
			var axis_event := InputEventJoypadMotion.new()
			axis_event.axis = axis[0] as JoyAxis
			axis_event.axis_value = axis[1]
			InputMap.action_add_event(action, axis_event)


	static func _remove_events(action: StringName, event_type: Object) -> void:
		for event in InputMap.action_get_events(action):
			if is_instance_of(event, event_type):
				InputMap.action_erase_event(action, event)
