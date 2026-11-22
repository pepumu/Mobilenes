class_name MobilenesSkin
extends Resource
## MobilenesSkin - everything about ONE gamepad look, in one file.
##
## The file has three parts, each with a heading:
##   1. THE SKIN       what a skin is made of (name, size, where the game screen sits ...)
##   2. THE PIECES     one picture of the pad, and for buttons its touch area (class Piece)
##   3. THE LOADER     reads a skin FOLDER (its skin.ini and pictures) into a MobilenesSkin
##
## To make a skin, make a folder with a skin.ini file (see skins/ascii).

# =================================================================================================================
# 1. THE SKIN
# =================================================================================================================
## A complete on-screen gamepad "look": the pictures, where every button is,
## and which keys they use.
##
## It is made from a skin FOLDER with a skin.ini file (see skins/ascii for an example).

@export var skin_name := "My skin"  # A name for the skin.

@export var preview: Texture2D  # A small picture that shows what the skin looks like (optional).

# ==============================
# Total size of the layout. The Famicube skin is 512 x 240:
# 128 pixels of pad on the left, the 256 pixel game screen, 128 on the right.
# ==============================
@export var design_size := Vector2(512, 240)

# ==============================
# Where the game screen sits inside the layout (x, y, width, height).
# (Its size is the game size, for example 640 x 400.)
# ==============================
@export var screen_rect := Rect2(128, 0, 256, 240)

@export var controls: Array[Piece] = []  # All the pieces, drawn from first (back) to last (front).

@export var menu_color := Color("e4002b")  # colour of the menu pull handle (skin.ini: menu_color = e4002b)

# ==============================
# Keyboard keys / gamepad buttons the skin asks for.
# Format: { action_name: { "keys": [key codes], "buttons": [gamepad button codes] } }
# ==============================
@export var bindings: Dictionary = {}


# ==============================
# "Sides" layout: the pad is two panels (left and right) that GROW to fill the space beside the game screen,
# instead of one fixed picture with a hole in the middle. In skin.ini:  layout = sides
# The left panel is design x 0 .. left_width, the right panel is design x right_start .. width.
# ==============================
@export var sides := false
@export var left_width := 128.0
@export var right_start := 384.0
@export var screen_background: Texture2D  # one picture drawn behind the game, filling the window (skin.ini: screen_background)
@export var screen_frame: Texture2D  # a frame drawn around the game's picture as a 9-patch (skin.ini: screen_frame)
@export var screen_frame_patch := Vector4.ZERO  # its borders in picture pixels: left, top, right, bottom (skin.ini: screen_frame_patch)
@export var body: Texture2D  # The picture the two panels are cut from (the skin's background).


# =================================================================================================================
# 2. THE PIECES - one picture of the pad (and, for buttons, a touch area)
# =================================================================================================================

class Piece extends Resource:
	## One piece of a gamepad skin: a picture and, for buttons, a touch area.
	##
	## They are created from the skin.ini file of a skin folder.
	##
	## All positions are measured in the "design space" of the skin. For the
	## Famicube skin that is 512 wide and 240 tall: the game screen sits in the
	## middle (x 128 to 384) and the pad pieces sit on the left and right.

	# ==============================
	# What does this piece do?
	#   DECORATION = just a picture (body, labels, frames). Cannot be touched.
	#   BUTTON     = a single button (A, B, Start, Select ...).
	#   DPAD       = the direction cross. Handles up/down/left/right and diagonals.
	# ==============================
	enum Kind { DECORATION, BUTTON, DPAD }

	@export var label := "Piece"  # A friendly name, only for you.

	@export var kind: Kind = Kind.DECORATION  # The type of piece (see above).

	@export var action: StringName = &""  # Which game action this button triggers (for example pad_a).

	@export var texture: Texture2D  # The picture shown normally.

	@export var pressed_texture: Texture2D  # picture shown while held down (empty = the normal picture, darkened)

	@export var position := Vector2.ZERO  # Where the CENTER of the picture sits (x, y).

	@export var touch_size := Vector2.ZERO  # size of the invisible touch area (0,0 = the picture's size)

	@export var touch_offset := Vector2.ZERO  # moves the touch area off the picture's center (0,0 = centered)

	# ==============================
	# DPAD only: how far from the middle a finger must be before a direction
	# counts (0.25 = a quarter of the way to the edge).
	# ==============================
	@export_range(0.0, 0.9) var dpad_dead_zone := 0.25

	@export var turbo := false  # If ON, holding this button repeats it quickly ("turbo" / autofire).

	@export var draw_size := Vector2.ZERO  # size the picture is stretched to as a 9-patch (0,0 = the picture's own size)

	@export var patch_margins := Vector4.ZERO  # 9-patch borders kept as drawn: left, top, right, bottom (picture pixels)

	@export var legend: Texture2D  # small picture drawn on top of a button (the letters on a key, for example)

	@export var legend_offset := Vector2.ZERO  # where the legend's top-left corner sits, from the button's top-left corner


	func get_size() -> Vector2:  # The size the piece is drawn at: its 9-patch size, or else its picture's size.
		if draw_size != Vector2.ZERO:
			return draw_size
		return texture.get_size() if texture != null else Vector2.ZERO


	func get_touch_rect() -> Rect2:  # The touch area as a rectangle (used by the pad). You do not need to call this.
		var rect_size := touch_size
		if rect_size == Vector2.ZERO:
			rect_size = get_size()
		return Rect2(position + touch_offset - rect_size / 2.0, rect_size)


