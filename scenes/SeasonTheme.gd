class_name SeasonTheme
extends RefCounted

## The look of every menu, one per season.
##
## Nothing here is a node and nothing here is saved: a menu calls
## `SeasonTheme.make_theme("autumn")` and puts the result on its root Control,
## and every Button, Label, panel, slider and check box under it is styled from
## that. Changing season is just making a new theme and swapping it in.
##
## Each season has its own colours - a strong colour, a pale tint for panels, a
## dark colour for borders and text, and the colour of the keyboard focus ring -
## and its panels are pixel-art frames with that season's decorations on them:
## flowers in Spring, a sun and waves in Summer, leaves in Autumn, and snow and
## icicles in Winter. The four strong colours are the ones the proposal's
## screen-flow figure uses for the four seasons.

const ORDER: Array[String] = ["spring", "summer", "autumn", "winter"]

## The wireframes' outline colour. Winter's dark colour is close to it; the other
## seasons now use their own.
const NAVY := Color("1f3b73")
const WHITE := Color(1, 1, 1)

## The strong colour of each season: filled buttons, the badge, slider fill.
const MAIN := {
	"spring": Color("6bbf67"),
	"summer": Color("f3b843"),
	"autumn": Color("e07a30"),
	"winter": Color("80b5e3"),
}

## A pale tint of the same colour, for panel backgrounds.
const PANEL := {
	"spring": Color("f1faec"),
	"summer": Color("fff6dc"),
	"autumn": Color("fcecdc"),
	"winter": Color("eef5fc"),
}

## The fill of an ordinary button: lighter than the panel it sits on, but still
## tinted with its season instead of plain white.
const BUTTON := {
	"spring": Color("fbfff8"),
	"summer": Color("fffcf0"),
	"autumn": Color("fff7f0"),
	"winter": Color("f8fbff"),
}

## The colour a button turns when the mouse is over it.
const HOVER := {
	"spring": Color("d9f0d3"),
	"summer": Color("ffe9ad"),
	"autumn": Color("f8d2b0"),
	"winter": Color("d3e6f7"),
}

## The dark colour of each season: every border and all the text. Each one is
## dark enough to read easily on that season's pale panel.
const DARK := {
	"spring": Color("2f6b33"),
	"summer": Color("7a4f10"),
	"autumn": Color("6b3210"),
	"winter": Color("1f4a7a"),
}

## The ring drawn round whichever control the keyboard is on. It has to stand out
## from both the season colour and the dark border, so it is a different colour in
## each season.
const FOCUS := {
	"spring": Color("e2559a"),
	"summer": Color("1e88c7"),
	"autumn": Color("b8321f"),
	"winter": Color("e07a30"),
}

## The sky behind each season, matching the levels where they have one.
## Spring's level has a plain white background, so the title screen gives it a
## soft green sky instead, so it reads as spring and not as an empty screen.
const SKY := {
	"spring": Color(0.88, 0.96, 0.86),
	"summer": Color(0.64, 0.83, 0.95),
	"autumn": Color(0.96, 0.87, 0.72),
	"winter": Color(0.85, 0.9, 0.96),
}

const SEASON_NAMES := {
	"spring": "Spring",
	"summer": "Summer",
	"autumn": "Autumn",
	"winter": "Winter",
}

const ANIMAL_NAMES := {
	"spring": "Cats",
	"summer": "Dogs",
	"autumn": "Foxes",
	"winter": "Penguins",
}

const FONT_SIZE := 22
const TITLE_FONT_SIZE := 72
const HEADING_FONT_SIZE := 36
const CORNER_RADIUS := 4
const BORDER := 3
## How much thicker a button's bottom edge is than its other edges, so it looks
## like a chunky pixel key. Pressing it squashes the edge and moves the words down.
const BUTTON_DEPTH := 4

