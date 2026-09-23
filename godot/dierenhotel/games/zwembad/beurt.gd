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

## Owner (2026-09-16): "de duikplek zit door een hek heen".  The outdoor room
## fences off its BACK side, so the number line lies on the near edge: the
## markers stand on the stone rim in front of the water, the flag on the deck
## just behind them.  Both z's always sit inside the fence (z > HEK_Z).
static func rand_z(bad: Dictionary) -> float:
	return 46.0 if bad.is_empty() else float(bad["z1"]) + 2.0

static func vlag_z(bad: Dictionary) -> float:
	return 50.0 if bad.is_empty() else float(bad["z1"]) + 6.0

## Owner (2026-09-17): "startblokken ... met een trappetje zodat het dier
## langzaam omhoog kan springen" and "Maak het startblok groter en doe 1 ipv
## 3".  The one big startblok stands at the WEST end of the lane, on the deck
## between the moved fence and the water.  `blok_x` is the block's centre,
## `trap_voet` the foot of its stair, `duik_x` where the dive enters the
## water at the 0 m mark.
static func blok_x(bad: Dictionary) -> float:
	return 14.0 if bad.is_empty() else float(bad["x0"]) - 4.0

static func trap_voet(bad: Dictionary) -> float:
	return blok_x(bad) - 8.0

static func duik_x(bad: Dictionary) -> float:
	return 20.5 if bad.is_empty() else float(bad["x0"]) + 2.5

## The hops up the trappetje, as [x, hoogte] pairs: three steps of the big
## `startblok` model (3, 6, 8) and the last hop onto the cushion at its front
## edge (hoogte 9), so the dive starts at the edge and clears the block.
static func trap_hoppen(bad: Dictionary) -> Array:
	var voet := trap_voet(bad)
	return [[voet + 1.0, 3.0], [voet + 3.0, 6.0], [voet + 5.0, 8.0],
		[voet + 10.5, 9.0]]

## games-b.md §1.6: the number on the swimmer stays readable (~5 m/s) and a
## whole lane never takes longer than ~15 s.
static func tempo_van(l: int) -> float:
	return clampf(4.3 * 5.0 / float(maxi(1, l)), 4.3 / 15.0, 1.0)

# ------------------------------------------------------------- de verre wand

## How far his nose sticks out in front of the paws he stands on: the guest
## models are ~29 voxels long with their anchor on voxel 13 (`Art.DIER_ANKER`).
## A stroke that ends at the far wall stops with the NOSE against the wall —
## with his middle on `x(L)` his head used to stand on the tiles beyond it
## (owner, 2026-09-23: the bumping animal "is slecht geanimeerd").
const NEUS := 15.0
## The last stretch before the wall, in voxels: there he swims slowly.
const REM := 10.0
## ... at this tempo: he sees the wall coming (about two thirds of a second).
const TRAAG := 0.6

## The bonk at the wall, as [pose, seconds]: his head dips against it, then
## comes up, dazed (games-b.md §1.7).  1.2 s in all: the time the 💛 Au!
## bubble stays up.  Two poses, not a wobble of four: every pose is another
## box for his number, his name and the bubble, and on a phone each change
## sent them hopping from one side of him to the other.
const BONK := [["snuif", 0.25], ["kijk", 0.95]]

## Where his paws are when his nose touches the far wall.
static func wand_x(bad: Dictionary) -> float:
	return (134.0 if bad.is_empty() else float(bad["x1"])) - NEUS

