class_name ZwembadBeurt
extends RefCounted
## Everything about one turn of the pool that is pure arithmetic or a literal
## child-facing sentence (games-b.md §1.3–§1.12).  Nothing here touches the
## world, so `test_zwembad.gd` can walk every band without a viewport.
##
## The generators themselves are NOT here: `Sommen.Zwembad.baan / juist_van /
## keuze_getallen / slag` are frozen (architecture.md §1.1 F1) and are called,
## never re-implemented.

## The lane is the number line: the pool of the room maps `0 … L` linearly onto
## `bad.x0 … bad.x1`, and the swimming lane is the middle of the water.
static func baan_x(bad: Dictionary, l: int, p: float) -> float:
	if bad.is_empty() or l <= 0:
		return 0.0
	var x0 := float(bad["x0"])
	var x1 := float(bad["x1"])
	return x0 + (x1 - x0) * clampf(p, 0.0, float(l)) / float(l)

static func baan_z(bad: Dictionary) -> float:
	return 28.0 if bad.is_empty() else (float(bad["z0"]) + float(bad["z1"])) / 2.0

## games-b.md §1.6: the number on the swimmer stays readable (~5 m/s) and a
## whole lane never takes longer than ~15 s.
static func tempo_van(l: int) -> float:
	return clampf(4.3 * 5.0 / float(maxi(1, l)), 4.3 / 15.0, 1.0)

## At most four splashes over a long stretch.
static func plons_elke(n: int) -> int:
	return maxi(1, ceili(n / 4.0)) if n > 10 else 5

## games-b.md §1.9: label the big markers wider as soon as two labels would
## stand closer than 34 css px together.
static func label_stap(l: int, stap: int, bad: Dictionary, k: float) -> int:
	var stap2 := 2 * stap
	if bad.is_empty() or l <= 0:
		return stap2
	var per_meter := (float(bad["x1"]) - float(bad["x0"])) / float(l) * 2.0 * k
	while stap2 < l and per_meter * stap2 < 34.0:
		stap2 += 2 * stap
	return stap2

# ------------------------------------------------------------- de bewaarde beurt

## `normaliseer(b)` — fill an old saved turn in (games-b.md §1.12).
static func normaliseer(b: Dictionary, band_nu: int) -> Dictionary:
	var uit := b.duplicate(true)
	var band := Sommen.Zwembad.band_van(int(uit.get("band", band_nu)))
	uit["band"] = band
	var l := int(uit.get("L", 0))
	uit["L"] = l
	uit["M"] = Sommen.Zwembad.max_van(l, band)
	uit["stap"] = 5 if l <= 20 else 10
	uit["p"] = clampi(int(uit.get("p", 0)), 0, maxi(0, l))
	uit["leg"] = maxi(0, int(uit.get("leg", 0)))
	uit["misser"] = maxi(0, int(uit.get("misser", 0)))
	uit["laatste_p"] = JsGetal.rond(float(uit.get("laatste_p", 0)))
	uit["laatste_rest"] = int(uit.get("laatste_rest", l))
	uit["klaar"] = str(uit.get("klaar", ""))
	uit["gast"] = str(uit.get("gast", ""))
	uit["wens"] = bool(uit.get("wens", false))
	uit["plafond"] = Sommen.Zwembad.plafond_van(band)
	return uit

## A turn may be resumed when the numbers are numbers, the lane is real, the
## swimmer is somewhere on it, the turn is not finished and the guest is still
## in the hotel.
static func geldig(b: Dictionary, gast_bestaat: bool) -> bool:
	if b.is_empty():
		return false
	for sleutel in ["L", "p", "M"]:
		var v = b.get(sleutel, null)
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
			return false
	var l := int(b["L"])
	var p := int(b["p"])
	if l <= 0 or p < 0 or p > l:
		return false
	if not str(b.get("klaar", "")).is_empty():
		return false
	return gast_bestaat

# ------------------------------------------------------- kindtekst (§1.11)

const HULP_TITEL := "hoeveel meter zwemt hij?"
const GEEN_GAST := "🏊 Er is nog geen gast"
const TOAST_PRECIES := "🏊 Precies aan de overkant! ⭐"
const TOAST_BOTS := "🏊 Aan de overkant! ⭐"
const EIND_PRECIES := "Precies aan de overkant!"
const KAART_ICOON := "🏊"
const PRECIES_ICOON := "✅"
const BOTS_ICOON := "💛"
const LABEL := "Zwemles"
const ICOON := "🏊"
const TAAK := "Zwemles"

static func taak_tekst(naam: String) -> String:
	return "Zwemles voor %s" % naam if not naam.is_empty() else TAAK

## The guest whose 🏊 wish this game fulfils (games-b.md §1.2).  `wanneer` asks
## for one that is not happy yet; the TEXT asks with `ook_blij`, so a card that
## was just ticked keeps its name for the rest of the day.
static func wens_gast(gasten: Array, ook_blij: bool) -> Dictionary:
	for g in gasten:
		if typeof(g) != TYPE_DICTIONARY:
			continue
		if str(g.get("bed", "")).is_empty():
			continue
		if str(g.get("behoefte", "")) != "zwemmen":
			continue
		if not ook_blij and bool(g.get("blij", false)):
			continue
		return g
	return {}

## Card 1 (p = 0): the lane and the maximum per stroke.
static func regel_start(l: int) -> String:
	return "Het bad is %d meter lang" % l

static func regel2_start(m: int) -> String:
	return "Max %d meter per keer" % m

static func som_start(l: int) -> String:
	return "nog %d m" % l

## Card n (p > 0): where he is, and the school sum under it.
static func regel_verder(naam: String, p: int) -> String:
	return "%s is bij %d meter" % [naam, p]

static func regel2_verder() -> String:
	return "Nog hoeveel meter?"

## The real minus sign U+2212, never a hyphen (architecture.md §1.1 F3).
static func som_verder(l: int, p: int) -> String:
	return "%d − %d =" % [l, p]

static func keuze_woord(v: int) -> String:
	return "%d m" % v

## The sum bar of the end card.
static func som_af(l: int, laatste_p: int, laatste_rest: int, had_etappe: bool) -> String:
	if not had_etappe:
		return "%d m ✓" % l
	return "%d − %d = %d" % [l, laatste_p, laatste_rest]

static func eind_regel2_precies(naam: String, l: int) -> String:
	return "%s zwom %d meter" % [naam, l]

static func eind_regel_bots(naam: String) -> String:
	return "%s is aan de overkant" % naam

static func eind_regel2_bots(rest: int) -> String:
	return "Het was nog %d meter" % rest

## The three steps of the help ladder (games-b.md §0.5).  The pool has no
## literals of its own for them, so these are gentle and wordless-ish: count
## the markers, then the rule of the game, then the ghost marker in the water.
static func hulp_regel(misser: int, m: int) -> String:
	if misser <= 0:
		return ""
	if misser == 1:
		return "💛 tel de strepen tot de vlag"
	if misser == 2:
		return "💛 hooguit %d m per keer" % m
	return "💛 zwem tot het bleke streepje"