# --- The pixel-art panel frames --------------------------------------------
#
# Every panel is drawn from one small picture, 24 x 24 "art pixels", scaled up
# PIXEL_SCALE times. The picture is written out as text below, one character per
# art pixel, so it can be changed without any drawing program:
#   .  nothing (see-through)      B  the season's dark border
#   L  a light inner edge         F  the panel's fill
#   D  a slightly darker edge     1-5  the season's decoration colours
#
# The outermost 4 art pixels on every side are outside the box: the frame itself
# starts at the fifth row and column. They are there so decorations can stick out
# past the edge of the box - flowers and leaves on the corners, snow piled on top.
#
# Godot stretches the picture to fit each panel: the outer 10 art pixels on every
# side are drawn as they are, and the middle 4 are repeated. So decorations must
# stay in the corners (the first and last 10 rows and columns), unless they repeat
# every 4 art pixels, like Winter's snow and Summer's waves.

const PIXEL_SCALE := 5
## The see-through ring round the frame, in art pixels.
const FRAME_OUTSIDE := 4
## How much of each side is drawn as it is rather than repeated, in art pixels.
const FRAME_MARGIN := 10

const FRAME := [
	"........................",
	"........................",
	"........................",
	"........................",
	"......BBBBBBBBBBBB......",
	".....BLLLLLLLLLLLLB.....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	"....BLFFFFFFFFFFFFDB....",
	".....BDDDDDDDDDDDDB.....",
	"......BBBBBBBBBBBB......",
	"........................",
	"........................",
	"........................",
	"........................",
]
## Little pictures drawn on top of the frame. Same characters as FRAME, and a "."
## here means "leave the frame as it is".
const FLOWER := [
	"..11.11..",
	".1111111.",
	"111111111",
	".1122211.",
	"111222111",
	".1122211.",
	"111111111",
	".1111111.",
	"..11.11..",
]
## A tulip on its stem, growing up out of the bottom corners.
const TULIP := [
	"1.1.1",
	"11111",
	"11111",
	".111.",
	"..5..",
	"5.5.5",
	".555.",
	"..5..",
]
const SUN := [
	"2...22...2",
	".2..11..2.",
	"...1111...",
	"..111111..",
	"2111111112",
	"2111111112",
	"..111111..",
	"...1111...",
	".2..11..2.",
	"2...22...2",
]
## Full-width rows, so they repeat along the bottom edge of any panel.
const WAVES := [
	".....3...3...3...3......",
	"....333.333.333.333.....",
	"....3333333333333333....",
	"....4444444444444444....",
]
## A maple leaf, and the same leaf in red.
const LEAF := [
	"....1....",
	"..1.1.1..",
	"..11111..",
	"1.11111.1",
	"111121111",
	".1112111.",
	"..11211..",
	"....2....",
	"....2....",
]
const RED_LEAF := [
	"....3....",
	"..3.3.3..",
	"..33333..",
	"3.33333.3",
	"333323333",
	".3332333.",
	"..33233..",
	"....2....",
	"....2....",
]
const SMALL_LEAF := [
	"...44",
	"..444",
	".4424",
	".424.",
	"2....",
]
## Full-width rows: a slab of snow piled on top of the dark border, heaped up at
## the corners, with long icicles hanging under the corners. The middle of every
## row is the same 4 art pixels over and over, so it repeats cleanly.
const SNOW := [
	"..1111............1111..",
	".1111111........1111111.",
	".1111111111111111111111.",
	"..11111111111111111111..",
	"........................",
	"....222..........222....",
	".....22..........22.....",
	".....22..........22.....",
	"......2..........2......",
	"......3..........3......",
]
## A small heap of snow on each bottom corner.
const SNOW_DRIFT := [
	".111.",
	"11111",
]

## Each season's decorations: [picture, column, row] of its top-left art pixel.
const DECORATIONS := {
	"spring": [[FLOWER, 0, 0], [FLOWER, 15, 0], [TULIP, 2, 14], [TULIP, 17, 14]],
	"summer": [[SUN, 14, 0], [WAVES, 0, 16]],
	"autumn": [[LEAF, 0, 0], [RED_LEAF, 15, 0], [SMALL_LEAF, 2, 16], [SMALL_LEAF, 17, 16]],
	"winter": [[SNOW, 0, 0], [SNOW_DRIFT, 3, 18], [SNOW_DRIFT, 16, 18]],
}

