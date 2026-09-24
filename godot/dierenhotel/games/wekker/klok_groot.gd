class_name WekkerKlok
extends Control
## De wekker van VOREN en groot, zolang de wekkerdienst loopt (eigenaar
## 2026-09-24: "Kun je de klok groter maken wanneer erop wordt geklikt ... ook
## de klok naar voren laten komen zodat de speler de klok duidelijk van voren
## kan zien tot ze wegklikken van het wekker zetten").
##
## De klok aan de wand is een voxelmodel onder de hoek van de kamer: klein, en
## de wijzers zijn een paar blokjes.  Deze tekent dezelfde wekker plat en recht
## van voren, in dezelfde kleuren (kast, gouden rand, room wijzerplaat, twee
## belletjes), met twaalf cijfers en zestig minuutstreepjes zoals op een klok
## in de klas.  Er staat GEEN tijd in woorden bij: het kind leest de wijzers
## (eigenaar 2026-09-24: "geen hint geven hoe laat het is").
##
## Het is geen knop: een tik gaat erdoorheen.  `Hits` legt hem neer en ruimt
## hem op zoals elk ander element van het spel (`kind: "eigen"`); de grootte
## vraagt hij het spel elke plaatsing (`meet`), zodat hij meegroeit met het
## kader en nooit onder de rekenbalk komt.  Bij het verschijnen komt hij van de
## wand naar voren (`groei`), en een draai laat de wijzers echt draaien: een
## uur erbij is één rondje van de grote wijzer, een uur eraf één rondje terug.

const KL_KAST := Color("#7E6255")
const KL_RAND := Color("#E8C58E")
const KL_PLAAT := Color("#FFF7E4")
const KL_STREEP := Color("#7E6255")
const KL_UUR := Color("#4A3B33")
const KL_MIN := Color("#C9788F")
const KL_HART := Color("#E0A86B")
const KL_BEL := Color("#E8C58E")
const KL_SCHADUW := Color(0.29, 0.231, 0.2, 0.16)

## Hoogte / breedte van het geheel: de belletjes steken boven de kast uit en
## de pootjes eronder.
const VORM := 1.06
const KOM_S := 0.42        ## seconden: van de wand naar voren
const DRAAI_S := 0.45      ## seconden: de wijzers naar hun nieuwe stand

## Minuten sinds 12 uur die de wijzers NU tonen.  Doorlopend (niet modulo), zodat
## een uur erbij de grote wijzer een heel rondje vooruit draait en een uur eraf
## een heel rondje terug.
var getoond := 0.0
var uur := 12
var minuut := 0
## 0 → 1: van de klok aan de wand naar deze plek.
var groei := 1.0
## Wat de grootte bepaalt: `func() -> Vector2`, van het spel.
var meet: Callable = Callable()
## Het hart van de wandklok in de coördinaten van mijn ouder (de knoppenlaag).
var van_hart := Vector2.INF
var van_straal := 0.0

var _draai_tw: Tween = null
var _draai_eind := 0.0     ## waar een draai die nog onderweg is uitkomt
var _groei_tw: Tween = null
static var _cijferfont: Font = null

func _init() -> void:
	name = "WekkerKlok"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	visibility_changed.connect(_op_zicht)
	_kom_naar_voren()

## Hoe groot `Hits` hem moet neerleggen (`hits.gd:_maat_van`).
func inhoud_maat() -> Vector2:
	var m: Vector2 = meet.call() if meet.is_valid() else custom_minimum_size
	return Vector2(maxf(48.0, m.x), maxf(48.0, m.y))

## De maat die bij een wijzerplaat van `breed` hoort.
static func maat_bij(breed: float) -> Vector2:
	return Vector2(breed, breed * VORM)

