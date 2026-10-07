class_name SeasonTheme
extends RefCounted

## The look of every menu, one per season.
##
## Nothing here is a node and nothing here is saved: a menu calls
## `SeasonTheme.make_theme("autumn")` and puts the result on its root Control,
## and every Button, Label, slider and check box under it is styled from that.
## Changing season is just making a new theme and swapping it in.
##
## The four colours are the ones the proposal's screen-flow figure uses for the
## four seasons, and the dark navy is the wireframes' outline colour, so the
## menus look like the mockups but each one wears its season.

const ORDER: Array[String] = ["spring", "summer", "autumn", "winter"]

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

## The colour a button turns when the mouse is over it.
const HOVER := {
	"spring": Color("d9f0d3"),
	"summer": Color("ffe9ad"),
	"autumn": Color("f8d2b0"),
	"winter": Color("d3e6f7"),
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
const CORNER_RADIUS := 10
const BORDER := 3


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
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE

	# Buttons: white with a navy border, tinted on hover, season colour when held.
	theme.set_stylebox("normal", "Button", _box(WHITE, NAVY))
	theme.set_stylebox("hover", "Button", _box(HOVER[season], NAVY))
	theme.set_stylebox("pressed", "Button", _box(main, NAVY))
	theme.set_stylebox("disabled", "Button", _box(Color(0.92, 0.92, 0.92), Color(0.6, 0.6, 0.6)))
	theme.set_stylebox("focus", "Button", _focus_ring())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", NAVY)

	# The primary button is filled with the season colour from the start.
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _box(main, NAVY))
	theme.set_stylebox("hover", "PrimaryButton", _box(main.lightened(0.15), NAVY))
	theme.set_stylebox("pressed", "PrimaryButton", _box(main.darkened(0.15), NAVY))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "PrimaryButton", NAVY)

	# Panels: the pale season tint with the same navy border.
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL[season], NAVY, 18))

	# Text.
	theme.set_color("font_color", "Label", NAVY)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", TITLE_FONT_SIZE)
	theme.set_color("font_outline_color", "TitleLabel", WHITE)
	theme.set_constant("outline_size", "TitleLabel", 14)
	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font_size("font_size", "HeadingLabel", HEADING_FONT_SIZE)
	theme.set_type_variation("SeasonBadge", "Label")
	var badge := _box(main, NAVY, 14)
	badge.content_margin_left = 18
	badge.content_margin_right = 18
	theme.set_stylebox("normal", "SeasonBadge", badge)

	# Sliders: a grey track, the part to the left of the knob in season colour,
	# and a round knob like the wireframe's.
	var track := _box(Color(0.42, 0.45, 0.5), Color(0.42, 0.45, 0.5), 4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)
	var filled := _box(main, main, 4)
	filled.content_margin_top = 4
	filled.content_margin_bottom = 4
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", _circle(main, NAVY, 28))
	theme.set_icon("grabber_highlight", "HSlider", _circle(main.lightened(0.2), NAVY, 28))
	theme.set_stylebox("focus", "HSlider", _focus_ring())

	# Check box: a white square that fills with the season colour and a tick.
	theme.set_icon("unchecked", "CheckBox", _check_box(main, false))
	theme.set_icon("checked", "CheckBox", _check_box(main, true))
	theme.set_stylebox("focus", "CheckBox", _focus_ring())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "CheckBox", NAVY)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())

	return theme


## A rounded box with a border, used for buttons, panels and the badge.
static func _box(fill: Color, border: Color, radius: int = CORNER_RADIUS) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(BORDER)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


## The ring drawn round whichever control the keyboard is on, so a player using
## only the keys can always see where they are.
static func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color("e07a30")
	ring.set_border_width_all(4)
	ring.set_corner_radius_all(CORNER_RADIUS + 4)
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
static func _check_box(fill: Color, ticked: bool) -> ImageTexture:
	var size := 30
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(NAVY)
	image.fill_rect(Rect2i(BORDER, BORDER, size - BORDER * 2, size - BORDER * 2),
		fill if ticked else WHITE)
	if ticked:
		# Two thick strokes make the tick: down to the bottom, then up to the right.
		_thick_line(image, Vector2(7, 15), Vector2(12, 21), NAVY)
		_thick_line(image, Vector2(12, 21), Vector2(23, 8), NAVY)
	return ImageTexture.create_from_image(image)


static func _thick_line(image: Image, from: Vector2, to: Vector2, colour: Color) -> void:
	var steps := int(from.distance_to(to) * 2.0)
	for step in steps + 1:
		var point := from.lerp(to, float(step) / steps)
		image.fill_rect(Rect2i(int(point.x) - 1, int(point.y) - 1, 3, 3), colour)