## What the numbers in the decorations mean in each season.
const DECORATION_COLOURS := {
	"spring": {"1": Color("f28db2"), "2": Color("ffd84d"), "5": Color("4f9a3f")},
	"summer": {"1": Color("ffd23f"), "2": Color("f39c12"), "3": Color("3fa7d6"), "4": Color("1e6fa8"),
		"5": Color("ff7b5c"), "6": Color("c94f3a")},
	"autumn": {"1": Color("e8762b"), "2": Color("7a3e14"), "3": Color("c8452b"), "4": Color("f2b134")},
	"winter": {"1": Color("ffffff"), "2": Color("8fc3ee"), "3": Color("5d9fd6")},
}

# --- The little decorations on the title screen's buttons -------------------
#
# Each title button gets one small picture on its top-left corner and another on
# its top-right corner, half on the button and half off it, in the colours above.
# They are drawn BUTTON_DECORATION_SCALE screen pixels per art pixel.

const BUTTON_DECORATION_SCALE := 4

const SMALL_FLOWER := [
	"..111..",
	".11111.",
	"1112111",
	"1122211",
	"1112111",
	".11111.",
	"..111..",
]
const SMALL_YELLOW_FLOWER := [
	"..222..",
	".22222.",
	"2221222",
	"2211122",
	"2221222",
	".22222.",
	"..222..",
]
const STARFISH := [
	"...5...",
	"..555..",
	"5555555",
	".55655.",
	".55.55.",
	"5.....5",
]
const YELLOW_STARFISH := [
	"...1...",
	"..111..",
	"1111111",
	".11211.",
	".11.11.",
	"1.....1",
]
const MINI_LEAF := [
	"...1...",
	".1.1.1.",
	".11111.",
	"1111111",
	".11211.",
	"...2...",
	"...2...",
]
const MINI_RED_LEAF := [
	"...3...",
	".3.3.3.",
	".33333.",
	"3333333",
	".33233.",
	"...2...",
	"...2...",
]
## Blue, not white: a white snowflake would vanish on a pale winter button.
const SNOWFLAKE := [
	"...3...",
	".3.3.3.",
	"..323..",
	"3332333",
	"..323..",
	".3.3.3.",
	"...3...",
]

## [top-left picture, top-right picture] for each season.
const BUTTON_DECORATIONS := {
	"spring": [SMALL_FLOWER, SMALL_YELLOW_FLOWER],
	"summer": [STARFISH, YELLOW_STARFISH],
	"autumn": [MINI_LEAF, MINI_RED_LEAF],
	"winter": [SNOWFLAKE, SNOWFLAKE],
}


## "Spring · Cats", the words on the season badge.
static func badge_text(season: String) -> String:
	return "%s · %s" % [SEASON_NAMES[season], ANIMAL_NAMES[season]]


## The season after this one, in the same order the levels are played.
static func next_season(season: String) -> String:
	return ORDER[(ORDER.find(season) + 1) % ORDER.size()]