# =================================================================================================================
# 3. THE LOADER - reads a skin FOLDER
# =================================================================================================================
## Reads a gamepad skin from a FOLDER.
##
## A skin folder contains:
##   skin.ini  - a plain text file describing everything (see the Famicube one,
##               it is full of explanations)
##   *.png     - the pictures the skin.ini talks about
##
## To use a skin: put its folder anywhere in your project (for example inside
## addons/mobilenes/skins/) and select that folder in Mobilenes's "Skin Folder" setting.
##
## Mistakes in skin.ini never crash the game. They show up as yellow warnings in
## Godot's Output panel, with the line number, and the bad entry is skipped.

const SKIN_FILE := "skin.ini"  # The name of the description file inside a skin folder.

const GAMEPAD_NAMES := {  # Names you can use in the "gamepad = ..." lines of skin.ini.
	"a": JOY_BUTTON_A, "b": JOY_BUTTON_B, "x": JOY_BUTTON_X, "y": JOY_BUTTON_Y,
	"back": JOY_BUTTON_BACK, "select": JOY_BUTTON_BACK,
	"start": JOY_BUTTON_START, "guide": JOY_BUTTON_GUIDE,
	"leftstick": JOY_BUTTON_LEFT_STICK, "rightstick": JOY_BUTTON_RIGHT_STICK,
	"leftshoulder": JOY_BUTTON_LEFT_SHOULDER, "lb": JOY_BUTTON_LEFT_SHOULDER, "l1": JOY_BUTTON_LEFT_SHOULDER,
	"rightshoulder": JOY_BUTTON_RIGHT_SHOULDER, "rb": JOY_BUTTON_RIGHT_SHOULDER, "r1": JOY_BUTTON_RIGHT_SHOULDER,
	"dpadup": JOY_BUTTON_DPAD_UP, "dpaddown": JOY_BUTTON_DPAD_DOWN,
	"dpadleft": JOY_BUTTON_DPAD_LEFT, "dpadright": JOY_BUTTON_DPAD_RIGHT,
}

const KEY_ALIASES := {  # Friendly names for keyboard keys (anything else is looked up by Godot itself).
	"enter": KEY_ENTER, "return": KEY_ENTER, "space": KEY_SPACE,
	"backspace": KEY_BACKSPACE, "tab": KEY_TAB, "escape": KEY_ESCAPE, "esc": KEY_ESCAPE,
	"shift": KEY_SHIFT, "ctrl": KEY_CTRL, "control": KEY_CTRL, "alt": KEY_ALT,
	"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
	"minus": KEY_MINUS, "equals": KEY_EQUAL, "plus": KEY_KP_ADD,
}


# ==============================
# Returns the folders inside "directory" that contain a skin.ini.
# ==============================
static func list_skins(directory: String) -> PackedStringArray:
	var result := PackedStringArray()
	for folder_name in DirAccess.get_directories_at(directory):
		var folder := directory.path_join(folder_name)
		if FileAccess.file_exists(folder.path_join(SKIN_FILE)):
			result.append(folder)
	return result