## Zet de wijzers.  `stap` is wat er net gedraaid is, in minuten: dan draaien ze
## die kant op naar de nieuwe stand; 0 is een nieuwe beurt, de wijzers staan er
## meteen.
func zet(u: int, m: int, stap: int = 0) -> void:
	uur = u
	minuut = m
	var doel := float((u % 12) * 60 + posmod(m, 60))
	if stap == 0 or not _beweegt():
		if _draai_tw != null:
			_draai_tw.kill()
			_draai_tw = null
		getoond = doel
		queue_redraw()
		return
	# vanaf waar de wijzers nu staan precies `stap` verder: zo draait een uur
	# eraf echt terug, ook als een vorige draai nog onderweg was
	var eind := getoond + float(stap)
	if _draai_tw != null and _draai_tw.is_running():
		eind = _draai_eind + float(stap)
	_draai_eind = eind
	if _draai_tw != null:
		_draai_tw.kill()
	_draai_tw = create_tween()
	_draai_tw.tween_method(_zet_getoond, getoond, eind, DRAAI_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _zet_getoond(v: float) -> void:
	getoond = v
	queue_redraw()

## De hoek van de uurwijzer en van de minuutwijzer (0 = 12 uur, met de klok mee).
func hoek_uur() -> float:
	return fposmod(getoond, 720.0) / 720.0 * TAU

func hoek_min() -> float:
	return fposmod(getoond, 60.0) / 60.0 * TAU

func _beweegt() -> bool:
	return not Ui.rust_modus() and DisplayServer.get_name() != "headless" \
		and is_inside_tree()

func _op_zicht() -> void:
	if is_visible_in_tree():
		_kom_naar_voren()

## Van de wand naar voren: klein op de plek van de wandklok, dan groot hier.
func _kom_naar_voren() -> void:
	if _groei_tw != null:
		_groei_tw.kill()
		_groei_tw = null
	if not _beweegt() or van_hart == Vector2.INF:
		groei = 1.0
		queue_redraw()
		return
	groei = 0.0
	_groei_tw = create_tween()
	_groei_tw.tween_method(_zet_groei, 0.0, 1.0, KOM_S) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _zet_groei(v: float) -> void:
	groei = v
	queue_redraw()

# ------------------------------------------------------------------ tekenen

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	# de belletjes raken de bovenrand: zo staat hij zo hoog mogelijk en dekt
	# hij de wandklok erachter helemaal af
	var r_vol := minf(size.x * 0.48, size.y / 2.12)
	var hart_vol := Vector2(size.x * 0.5, r_vol * 1.1 + 1.0)
	# van de wand naar voren: het hart schuift van de wandklok naar hier en de
	# straal groeit mee
	var r := r_vol
	var hart := hart_vol
	if not is_equal_approx(groei, 1.0) and van_hart != Vector2.INF:
		var van := van_hart - position
		var r0 := maxf(4.0, van_straal)
		r = lerpf(r0, r_vol, groei)
		hart = van.lerp(hart_vol, groei)
	_teken_klok(hart, r)

func _teken_klok(c: Vector2, r: float) -> void:
	# schaduw: hij staat vóór de muur
	draw_circle(c + Vector2(r * 0.04, r * 0.07), r * 1.03, KL_SCHADUW)
	# pootjes
	for kant: float in [-1.0, 1.0]:
		var voet := c + Vector2(kant * r * 0.62, r * 0.84)
		_blok(voet, Vector2(r * 0.2, r * 0.22), -kant * 0.5, KL_KAST)
	# belletjes, schuin boven de kast, met een knopje erop
	for kant: float in [-1.0, 1.0]:
		var a := kant * deg_to_rad(40.0)
		var b := c + Vector2(sin(a), -cos(a)) * r * 1.0
		draw_circle(b, r * 0.25, KL_KAST)
		draw_circle(b, r * 0.21, KL_BEL)
		draw_circle(b + Vector2(sin(a), -cos(a)) * r * 0.25, r * 0.06, KL_KAST)
	# kast, gouden rand, wijzerplaat
	draw_circle(c, r, KL_KAST)
	draw_circle(c, r * 0.9, KL_RAND)
	draw_circle(c, r * 0.8, KL_PLAAT)
	# zestig minuutstreepjes, twaalf dikke uurstreepjes
	for i in 60:
		var a := float(i) / 60.0 * TAU
		var dir := Vector2(sin(a), -cos(a))
		if i % 5 == 0:
			draw_line(c + dir * r * 0.66, c + dir * r * 0.76, KL_STREEP,
				maxf(2.0, r * 0.035), true)
		else:
			draw_line(c + dir * r * 0.72, c + dir * r * 0.76, Color(KL_STREEP, 0.55),
				maxf(1.0, r * 0.012), true)
	# de cijfers 1 tot 12
	var f := _font()
	if f != null:
		var fs := maxi(10, int(round(r * 0.17)))
		var hoog := f.get_ascent(fs) - f.get_descent(fs)
		for i in range(1, 13):
			var a := float(i) / 12.0 * TAU
			var p := c + Vector2(sin(a), -cos(a)) * r * 0.53
			var t := str(i)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(p.x - w * 0.5, p.y + hoog * 0.5 - f.get_descent(fs) * 0.2),
				t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, KL_UUR)
	# de wijzers: kort en dik is het uur, lang en roze de minuten
	_wijzer(c, hoek_uur(), r * 0.4, r * 0.1, maxf(3.0, r * 0.085), KL_UUR)
	_wijzer(c, hoek_min(), r * 0.66, r * 0.12, maxf(2.0, r * 0.05), KL_MIN)
	draw_circle(c, r * 0.075, KL_HART)
	draw_circle(c, r * 0.03, KL_UUR)

func _wijzer(c: Vector2, a: float, lang: float, staart: float, dik: float, kl: Color) -> void:
	var dir := Vector2(sin(a), -cos(a))
	var van := c - dir * staart
	var tot := c + dir * lang
	draw_line(van, tot, kl, dik, true)
	draw_circle(tot, dik * 0.5, kl)
	draw_circle(van, dik * 0.5, kl)

## Een schuin blokje (een pootje) rond `m`.
func _blok(m: Vector2, maat: Vector2, kanteling: float, kl: Color) -> void:
	var h := maat * 0.5
	var punten := PackedVector2Array()
	for p: Vector2 in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		punten.append(m + p.rotated(kanteling))
	draw_colored_polygon(punten, kl)

static func _font() -> Font:
	if _cijferfont == null:
		_cijferfont = UiThema.laad_font(true)
	return _cijferfont