## A whole Theme for one season. Put it on a Control's `theme` and everything
## under that Control is styled.
##
## Three named looks ("type variations") are added on top of the normal ones,
## and a node opts into one with `theme_type_variation` in its scene:
## - `PrimaryButton`: the one most likely action (Play, Resume), filled with the
##   season colour, as wireframe notes 1 and 6 ask;
## - `TitleLabel` / `HeadingLabel`: the big game title and a panel heading;
## - `SeasonBadge`: the small "Spring · Cats" tag.
static func make_theme(season: String) -> Theme:
	var main: Color = MAIN[season]
	var dark: Color = DARK[season]
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE

	# Buttons: a pale season fill with a dark season border and a thick bottom edge,
	# tinted on hover, season colour when held down.
	theme.set_stylebox("normal", "Button", _button_box(BUTTON[season], dark))
	theme.set_stylebox("hover", "Button", _button_box(HOVER[season], dark))
	theme.set_stylebox("pressed", "Button", _button_box(main, dark, true))
	theme.set_stylebox("disabled", "Button", _button_box(Color(0.92, 0.92, 0.92), Color(0.6, 0.6, 0.6)))
	theme.set_stylebox("focus", "Button", _focus_ring(season))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", dark)

	# The primary button is filled with the season colour from the start.
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _button_box(main, dark))
	theme.set_stylebox("hover", "PrimaryButton", _button_box(main.lightened(0.15), dark))
	theme.set_stylebox("pressed", "PrimaryButton", _button_box(main.darkened(0.15), dark, true))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "PrimaryButton", dark)

	# Panels: the season's pixel-art frame.
	theme.set_stylebox("panel", "PanelContainer", panel_box(season))

	# Text.
	theme.set_color("font_color", "Label", dark)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", TITLE_FONT_SIZE)
	theme.set_color("font_outline_color", "TitleLabel", WHITE)
	theme.set_constant("outline_size", "TitleLabel", 14)
	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font_size("font_size", "HeadingLabel", HEADING_FONT_SIZE)
	theme.set_type_variation("SeasonBadge", "Label")
	var badge := _box(main, dark)
	badge.content_margin_left = 18
	badge.content_margin_right = 18
	theme.set_stylebox("normal", "SeasonBadge", badge)

	# Sliders: a grey track, the part to the left of the knob in season colour,
	# and a round knob like the wireframe's.
	var track := _box(Color(0.42, 0.45, 0.5), Color(0.42, 0.45, 0.5), 2)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)
	var filled := _box(main, dark, 2)
	filled.content_margin_top = 4
	filled.content_margin_bottom = 4
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", _circle(main, dark, 28))
	theme.set_icon("grabber_highlight", "HSlider", _circle(main.lightened(0.2), dark, 28))
	theme.set_stylebox("focus", "HSlider", _focus_ring(season))

	# Check box: a pale square with a dark season border that fills with the
	# season colour and a tick.
	theme.set_icon("unchecked", "CheckBox", _check_box(season, false))
	theme.set_icon("checked", "CheckBox", _check_box(season, true))
	theme.set_stylebox("focus", "CheckBox", _focus_ring(season))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "CheckBox", dark)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())

	return theme