# ==============================
# Loads the skin in "folder". Returns null if the folder has no usable skin.ini.
# ==============================
static func load_folder(folder: String) -> MobilenesSkin:
	var ini_path := folder.path_join(SKIN_FILE)
	if not FileAccess.file_exists(ini_path):
		push_warning("Mobilenes skin: could not find '%s'. (In an exported game, add *.ini under Export > Resources > 'Filters to export non-resource files'.)" % ini_path)
		return null

	var sections := _parse_ini(FileAccess.get_file_as_string(ini_path), ini_path)
	var skin := MobilenesSkin.new()
	skin.skin_name = folder.get_file()
	var controls: Array[Piece] = []

	# The [skin] section goes first: it tells us the size and the background.
	for section in sections:
		if section["kind"] == "skin":
			_read_skin_section(section, skin, controls, folder, ini_path)

	# Everything else is drawn in the order it appears in the file.
	for section in sections:
		match section["kind"]:
			"skin":
				pass
			"picture":
				_read_picture(section, controls, folder, ini_path)
			"button":
				_read_button(section, skin, controls, folder, ini_path)
			"dpad":
				_read_dpad(section, skin, controls, folder, ini_path)
			_:
				_warn(ini_path, section["line"], "unknown section [%s]. Use [skin], [picture], [button NAME] or [dpad]." % section["kind"])

	skin.controls = controls
	return skin


# ----------------------------------------------------------------------------
#  Reading the sections
# ----------------------------------------------------------------------------
static func _read_skin_section(section: Dictionary, skin: MobilenesSkin,
		controls: Array[Piece], folder: String, ini_path: String) -> void:
	var values: Dictionary = section["values"]
	var line: int = section["line"]
	skin.skin_name = values.get("name", skin.skin_name)
	skin.design_size = Vector2(
		_number(values, "width", 512.0, ini_path, line),
		_number(values, "height", 240.0, ini_path, line))
	skin.screen_rect = Rect2(
		_number(values, "screen_x", 128.0, ini_path, line),
		_number(values, "screen_y", 0.0, ini_path, line),
		_number(values, "screen_width", 256.0, ini_path, line),
		_number(values, "screen_height", 240.0, ini_path, line))
	if values.has("menu_color"):
		skin.menu_color = Color.html(String(values["menu_color"]).strip_edges())
	skin.sides = String(values.get("layout", "")).strip_edges().to_lower() == "sides"
	skin.left_width = _number(values, "left_width", skin.screen_rect.position.x, ini_path, line)
	skin.right_start = _number(values, "right_start", skin.design_size.x - skin.left_width, ini_path, line)
	if values.has("screen_background"):
		skin.screen_background = _texture(folder, values["screen_background"], ini_path, line)
	if values.has("screen_frame"):
		skin.screen_frame = _texture(folder, values["screen_frame"], ini_path, line)
		var borders := _split_list(values.get("screen_frame_patch", ""))
		if borders.size() == 4:
			skin.screen_frame_patch = Vector4(float(borders[0]), float(borders[1]), float(borders[2]), float(borders[3]))
		else:
			_warn(ini_path, line, "screen_frame_patch needs four numbers: left, top, right, bottom")
			skin.screen_frame = null
	if values.has("preview"):
		skin.preview = _texture(folder, values["preview"], ini_path, line)
	if values.has("background"):
		var background := Piece.new()
		background.label = "Background"
		background.texture = _texture(folder, values["background"], ini_path, line)
		background.position = skin.design_size / 2.0
		skin.body = background.texture
		if background.texture != null and not skin.sides:
			controls.append(background)


static func _read_picture(section: Dictionary, controls: Array[Piece],
		folder: String, ini_path: String) -> void:
	var values: Dictionary = section["values"]
	var line: int = section["line"]
	if not _require(values, ["image", "x", "y"], "[picture]", ini_path, line):
		return
	var texture := _texture(folder, values["image"], ini_path, line)
	if texture == null:
		return
	var piece := Piece.new()
	piece.label = section["name"] if section["name"] != "" else "Picture"
	piece.kind = Piece.Kind.DECORATION
	piece.texture = texture
	piece.position = Vector2(_number(values, "x", 0.0, ini_path, line), _number(values, "y", 0.0, ini_path, line))
	controls.append(piece)


