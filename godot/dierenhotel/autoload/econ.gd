extends Node
## Econ — coins, stars and the bill.  Autoload #8.
## Port of `demos/dierenhotel/econ.js` (world.md §3.5, §3.6).
##
## The coin maths itself is frozen and lives in `Sommen` (`buidel`, `splits`);
## this file owns the three-step checkout moment, which is delegated to
## `res://hotel/rekening.gd` so that both stay readable.
##
## Two rules from HOTEL.md §9 that the code has to make impossible to break:
## a star is for taking part and has no "correct" parameter (F5), and the star
## counter goes up DURING a game — `sterren()` refreshes the five HUD texts
## itself instead of waiting for the next `Hotel.render()`.

signal sterren_veranderd(aantal: int)
signal munten_veranderd(aantal: int)
signal rekening_veranderd()
signal rekening_klaar(uit: Dictionary)

var _rek: HotelRekening = null

func _ready() -> void:
	_rek = HotelRekening.new()
	_rek.veranderd.connect(func(): rekening_veranderd.emit())
	_rek.klaar.connect(func(uit: Dictionary): rekening_klaar.emit(uit))

## A star is for taking part, never for being right (HOTEL.md §9).
func sterren(n: int = 1, _bron: String = "") -> void:
	State.s["sterren"] = int(State.s["sterren"]) + n
	Snd.ster()
	sterren_veranderd.emit(int(State.s["sterren"]))
	Hotel.hud()

func geef_munt(n: int) -> void:
	State.s["munten"] = int(State.s["munten"]) + n
	munten_veranderd.emit(int(State.s["munten"]))
	Hotel.hud()

func buidel(totaal: int) -> Array[int]:
	return Sommen.buidel(totaal)

func splits(n: int) -> Array[int]:
	return Sommen.splits(n)

## `€10` and `€20` are notes, everything else is a coin (world.md §3.5).
func munt_soort(waarde: int) -> String:
	return "biljet" if waarde == 10 or waarde == 20 else "munt"

## `Ui.telMee(stap, aantal)` of the HTML: `5 … 10 … 15.`  It lives here because
## `Ui` is W3's file and the help ladder of the bill is W2's.
func tel_mee(stap: int, aantal: int, staart: String = ".") -> String:
	var l := PackedStringArray()
	var som := 0
	for i in maxi(0, aantal):
		som += stap
		l.append(str(som))
	return " … ".join(l) + staart

## A cancel-free delay for the presentation beats of the bill.  Never used for
## anything a child could lose by reloading — that all lives in the save, which
## is written BEFORE the wait starts.  `Econ` is the Node that owns the timer,
## because `HotelRekening` is a RefCounted and has no tree.
func wacht(seconden: float) -> void:
	var boom := get_tree()
	if boom == null or seconden <= 0.0:
		return
	await boom.create_timer(seconden).timeout

func na(seconden: float, fn: Callable) -> void:
	await wacht(seconden)
	if fn.is_valid():
		fn.call()

# ------------------------------------------------------------- de rekening

## `Econ.rekening({gast, fam, nachten, prijs, totaal, betaald, on_klaar})`.
## The result is also announced with `rekening_klaar`, which is what `Hotel`
## listens to — a Callable cannot be saved, a signal survives a reload.
func rekening(o: Dictionary) -> Dictionary:
	var af: Callable = o.get("on_klaar", Callable())
	if af.is_valid():
		rekening_klaar.connect(af, CONNECT_ONE_SHOT)
	return _rek.begin(o)

## After loading a save: put a half-finished bill back on the desk.
func herstel_rekening() -> void:
	_rek.herstel()

func rekening_bezig() -> bool:
	return _rek != null and _rek.bezig()

func rekening_stand() -> Dictionary:
	return {} if _rek == null else _rek.stand()

func rekening_stop() -> void:
	if _rek != null:
		_rek.stop()

## The three answers the child can give, exposed so the shell and the tests
## reach them without knowing about `hotel/rekening.gd`.
##
## Three of them carry a presentation wait (world.md §3.5: 500 ms after the sum,
## 1100 ms under the goodbye bubble), so they are coroutines: `await` them when
## you need the next step, call them plainly when you do not.
func som_ok(n: Variant) -> void:
	await _rek.som_ok(n)

func leg_neer() -> void:
	_rek.leg_neer()

func klaar_met_tellen() -> void:
	await _rek.klaar_met_tellen()

func wissel_ok(n: Variant) -> void:
	await _rek.wissel_ok(n)

func geteld() -> int:
	return 0 if _rek == null else _rek.geteld()