## The season's panel: its pixel-art frame, stretched to fit. The middle of each
## edge repeats rather than stretches, so the snow, the waves and the pixels stay
## the same size on a panel of any size.
static func panel_box(season: String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = frame_texture(season)
	var margin := float(FRAME_MARGIN * PIXEL_SCALE)
	box.texture_margin_left = margin
	box.texture_margin_top = margin
	box.texture_margin_right = margin
	box.texture_margin_bottom = margin
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	# The see-through ring is drawn outside the panel, so the frame's border lines
	# up with the panel's own edge and the decorations stick out past it.
	box.set_expand_margin_all(float(FRAME_OUTSIDE * PIXEL_SCALE))
	# Keep the words clear of the frame and its decorations.
	var inside := float((FRAME_MARGIN - FRAME_OUTSIDE) * PIXEL_SCALE)
	box.content_margin_left = inside + 6.0
	box.content_margin_right = inside + 6.0
	box.content_margin_top = inside + 4.0
	box.content_margin_bottom = inside + 4.0
	return box


## Draws the season's frame picture: FRAME, then the season's decorations on top,
## each art pixel PIXEL_SCALE screen pixels across.
static func frame_texture(season: String) -> ImageTexture:
	var colours := {
		"B": DARK[season],
		"L": (PANEL[season] as Color).lightened(0.6),
		"F": PANEL[season],
		"D": (PANEL[season] as Color).darkened(0.08),
	}
	colours.merge(DECORATION_COLOURS[season])

	var art: Array[String] = []
	for row: String in FRAME:
		art.append(row)
	for decoration in DECORATIONS[season]:
		var picture: Array = decoration[0]
		var left: int = decoration[1]
		var top: int = decoration[2]
		for y in picture.size():
			var line: String = picture[y]
			for x in line.length():
				if line[x] != ".":
					var row: String = art[top + y]
					art[top + y] = row.substr(0, left + x) + line[x] + row.substr(left + x + 1)

	return picture_texture(art, colours, PIXEL_SCALE)


## The two little pictures for the title buttons in this season, ready to draw:
## [top-left, top-right].
static func button_decorations(season: String) -> Array[ImageTexture]:
	var textures: Array[ImageTexture] = []
	for picture in BUTTON_DECORATIONS[season]:
		textures.append(picture_texture(picture, DECORATION_COLOURS[season], BUTTON_DECORATION_SCALE))
	return textures


## Turns one of the text pictures into a texture: every character that has a colour
## becomes a `scale` x `scale` square of it, and everything else is see-through.
static func picture_texture(picture: Array, colours: Dictionary, scale: int) -> ImageTexture:
	var height := picture.size()
	var width := String(picture[0]).length()
	var image := Image.create_empty(width * scale, height * scale, false, Image.FORMAT_RGBA8)
	for y in height:
		var line: String = picture[y]
		for x in width:
			if colours.has(line[x]):
				image.fill_rect(Rect2i(x * scale, y * scale, scale, scale), colours[line[x]])
	return ImageTexture.create_from_image(image)


## A button: the given fill and border, square-ish pixel corners, and a thicker
## bottom edge. A pressed button has a thin bottom edge and its words moved down,
## so it looks pushed in.
static func _button_box(fill: Color, border: Color, pressed := false) -> StyleBoxFlat:
	var box := _box(fill, border)
	var depth := BORDER if pressed else BORDER + BUTTON_DEPTH
	box.border_width_bottom = depth
	if pressed:
		box.content_margin_top += BUTTON_DEPTH
		box.content_margin_bottom -= BUTTON_DEPTH
	return box


## A box with a border and small, crisp (not smoothed) corners, used for buttons,
## the badge and the slider.
static func _box(fill: Color, border: Color, radius: int = CORNER_RADIUS) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(BORDER)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = false
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


## The ring drawn round whichever control the keyboard is on, so a player using
## only the keys can always see where they are.
static func _focus_ring(season: String) -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = FOCUS[season]
	ring.set_border_width_all(4)
	ring.set_corner_radius_all(CORNER_RADIUS + 4)
	ring.anti_aliasing = false
	ring.set_expand_margin_all(5)
	return ring


## A filled circle with an outline, drawn into a texture at run time so the
## project does not need a picture file for a slider knob.
static func _circle(fill: Color, outline: Color, size: int) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var centre := (size - 1) * 0.5
	var radius := size * 0.5 - 0.5
	for y in size:
		for x in size:
			var distance := Vector2(x - centre, y - centre).length()
			if distance <= radius - BORDER:
				image.set_pixel(x, y, fill)
			elif distance <= radius:
				image.set_pixel(x, y, outline)
	return ImageTexture.create_from_image(image)


## The check box picture, empty or ticked, drawn at run time like the knob.
static func _check_box(season: String, ticked: bool) -> ImageTexture:
	var size := 30
	var dark: Color = DARK[season]
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(dark)
	image.fill_rect(Rect2i(BORDER, BORDER, size - BORDER * 2, size - BORDER * 2),
		MAIN[season] if ticked else BUTTON[season])
	if ticked:
		# Two thick strokes make the tick: down to the bottom, then up to the right.
		_thick_line(image, Vector2(7, 15), Vector2(12, 21), dark)
		_thick_line(image, Vector2(12, 21), Vector2(23, 8), dark)
	return ImageTexture.create_from_image(image)


static func _thick_line(image: Image, from: Vector2, to: Vector2, colour: Color) -> void:
	var steps := int(from.distance_to(to) * 2.0)
	for step in steps + 1:
		var point := from.lerp(to, float(step) / steps)
		image.fill_rect(Rect2i(int(point.x) - 1, int(point.y) - 1, 3, 3), colour)