static func _read_button(section: Dictionary, skin: MobilenesSkin,
		controls: Array[Piece], folder: String, ini_path: String) -> void:
	var values: Dictionary = section["values"]
	var line: int = section["line"]
	var button_name: String = section["name"]
	if button_name == "":
		_warn(ini_path, line, "a [button] needs a name, for example [button a]")
		return
	if not _require(values, ["x", "y"], "[button %s]" % button_name, ini_path, line):
		return

	var piece := Piece.new()
	piece.label = "Button " + button_name
	piece.kind = Piece.Kind.BUTTON
	piece.action = StringName(values.get("action", "pad_" + button_name.to_lower().replace(" ", "_")))
	if values.has("image"):
		piece.texture = _texture(folder, values["image"], ini_path, line)
	if values.has("pressed_image"):
		piece.pressed_texture = _texture(folder, values["pressed_image"], ini_path, line)
	piece.position = Vector2(_number(values, "x", 0.0, ini_path, line), _number(values, "y", 0.0, ini_path, line))
	piece.turbo = _boolean(values, "turbo", false, ini_path, line)
	if values.has("width") or values.has("height"):  # stretched as a 9-patch to this size
		var own := piece.texture.get_size() if piece.texture != null else Vector2.ZERO
		piece.draw_size = Vector2(_number(values, "width", own.x, ini_path, line), _number(values, "height", own.y, ini_path, line))
	if values.has("patch"):
		var borders := _split_list(values["patch"])
		if borders.size() == 4:
			piece.patch_margins = Vector4(float(borders[0]), float(borders[1]), float(borders[2]), float(borders[3]))
		else:
			_warn(ini_path, line, "patch needs four numbers: left, top, right, bottom")
	if values.has("legend"):
		piece.legend = _texture(folder, values["legend"], ini_path, line)
		piece.legend_offset = Vector2(_number(values, "legend_x", 0.0, ini_path, line), _number(values, "legend_y", 0.0, ini_path, line))

	if not _read_touch_area(piece, values, ini_path, line, "[button %s]" % button_name):
		return
	_read_bindings(piece.action, values, "keys", "gamepad", skin.bindings, ini_path, line)
	controls.append(piece)


static func _read_dpad(section: Dictionary, skin: MobilenesSkin,
		controls: Array[Piece], folder: String, ini_path: String) -> void:
	var values: Dictionary = section["values"]
	var line: int = section["line"]
	if not _require(values, ["image", "x", "y"], "[dpad]", ini_path, line):
		return

	var piece := Piece.new()
	piece.label = "Direction cross"
	piece.kind = Piece.Kind.DPAD
	piece.texture = _texture(folder, values["image"], ini_path, line)
	piece.position = Vector2(_number(values, "x", 0.0, ini_path, line), _number(values, "y", 0.0, ini_path, line))
	piece.dpad_dead_zone = clampf(_number(values, "dead_zone", 25.0, ini_path, line), 0.0, 90.0) / 100.0

	if not _read_touch_area(piece, values, ini_path, line, "[dpad]"):
		return
	for direction in ["up", "down", "left", "right"]:
		_read_bindings(StringName("pad_" + direction), values,
				direction + "_keys", direction + "_gamepad", skin.bindings, ini_path, line)
	controls.append(piece)


# ==============================
# Reads touch_x, touch_y (center), touch_width, touch_height.
# Anything missing falls back to the picture's own position and size.
# ==============================
static func _read_touch_area(piece: Piece, values: Dictionary,
		ini_path: String, line: int, where: String) -> bool:
	var picture_size := piece.get_size()  # the 9-patch size when there is one, else the picture's own size
	piece.touch_size = Vector2(
		_number(values, "touch_width", picture_size.x, ini_path, line),
		_number(values, "touch_height", picture_size.y, ini_path, line))
	if piece.touch_size == Vector2.ZERO:
		_warn(ini_path, line, "%s has no picture, so it needs touch_width and touch_height" % where)
		return false
	var touch_center := Vector2(
		_number(values, "touch_x", piece.position.x, ini_path, line),
		_number(values, "touch_y", piece.position.y, ini_path, line))
	piece.touch_offset = touch_center - piece.position
	return true


