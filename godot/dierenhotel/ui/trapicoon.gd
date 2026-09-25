class_name UiTrapIcoon
extends RefCounted
## The pictogram of the stairs (owner, 2026-09-25: "Ik wil graag de lift
## vervangen voor een trap").  There is no stairs emoji — 🪜 is a ladder, and
## a child calls it one — so it is drawn here, once: four wooden steps climbing
## to the right, light treads on darker risers, a handrail over them, in the
## wood of the drawn stairwell (`scenes/vloer.gd` `TRAP_*`).  Drawn at `FIJN`
## times the size and scaled down, so its edges are as soft as an emoji's.
##
## A button carries it as its `beeld` (`UiHotKnop`), a sheet as its title's
## picture (`UiBlad`); both size it to the text beside it.

const MAAT := 64                          ## pixels, square
const FIJN := 4                           ## drawn this many times bigger
const TREE := Color("#F2C995")            ## the top of a step
const STOOTBORD := Color("#C98B5B")       ## the front of a step
const NEUS := Color("#A36B40")            ## the shadow under a step's nose
const LEUNING := Color("#7A4B2A")         ## the handrail and its posts

## [left, top] of each step's nose on the 64 grid, bottom step first; every
## step runs on to the right edge and down to the floor.
const NEUZEN := [[6.0, 49.0], [19.0, 39.0], [32.0, 29.0], [45.0, 19.0]]
const RECHTS := 58.0
const VLOER := 59.0
const TREE_DIK := 3.5                     ## how much of a step's top shows
const LEUNING_OP := 13.0                  ## the rail runs this far over the noses
const LEUNING_DIK := 3.0

static var _beeld: ImageTexture = null

static func beeld() -> Texture2D:
	if _beeld == null:
		_beeld = ImageTexture.create_from_image(teken())
	return _beeld

## The picture itself, `MAAT` square, transparent round the stairs.
static func teken() -> Image:
	var f := float(FIJN)
	var groot := Image.create_empty(MAAT * FIJN, MAAT * FIJN, false, Image.FORMAT_RGBA8)
	groot.fill(Color(0, 0, 0, 0))
	for neus in NEUZEN:
		var x: float = neus[0]
		var y: float = neus[1]
		_blok(groot, x, y, RECHTS, VLOER, STOOTBORD, f)
		_blok(groot, x, y, RECHTS, y + TREE_DIK, TREE, f)
		_blok(groot, x, y + TREE_DIK, RECHTS, y + TREE_DIK + 1.2, NEUS, f)
	# the rail, over the noses, and a post down onto every step
	var a := Vector2(NEUZEN[0][0] + 3.0, NEUZEN[0][1] - LEUNING_OP)
	var b := Vector2(NEUZEN[3][0] + 9.0, NEUZEN[3][1] - LEUNING_OP)
	for neus in NEUZEN:
		var px: float = neus[0] + 4.0
		var t := (px - a.x) / (b.x - a.x)
		_blok(groot, px - 1.0, lerpf(a.y, b.y, t), px + 1.0, neus[1], LEUNING, f)
	_lijn(groot, a, b, LEUNING_DIK, LEUNING, f)
	groot.resize(MAAT, MAAT, Image.INTERPOLATE_LANCZOS)
	return groot

static func _blok(img: Image, x0: float, y0: float, x1: float, y1: float, kl: Color,
		f: float) -> void:
	var r := Rect2i(int(round(x0 * f)), int(round(y0 * f)),
		int(round((x1 - x0) * f)), int(round((y1 - y0) * f)))
	img.fill_rect(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())), kl)

## A thick straight line, as a row of small squares along it.
static func _lijn(img: Image, a: Vector2, b: Vector2, dik: float, kl: Color, f: float) -> void:
	var stappen := int(ceil(a.distance_to(b) * f))
	var half := dik * 0.5
	for i in stappen + 1:
		var p := a.lerp(b, float(i) / float(maxi(1, stappen)))
		_blok(img, p.x - half, p.y - half, p.x + half, p.y + half, kl, f)