## The x of every metre of one stroke of `aantal` metres from metre `p0`, split
## into what he swims at his own tempo (`snel`) and what he swims slowly
## (`traag`).  One point per metre, on the number line (§1.6) — except for a
## stroke that ends at the wall: its metres past `wand_x − REM` are spread
## evenly over that last stretch, so the number on his back says `L` exactly
## when his nose touches the wall.  `x_nu` is where he lies now; he never
## swims backwards to reach the wall.
static func slag_x(bad: Dictionary, l: int, p0: int, aantal: int, x_nu: float) -> Dictionary:
	var snel: Array = []
	var traag: Array = []
	if aantal <= 0 or l <= 0:
		return {"snel": snel, "traag": traag}
	if p0 + aantal < l:
		for i in range(1, aantal + 1):
			snel.append(baan_x(bad, l, p0 + i))
		return {"snel": snel, "traag": traag}
	var wand := wand_x(bad)
	var rem := wand - REM
	var n_traag := 0
	for i in range(1, aantal + 1):
		var x := baan_x(bad, l, p0 + i)
		if x <= rem and n_traag == 0:
			snel.append(x)
		else:
			n_traag += 1
	var van: float = x_nu if snel.is_empty() else float(snel[snel.size() - 1])
	for j in range(1, n_traag + 1):
		# already at (or past) the wall: the last metres are counted on the spot
		traag.append(van if van >= wand else lerpf(van, wand, float(j) / float(n_traag)))
	return {"snel": snel, "traag": traag}

## The bump (PLAN N3; owner, 2026-09-23: "Bij stoten moet de speler ook
## opnieuw rekenen met een andere afstand"): the wall throws him back into
## the lane and he floats `L − p` metres before it, so the card that follows
## is a NEW sum — never the question he just missed.  The metre he lands on:
##
##   * the throw is a fifth to a third of the lane (band 3: 2…7 m, band 4:
##     5…17 m, band 5: 7…27 m) — always far enough that his nose is clear of
##     the wall, and never more than one stroke back (`L − p ≤ M`);
##   * he keeps what he swam: he lands AHEAD of the metre he started the
##     stroke from whenever the lane leaves room for that; only a stroke that
##     began closer to the wall than the smallest throw lands a little behind
##     it, and then with the smallest throw;
##   * never the rest he had (that would be the same distance again), never on
##     or past the wall, never behind the start;
##   * the pool's own LCG seeded by the stroke (L, M, p, leg) picks it, so a
##     reload, a replay and a test all see the same throw.
static func bots_plek(l: int, m: int, p_voor: int, leg: int) -> int:
	if l <= 2:
		return 0
	var r: int = clampi(l - p_voor, 1, l)
	var lo := maxi(1, ceili(l / 5.0))
	var hi := maxi(lo, ceili(l / 3.0))
	var worp := lo
	if r - 1 >= lo:
		hi = mini(hi, r - 1)
		var rnd := Sommen.Lcg31.new(l * 977 + m * 131 + p_voor * 17 + leg * 7 + 3)
		worp = lo + mini(hi - lo, JsGetal.vloer(rnd.volgende() * float(hi - lo + 1)))
	elif worp == r:
		worp += 1
	return clampi(l - worp, 1, l - 1)

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
## swimmer is somewhere on it BEFORE the far wall, the turn is not finished and
## the guest is still in the hotel.
##
## `p == L` without `klaar` is the one state that cannot be answered: the rest
## is 0, so every button on the strip is "too far" and since N3 a bump brings
## the same question back — a turn parked against the wall would never end.  It
## can only be reached by a crash in the one frame between the last stroke and
## `_afronden`, and the gentle way out is a fresh lane.
static func geldig(b: Dictionary, gast_bestaat: bool) -> bool:
	if b.is_empty():
		return false
	for sleutel in ["L", "p", "M"]:
		var v = b.get(sleutel, null)
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
			return false
	var l := int(b["L"])
	var p := int(b["p"])
	if l <= 0 or p < 0 or p >= l:
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
const BOTS_KAART_ICOON := "🙃"
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

## Card n straight after a bump (PLAN N3, V1; owner 2026-09-23): the wall is
## not a finish line, and it threw him back — so this card says WHERE he is
## now, with `regel2_verder()` and the new sum under it, and the pictogram is
## a wry 🙃 instead of the swimmer.  6 words, at most 37 characters with the
## longest guest name.
static func regel_bots_terug(naam: String, p: int) -> String:
	return "%s botste terug naar %d meter" % [naam, p]

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