# ==============================
# Reads the keyboard keys and gamepad buttons for one action.
# If a line is missing, the default keys of that button are kept.
# ==============================
static func _read_bindings(action: StringName, values: Dictionary, keys_field: String,
		pad_field: String, bindings: Dictionary, ini_path: String, line: int) -> void:
	var entry: Dictionary = bindings.get(action, {})
	if values.has(keys_field):
		var key_codes: Array = []
		for token in _split_list(values[keys_field]):
			var code := _key_from_name(token)
			if code == KEY_NONE:
				_warn(ini_path, line, "'%s' is not a keyboard key I know (in %s)" % [token, keys_field])
			else:
				key_codes.append(code)
		entry["keys"] = key_codes
	if values.has(pad_field):
		var button_codes: Array = []
		for token in _split_list(values[pad_field]):
			var normalized := token.to_lower().replace(" ", "").replace("_", "").replace("-", "")
			if GAMEPAD_NAMES.has(normalized):
				button_codes.append(GAMEPAD_NAMES[normalized])
			elif token.is_valid_int():
				button_codes.append(token.to_int())
			else:
				_warn(ini_path, line, "'%s' is not a gamepad button I know (in %s)" % [token, pad_field])
		entry["buttons"] = button_codes
	if not entry.is_empty():
		bindings[action] = entry


# ----------------------------------------------------------------------------
#  Reading the text file
# ----------------------------------------------------------------------------
# Turns the text into a list of sections. Each section remembers its type
# ("button"), its name ("a"), its line number and its key = value pairs.
static func _parse_ini(text: String, ini_path: String) -> Array:
	var sections: Array = []
	var current: Dictionary = {}
	var line_number := 0
	for raw_line in text.split("\n"):
		line_number += 1
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue

		if line.begins_with("["):
			if not line.ends_with("]"):
				_warn(ini_path, line_number, "a section title must end with ]")
				current = {}
				continue
			var header := line.substr(1, line.length() - 2).strip_edges()
			var kind := header.get_slice(" ", 0).to_lower()
			current = {
				"kind": kind,
				"name": header.substr(kind.length()).strip_edges(),
				"line": line_number,
				"values": {},
			}
			sections.append(current)
			continue

		var equals := line.find("=")
		if equals < 0 or current.is_empty():
			_warn(ini_path, line_number, "expected 'name = value' inside a [section]")
			continue
		var key := line.substr(0, equals).strip_edges().to_lower()
		var value := line.substr(equals + 1).strip_edges()
		var comment_start := value.find(" ;")
		if comment_start >= 0:
			value = value.substr(0, comment_start).strip_edges()
		if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
			value = value.substr(1, value.length() - 2)
		current["values"][key] = value
	return sections


# ----------------------------------------------------------------------------
#  Small helpers
# ----------------------------------------------------------------------------
static func _require(values: Dictionary, fields: Array, where: String,
		ini_path: String, line: int) -> bool:
	for field in fields:
		if not values.has(field):
			_warn(ini_path, line, "%s is missing '%s', so it was skipped" % [where, field])
			return false
	return true


static func _number(values: Dictionary, key: String, fallback: float,
		ini_path: String, line: int) -> float:
	if not values.has(key):
		return fallback
	var text: String = values[key]
	if text.is_valid_float():
		return text.to_float()
	_warn(ini_path, line, "'%s' should be a number but it is '%s'" % [key, text])
	return fallback


static func _boolean(values: Dictionary, key: String, fallback: bool,
		ini_path: String, line: int) -> bool:
	if not values.has(key):
		return fallback
	var text := String(values[key]).to_lower()
	if text in ["true", "yes", "on", "1"]:
		return true
	if text in ["false", "no", "off", "0", ""]:
		return false
	_warn(ini_path, line, "'%s' should be true or false but it is '%s'" % [key, text])
	return fallback


static func _split_list(text: String) -> PackedStringArray:
	var result := PackedStringArray()
	for part in text.split(","):
		var cleaned := part.strip_edges()
		if cleaned != "":
			result.append(cleaned)
	return result


static func _key_from_name(key_name: String) -> int:
	var lower := key_name.to_lower()
	if KEY_ALIASES.has(lower):
		return KEY_ALIASES[lower]
	for candidate in [key_name, key_name.to_upper(), key_name.capitalize()]:
		var code: int = OS.find_keycode_from_string(candidate)
		if code != KEY_NONE:
			return code
	return KEY_NONE


# ==============================
# Loads a picture from the skin folder. Works for pictures Godot has imported
# (inside your project) and for loose PNG files (for example in user://).
# ==============================
static func _texture(folder: String, file_name: String, ini_path: String, line: int) -> Texture2D:
	var path := folder.path_join(file_name)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			return ImageTexture.create_from_image(image)
	_warn(ini_path, line, "picture '%s' was not found in the skin folder" % file_name)
	return null


static func _warn(ini_path: String, line: int, message: String) -> void:
	push_warning("Mobilenes skin (%s, line %d): %s" % [ini_path, line, message])
