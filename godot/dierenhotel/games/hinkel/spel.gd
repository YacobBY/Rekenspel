extends MiniGame
## G3 — HET HINKELPAD (games-b.md §3).
##
## In the garden, in the strip `Rooms.get_kamer("tuin").zones.hinkel`, a NUMBER
## LINE of stepping stones runs from 0 to E.  A little wooden staircase with the
## target number baked into it stands on the target stone.  The guest stands on
## a start stone; the child first picks the HOP SIZE and then the NUMBER OF
## HOPS, and the animal hops from stone to stone, counting along.
##
## Every number comes from `Sommen.Hinkel.*` (architecture.md §2, F1): this file
## never re-implements a generator.  What lives here is the world: two voxel
## models, where everything stands, the sentences, and the turn.
##
## Three rows in depth, deliberately apart (games-b.md §3.3): the stones on
## z = 41, the staircase on z = 45 (IN FRONT of the stones, or it disappears
## behind the number plates of the stones to its right) and the animal's walking
## line on z = 44 — only at the end does it step to z = 47 and stand ON the
## staircase.  Because a piece three voxels towards the viewer sits six pixels
## further left on screen, every row gets exactly that difference added to its x
## (`_x_op_rij`), so `x - z` is equal for all rows and everything stays in the
## same screen column as its own stone.
##
## The stones and the staircase are LOOSE DECOR and cost not one button: a
## number per stone could never be a hotspot, because the button layer holds
## sixteen per room.  The guest's own number is the one chip on screen.

# ------------------------------------------------------------------ maten

const STENEN_MAX := 21          ## the most stones a band can have

## The height of the target board on the little staircase, in voxels: a full row
## (8) above the highest plate the path itself carries (`_trap_model`).
const TRAP_BORD := 18

## Voxels of daylight between two number plates (`_bord_dx`).  One voxel is `2*g`
## px wide on screen and the outline eats `g / 2,6` px off either side, so at two
## voxels even the smallest voxel size (g = 2) keeps two real pixels of white
## between two numbers; at one voxel they would share a pixel column.
const BORD_LOS := 2.0

const STEEN_MARGE := 2.5        ## voxels from his stone: he stands on it (`_op_start_steen`)
const VRIJ_S := 2.0             ## how often the strip is swept clear again
const ZEG_S := 2.4              ## how long the soft word at the animal stays
const EIND_S := 4.6             ## and how long the finished card stays readable
const LEEG_S := 1.8             ## "nog geen gasten" and then close

## The garden zone, as a fallback if `Rooms` ever moves it.
const ZONE_TERUG := {"x0": 24, "x1": 100, "z0": 34, "z1": 50}

const DIER_ICO := {"puppy": "🐶", "poes": "🐱", "konijn": "🐰", "gans": "🦆"}
const DIER_ICO_ANDERS := "🐾"

# colours from the same warm palette as the rooms
const STEEN := Color("#C7C2B4")
const STEEN_TOP := Color("#DAD5C6")
const STEEN_G := Color("#BFAE92")
const STEEN_G_TOP := Color("#D8CBAE")
const BORD := Color("#FFFDF6")
const INKT := Color("#4A3B33")
const HOUT := Color("#D0A87A")
const HOUT_D := Color("#B98F62")
const HOUT_L := Color("#E2C094")
const VLAG := Color("#F5B0C2")

## Digits of 3 x 5 voxels.  The plate is ONE slab one voxel thick with the digit
## painted onto that same slab — not as little blocks in front of it.  That is
## the difference between a readable number and a row of brown bumps: the face
## looking at the viewer (+z) gets a flat, sharp pattern of 2 x 2 css-px per
## font point instead of twenty cubes with three faces each.
const CIJFER := {
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"],
	"3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "111"],
}

# ------------------------------------------------------------------ stand

## The turn.  Lives in `ctx.data()["stand"]`, so it survives a reload; a promise
## never does (architecture.md §6.2 rule 3).
var _s: Dictionary = {}
var _kaart: Ui.Kaart = null
var _opzij: Array[String] = []      ## guests we sent off the strip
var _hop_nr := 0                    ## every hop series gets a number
var _wacht_loopt := false           ## exactly ONE wait for the guest at a time
var _t0 := 0

# =================================================================== aanmelding

func definitie() -> Dictionary:
	# The entry button hangs on the hok — the fixed object the hinkel strip lies
	# in front of — and slides with dx/dz exactly onto the first stone, because
	# our own stones are loose decor that only exists once `start()` ran.
	var m := _pad_maat_van(3)
	var hok := {"x": 67.0, "z": 19.0}
	var r = Rooms.get_kamer("tuin")
	if r != null:
		for stuk in r.decor:
			if str(stuk.get("n", "")) == "hok":
				hok = {"x": float(stuk["x"]), "z": float(stuk["z"])}
				break

	# The three callables below are read by the hotel long after this node has
	# been freed (the registry instantiates the scene only to read this record),
	# so not one of them touches `self`: they read the autoloads and the
	# dictionary they captured, exactly as `games/_voorbeeld/spel.gd` does.
	var wil_spelen := func(s: Dictionary) -> Dictionary:
		for g in s.get("gasten", []):
			if str(g.get("bed", "")).is_empty():
				continue
			if str(g.get("behoefte", "")) == "spelen" and not bool(g.get("blij", false)):
				return g
		return {}

	var taak := {"id": "hinkel", "icoon": "🪨", "kamer": "tuin", "prio": 5}
	# games-b.md §3.2: `prio` is a READ FUNCTION in the HTML, because `hotel.js`
	# reads it again at every redraw — 2 while a guest is waiting to play, 5
	# otherwise.  Why not always 1: the board holds three cards and a card that
	# was just ticked keeps its tick for the rest of the day; a fixed prio 1
	# pushed exactly that tick off the board.
	# `Hotel.spel_taken()` reads `prio` as a plain int (see "Contract gaps" in
	# the report), and it calls `wanneer` BEFORE it reads `prio`, so the read
	# function lives here without touching a shared file.  The record is fetched
	# from the registry instead of captured: a lambda that captures the very
	# dictionary it is stored in is a reference cycle, and GDScript collects
	# none — the engine then reports leaked instances at exit.
	taak["wanneer"] = func(s: Dictionary) -> bool:
		var t: Dictionary = Games.definitie("hinkel").get("taak", {})
		if not t.is_empty():
			t["prio"] = 2 if not (wil_spelen.call(s) as Dictionary).is_empty() else 5
		for g in s.get("gasten", []):
			if not str(g.get("bed", "")).is_empty():
				return true
		return false
	taak["tekst"] = func(s: Dictionary) -> String:
		var g: Dictionary = wil_spelen.call(s)
		return "%s wil hinkelen" % str(g["naam"]) if not g.is_empty() \
			else "Hinkel op de stenen"

	# The stones stay on the path while no turn runs (owner, 2026-09-23: "Dan
	# hangt elk spel aan iets wat je echt ziet"): band 3's eleven plain stones —
	# the big ones on 0, 5 and 10 — with no plates.  No staircase: it stands on
	# the target of a turn, and at the end of the path the souvenir stall would
	# hide it.  A turn replaces them by its own.
	var rust: Array = []
	for i in int(m["stenen"]):
		rust.append({"id": "rust_hk_steen%d" % i, "model": "hinkel_steen",
			"x": float(m["eerste"]) + float(m["steek"]) * float(i), "z": float(m["zSteen"]),
			"params": {"groot": i % 5 == 0}})
	return {
		"naam": "Hinkelpad",
		"kamer": "tuin",
		"stub": false,
		"wens": "spelen",
		"hotspot": {"obj": "hok", "icoon": "🪨", "label": "Hinkelen", "hoog": 6,
			"dx": JsGetal.rond(float(m["eerste"]) - float(hok["x"])),
			"dz": JsGetal.rond(float(m["zSteen"]) - float(hok["z"])),
			"rust": "rust_hk_steen0"},
		"modellen": modellen(),
		"rust": rust,
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"taak": taak,
	}

# =================================================================== start/stop

func start(_c: SpelCtx) -> void:
	_registreer_modellen()
	var lijst := _spelers()
	if lijst.is_empty():
		_geen_gasten()
		return
	var d := ctx.data()
	var n := _gasten().size()
	var band: int = ctx.state.band()
	var dag := int(ctx.state.s["dag"])
	_s = d.get("stand", {})
	# the animal the child picked on the game bar hops, if he may (owner,
	# 2026-09-23); half a path of another animal is simply not finished
	var wil := ctx.voorkeur(spelers())
	# half a turn from the save may go on, but only when the day, the number of
	# guests, the band AND the guest still match — and when it is the picked
	# animal's: another animal's is dropped, and he makes room (`weg`)
	var hervat := not (_s.is_empty() or str(_s.get("fase", "")) == "af"
			or int(_s.get("dag", 0)) != dag or int(_s.get("N", -1)) != n
			or int(_s.get("band", 0)) != Sommen.Hinkel.band_of(band)
			or str(_s.get("gast", "")).is_empty()
			or State.gast_van(str(_s.get("gast", ""))).is_empty())
	var weg := ""
	if hervat and not wil.is_empty() and wil != str(_s.get("gast", "")):
		weg = str(_s.get("gast", ""))
		hervat = false
	if not hervat:
		_s = _nieuwe_stand(n, band, dag, str(lijst[0]["id"]) if wil.is_empty() else wil)
		d["stand"] = _s
	ctx.speelt(str(_s.get("gast", "")))
	_t0 = Time.get_ticks_msec()
	if str(_s["fase"]) == "hop":
		_s["fase"] = "sprong"          # a hop survives no reload
	_hop_nr += 1
	_opzij.clear()
	_wacht_loopt = false
	_zet_decor()
	State.bewaar()
	_haal_gast()                       # the card comes once he stands on his stone
	# who hopped the dropped path makes room, or turns back on his way here;
	# on the stones the loop below sends him to the grass like any other guest
	if not weg.is_empty() and weg != str(_s.get("gast", "")):
		ctx.laat_gaan(weg)
	_houd_vrij_lus()                   # the other guests off the stones

func stop() -> void:
	_hop_nr += 1                       # running hop series decide nothing more
	# A pose is a NEW order, so the promise of `stappen` falls false and the
	# animal does not hang in the air when the game stops mid-jump.
	if not _s.is_empty() and str(_s.get("fase", "")) == "hop" \
			and not str(_s.get("gast", "")).is_empty():
		ctx.wereld.pose(str(_s["gast"]), "wacht")
	_laat_los()
	_kaart = null
	ctx.hotspots.wis_alles()
	ctx.hotspots.laat()
	# `Games.stop()` wipes our loose decor as well; this one line makes the
	# clean-up independent of who calls stop().
	ctx.wereld.decor_wis_eigenaar(ctx.id)
	State.bewaar()

## No guest with a bed: one word on the hok and then the game closes itself.
func _geen_gasten() -> void:
	var hok: Dictionary = ctx.wereld.mik("hok", "tuin")
	ctx.ui.wolk({"id": "hk_leeg", "kamer": "tuin",
		"x": float(hok.get("x", 67.0)), "z": float(hok.get("z", 19.0)),
		"hoog": 26.0, "icoon": "🛏", "tekst": "nog geen gasten",
		"vlak": ctx.wereld.vlak_van("hok", float(hok.get("x", 67.0)),
			float(hok.get("z", 19.0)), 0.0)})
	_leeg_straks()

func _leeg_straks() -> void:
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg("hk_leeg")
	ctx.sluit()

func _nieuwe_stand(n: int, band: int, dag: int, gast_id: String) -> Dictionary:
	var b := Sommen.Hinkel.beurt(n, band, dag)
	return {"dag": dag, "N": n, "band": int(b["band"]), "E": int(b["E"]),
		"stap": int(b["stap"]), "gast": gast_id, "s": int(b["s"]),
		"doel": int(b["doel"]), "sprong": 0, "n": int(b["n"]), "hops": 0,
		"tel": 0, "fase": "sprong", "melding": "",
		"missers": 0, "pogingen": 0, "ster": 0, "wens": 0}

# =================================================================== de gasten

## Guests with a bed.  `N` for the generator is this count (games-b.md §3.4).
func _gasten() -> Array:
	var uit: Array = []
	for g in State.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(g)
	return uit

## Whoever wishes 🧶 `spelen` and is not happy yet plays first; then whoever is
## already in the garden, so nobody has to walk half the hotel first.
func _spelers() -> Array:
	var alle := _gasten()
	var wil: Array = []
	for g in alle:
		if str(g.get("behoefte", "")) == "spelen" and not bool(g.get("blij", false)):
			wil.append(g)
	var lijst: Array = wil if not wil.is_empty() else alle
	var in_tuin: Array = []
	var elders: Array = []
	for g in lijst:
		var d = ctx.wereld.dier(str(g.get("id", "")))
		if d != null and d.kamer == "tuin":
			in_tuin.append(g)
		else:
			elders.append(g)
	return in_tuin + elders

## Who may hop when the child picks the animal himself (the game bar): every
## guest with a bed, in check-in order.  `_spelers` stays the game's own order
## when nobody was picked.
func spelers() -> Array:
	var uit: Array = []
	for g in _gasten():
		uit.append(str(g.get("id", "")))
	return uit

func _gast() -> Dictionary:
	if _s.is_empty():
		return {}
	return State.gast_van(str(_s.get("gast", "")))

func _naam() -> String:
	var g := _gast()
	return str(g.get("naam", "De gast")) if not g.is_empty() else "De gast"

func _ico(g: Dictionary) -> String:
	return str(DIER_ICO.get(str(g.get("soort", "")), DIER_ICO_ANDERS))

# =================================================================== maatvoering

func _zone() -> Dictionary:
	var r = Rooms.get_kamer("tuin")
	if r != null and r.zones.has("hinkel"):
		var z: Dictionary = r.zones["hinkel"]
		if z.has("x0"):
			return z
	return ZONE_TERUG

## Every measurement of the path, in voxels — so it is screen-size free.
func _pad_maat_van(band: int) -> Dictionary:
	var b := Sommen.Hinkel.band_of(band)
	var z := _zone()
	var n := int(Sommen.Hinkel.BAND[b]["stenen"])
	var eerste := float(z["x0"]) + 3.0
	var laatste := float(z["x1"]) - 3.0
	var zs := float(JsGetal.rond((float(z["z0"]) + float(z["z1"])) / 2.0) - 1)
	return {"eerste": eerste, "laatste": laatste, "stenen": n,
		"steek": (laatste - eerste) / float(maxi(1, n - 1)),
		"zSteen": zs, "zDier": zs + 3.0, "zTrap": zs + 4.0, "zTop": zs + 6.0}

func _pad_maat() -> Dictionary:
	return _pad_maat_van(int(_s.get("band", 3)))

## The x of number `n` on the line (0 = the first stone, E = the last).
func _x_van(n: float, band: int) -> float:
	var m := _pad_maat_van(band)
	var e := float(Sommen.Hinkel.BAND[Sommen.Hinkel.band_of(band)]["E"])
	return float(m["eerste"]) + (float(m["laatste"]) - float(m["eerste"])) * n / e

## The same number on another depth row, shifted so that `x - z` stays equal and
## everything keeps standing in the same screen column as its stone.
func _x_op_rij(n: float, z0: float, band: int) -> float:
	return _x_van(n, band) + (z0 - float(_pad_maat_van(band)["zSteen"]))

func _dier_x(n: float) -> float:
	var band := int(_s.get("band", 3))
	return _x_op_rij(n, float(_pad_maat_van(band)["zDier"]), band)

## The number stone `i` stands for.  EVERY stone has one — it is the plate that
## not every stone wears (`_steen_getal`), while the big, darker tick stones
## count in fives and tens along the whole line.
func _steen_waarde(i: int, band: int) -> int:
	return i * int(Sommen.Hinkel.BAND[Sommen.Hinkel.band_of(band)]["stap"])

## Which stone wears a number PLATE?  Band 3: every stone (a one-character plate
## is 5 voxels = 10*g px on a pitch of 7 voxels = 14*g px, so they read).
## Band 4/5: only every twentieth — 0, 20, 40, 60, 80, 100.  The stones lie
## 3,5 voxels apart there, so a plate on every ten stood 7*g px apart while it is
## itself 18*g px wide: the tens smudged into one white ribbon.  Every FOURTH
## stone leaves 4 * 3,5 = 14 voxels = 28*g px between two plates against those
## 18*g px, and the widest plate of all ("100", 26*g px) still has room.
## -1 means "no plate".
func _steen_getal(i: int, band: int) -> int:
	var b := Sommen.Hinkel.band_of(band)
	var n := _steen_waarde(i, b)
	if b == 3:
		return n
	return n if i % 4 == 0 else -1

## How high does the plate hang?  Two plates at the same height must stand clear
## of each other: in band 3 only "10" is two characters wide and goes one row up.
## Band 4/5 keeps every plate low — with one plate per twenty they no longer
## touch, and a number line reads as a LINE: the old alternating lift made two
## rows of numbers of it, and the child had to find out which number belonged to
## which stone.
func _rij_van_steen(i: int, band: int) -> int:
	var b := Sommen.Hinkel.band_of(band)
	var n := _steen_getal(i, b)
	if n < 0 or b != 3:
		return 0
	return 1 if str(n).length() > 1 else 0

## Where the plate hangs sideways, in voxels.  It keeps `BORD_LOS` voxels clear
## of the plate on its LEFT (`links` is that plate's right edge) and it stays
## inside the strip as long as that costs its neighbour nothing.
##
## The widest number of a line always stands on the LAST stone — "10" is 9 voxels
## wide against a pitch of 7, "100" is 13 against a pitch of 14 — and the strip
## ends three voxels behind that stone.  Pulling such a plate back inside the
## strip is exactly what pushed it into its neighbour: "9" and "10", and "80" and
## "100", ran together into one white ribbon.  The garden itself runs on to 130
## and the plates are loose decor without a button, so a plate rather hangs over
## the end of the strip than over the number beside it.
func _bord_dx(x: float, txt: String, links := -INF) -> int:
	var z := _zone()
	var hw := float(_getal_breed(txt)) / 2.0 + 1.0
	var dx := 0.0
	if x - hw < float(z["x0"]):
		dx = float(z["x0"]) - (x - hw)
	if x + hw > float(z["x1"]):
		dx = float(z["x1"]) - (x + hw)
	return JsGetal.rond(maxf(dx, links + BORD_LOS - (x - hw)))

# =================================================================== de modellen

static func _getal_breed(txt: String) -> int:
	return txt.length() * 4 - 1

func _registreer_modellen() -> void:
	for naam in modellen():
		Art.registreer_model(naam, modellen()[naam])

## The two models, as functions of the SCRIPT: the registry draws the resting
## stones with them long after the instance it scanned was freed.
func modellen() -> Dictionary:
	return {"hinkel_steen": Callable(get_script(), "_steen_model"),
		"hinkel_trap": Callable(get_script(), "_trap_model")}

## The number plate: one slab, one voxel thick, with the digits painted on it.
static func _bak_getal(v: Array, txt: String, dx: float, y0: int, zp: int) -> void:
	var w := _getal_breed(txt)
	var x0 := JsGetal.rond(dx - float(w - 1) / 2.0)
	for r in range(-1, 6):
		for c in range(-1, w + 1):
			var aan := false
			if r >= 0 and r <= 4 and c >= 0 and c < w:
				@warning_ignore("integer_division")
				var i := c / 4
				var kol := c - i * 4
				var rij: Array = CIJFER.get(txt.substr(i, 1), [])
				aan = kol < 3 and not rij.is_empty() \
					and str(rij[r]).substr(kol, 1) == "1"
			v.append({"x": x0 + c, "y": y0 + 4 - r, "z": zp,
				"k": INKT if aan else BORD})

## `hinkel_steen` — a flat stepping stone; every fifth (band 3) or every tenth
## (band 4/5) is bigger and darker, so the path carries its own tick marks.  A
## stone with a number wears its plate BEHIND it, just peeping over the top: it
## covers nothing, and the path stays a path instead of becoming a fence.
static func _steen_model(p: Dictionary) -> Array:
	var v: Array = []
	var getal := int(p.get("getal", -1))
	var groot := bool(p.get("groot", false))
	var kl := STEEN_G if groot else STEEN
	var top := STEEN_G_TOP if groot else STEEN_TOP
	var b := 5 if groot else 4
	@warning_ignore("integer_division")
	var half := b / 2
	ArtVorm.bx(v, -half, 0, -2, b, 2, 5, kl)
	ArtVorm.verf(v, -3, 3, 1, 1, -2, 2, top)
	if getal >= 0:
		var y0 := 2 + int(p.get("rij", 0)) * 8
		_bak_getal(v, str(getal), float(p.get("dx", 0)), y0, -3)
	return v

## `hinkel_trap` — three treads climbing with the path (towards +x), each with a
## light top and a dark riser, and a MAST above them carrying the target number
## and its pink flag.  The TARGET NUMBER sits in this model and not in a loose
## chip: two chips (the guest's number and the staircase's) landed exactly on top
## of each other at the end of a turn.
##
## The mast is what makes the target findable.  The board used to hang two voxels
## over the top tread (y 9..15), and at the end of a turn the guest stands ON
## that tread: measured from its own floor point a rabbit reaches 34 voxel-px and
## it stands five voxel-px lower on screen, so it swallowed the number AND its
## flag — the very thing the child is aiming at.  The board on `TRAP_BORD`
## (y 17..23) and the flag on y 24 clear the tallest guest by four voxel-px at
## every voxel size, and the pole underneath keeps it standing on its stone.
static func _trap_model(p: Dictionary) -> Array:
	var v: Array = []
	for j in 3:
		var h := 3 + 3 * j
		ArtVorm.bx(v, -3 + 2 * j, 0, -2, 2, h, 5, HOUT)
		ArtVorm.verf(v, -3 + 2 * j, -2 + 2 * j, h - 1, h - 1, -2, 2, HOUT_L)
		ArtVorm.verf(v, -3 + 2 * j, -2 + 2 * j, 0, h - 2, 2, 2, HOUT_D)
	var getal := int(p.get("getal", -1))
	if getal >= 0:
		var txt := str(getal)
		var dx := float(p.get("dx", 0))
		var w := _getal_breed(txt)
		var x0 := JsGetal.rond(dx - float(w - 1) / 2.0)
		# the mast: out of the treads up to just under the board.  Its lower half
		# stands INSIDE the staircase, where every face of it is culled away.
		ArtVorm.bx(v, JsGetal.rond(dx), 0, 0, 1, TRAP_BORD, 1, HOUT_D)
		_bak_getal(v, txt, dx, TRAP_BORD, 0)
		# a pink cap over the plate and the flag on top of the mast: this is the
		# target of the turn
		ArtVorm.verf(v, x0 - 1, x0 + w, TRAP_BORD + 5, TRAP_BORD + 5, 0, 0, VLAG)
		ArtVorm.bx(v, x0 - 1, TRAP_BORD + 6, 0, w + 2, 1, 1, VLAG)
	return v

# =================================================================== het decor

## How many stones lie between two plates: every stone carries one in band 3,
## every fourth in band 4/5 (`_steen_getal`).
func _borden_om(band: int) -> int:
	return 1 if Sommen.Hinkel.band_of(band) == 3 else 4

## The right edge of the plate of stone `i`, in voxels, `-INF` if there is no
## such stone.  It reads the stone to ITS left in turn, so a plate that has to
## make way hands that on down the line.
func _bord_rechts(i: int, band: int) -> float:
	if i < 0:
		return -INF
	var st := _steen_plek(i, band)
	var n := int(st["params"]["getal"])
	if n < 0:
		return -INF
	return float(st["x"]) + float(st["params"]["dx"]) \
		+ float(_getal_breed(str(n))) / 2.0 + 1.0

## Where stone `i` stands and what it carries — one record, so the world and the
## test read exactly the same stone.
func _steen_plek(i: int, band: int) -> Dictionary:
	var m := _pad_maat_van(band)
	var b := Sommen.Hinkel.band_of(band)
	var x: float = float(m["eerste"]) + float(m["steek"]) * float(i)
	var n := _steen_getal(i, b)
	return {"x": x, "z": float(m["zSteen"]),
		"params": {"getal": n, "rij": _rij_van_steen(i, b),
			"dx": 0 if n < 0 else _bord_dx(x, str(n),
				_bord_rechts(i - _borden_om(b), b)),
			# the big, darker tick stones keep counting in fives and tens, also
			# where the line only writes out every twentieth
			"groot": _steen_waarde(i, b) % (5 if b == 3 else 10) == 0}}

## And where the little staircase with the target number stands.
func _trap_plek() -> Dictionary:
	var m := _pad_maat()
	var band := int(_s.get("band", 3))
	var doel := int(_s.get("doel", 0))
	var x := _x_op_rij(float(doel), float(m["zTrap"]), band)
	return {"x": x, "z": float(m["zTrap"]),
		"params": {"getal": doel, "dx": _bord_dx(x, str(doel))}}

func _zet_decor() -> void:
	var m := _pad_maat()
	var band := int(_s["band"])
	for i in int(m["stenen"]):
		var st := _steen_plek(i, band)
		ctx.wereld.decor("tuin", {
			"id": "hk_steen%d" % i, "model": "hinkel_steen",
			"x": float(st["x"]), "z": float(st["z"]), "params": st["params"]})
	# a band with fewer stones never leaves a few of the previous one standing
	for i in range(int(m["stenen"]), STENEN_MAX):
		ctx.wereld.decor_weg("tuin", "hk_steen%d" % i)
	var t := _trap_plek()
	ctx.wereld.decor("tuin", {"id": "hk_trap", "model": "hinkel_trap",
		"x": float(t["x"]), "z": float(t["z"]), "params": t["params"]})

# =================================================================== de gast halen

func _op_start_steen() -> bool:
	if _s.is_empty():
		return false
	var g := _gast()
	if g.is_empty():
		return false
	var d = ctx.wereld.dier(str(g["id"]))
	if d == null or d.kamer != "tuin":
		return false
	var m := _pad_maat()
	return absf(d.x - _dier_x(float(int(_s["s"])))) <= 2.5 \
		and absf(d.z - float(m["zDier"])) <= 3.5

## The guest first, then the card (owner, 2026-09-23: "Zorg dat de minigame
## pas begint wanneer het dier er is" — this overrules PLAN N11, where the sum
## stood there at once while the animal was still on his way).  He walks to his
## stone — a guest lying in kamer 1 through the whole hotel, with the hotel's
## "komt eraan" bubble and its `👀 Volg` at the garden door — and nothing of
## the turn is on screen until he stands there: no card, no strip, not the
## number above his head (`_teken`).  There is always exactly ONE wait
## (`_wacht_loopt`); `ctx.wacht_op` sends him again when a journey was
## overtaken by the engine or by another game.
func _haal_gast() -> void:
	if _wacht_loopt or _s.is_empty():
		return
	var g := _gast()
	if g.is_empty():
		return
	var id := str(g["id"])
	var plek := Vector2(_dier_x(float(int(_s["s"]))), float(_pad_maat()["zDier"]))
	_wacht_loopt = true
	if not ctx.is_er(id, plek, STEEN_MARGE):
		_teken()                         # the old card goes while he walks
	var er: bool = await ctx.wacht_op(id, plek, {"tempo": 1.4, "marge": STEEN_MARGE})
	_wacht_loopt = false
	if not actief or _s.is_empty():
		return
	if not er:
		ctx.sluit.call_deferred()        # the hopper is gone
		return
	if str(_s.get("fase", "")) == "hop":
		_s["fase"] = "sprong"            # a series that never set off: ask again
		_s["sprong"] = 0
	_teken()

## A walk nobody waits for.  `World.loop_naar` is awaitable; this void wrapper
## is the shape `games/_voorbeeld/spel.gd` uses to fire one and forget it.
func _loop_los(id: String, x: float, z: float, o: Dictionary) -> void:
	await ctx.wereld.loop_naar(id, x, z, o)

# =================================================================== de anderen

## The garden has wander places right on the hinkel strip: a guest standing
## there stands over the number plates and over the staircase, and then the
## number line cannot be read.  Everyone who is not playing is sent to the grass
## IN FRONT of the strip with `na: "wacht"`, so he does not wander back.
func _op_strook(d) -> bool:
	if d == null or d.kamer != "tuin":
		return false
	var z := _zone()
	return d.x > float(z["x0"]) - 10.0 and d.x < float(z["x1"]) + 10.0 \
		and d.z > float(z["z0"]) - 7.0 and d.z < float(z["z1"]) + 7.0

## The free cells on the grass in front of the strip, left to right.
func _gras_plekken() -> Array:
	var r = Rooms.get_kamer("tuin")
	if r == null:
		return []
	var z := _zone()
	var kr: Dictionary = r.zones.get("kraam", {})
	var uit: Array = []
	for v in r.vrij:
		if float(v["z"]) < float(z["z1"]) + 10.0:
			continue                    # still too close to the path
		if not kr.is_empty() and float(v["x"]) > float(kr["x0"]) - 8.0 \
				and float(v["z"]) < float(kr["z1"]) + 8.0:
			continue                    # and not at the souvenir stall
		uit.append(v)
	uit.sort_custom(func(a, b) -> bool:
		return (float(a["x"]) - float(a["z"])) < (float(b["x"]) - float(b["z"])))
	return uit

func _houd_vrij() -> void:
	var vrij := _gras_plekken()
	if vrij.is_empty():
		return
	var i := 0
	for g in State.s["gasten"]:
		var id := str(g.get("id", ""))
		if id == str(_s.get("gast", "")):
			continue
		if not _op_strook(ctx.wereld.dier(id)):
			continue
		var v: Dictionary = vrij[i % vrij.size()]
		i += 1
		if not _opzij.has(id):
			_opzij.append(id)
		_loop_los(id, float(v["x"]), float(v["z"]), {"na": "wacht"})

func _houd_vrij_lus() -> void:
	while actief and not _s.is_empty() and str(_s.get("fase", "")) != "af":
		_houd_vrij()
		if not await na(VRIJ_S):
			break

## `stop()` gives them their own way back.
func _laat_los() -> void:
	for id in _opzij:
		ctx.wereld.pose(id, "rust")
	_opzij.clear()

# =================================================================== tekenen

func _afstand() -> int:
	return absi(int(_s["doel"]) - int(_s["s"]))

func _richting() -> int:
	return 1 if int(_s["doel"]) >= int(_s["s"]) else -1

func _maten() -> Array[int]:
	return Sommen.Hinkel.maten(_afstand(), int(_s["band"]))

func _aantal_goed(k: int) -> int:
	@warning_ignore("integer_division")
	return _afstand() / maxi(1, k)

func _som_regel() -> String:
	return "van %d naar %d" % [int(_s["s"]), int(_s["doel"])]

## A frame under 360 units: there the card is 170 units wide and every sentence
## wraps, so one short line counts for more than a whole sentence (HOTEL.md §9:
## "het dier blijft zichtbaar" beats "de zin op één regel").  This is the port's
## one central breakpoint (`Ui.smal()`), which replaces hinkel's own 320 px
## threshold — architecture.md §1.2 drops the per-game width thresholds.
func _krap() -> bool:
	return Ui.smal()

## The sentences above the sum: one plain sentence, <= 8 words and <= 40
## characters, and at most one short second line (games-b.md §3.9, verbatim).
func _zinnen() -> Dictionary:
	var g := _gast()
	var nm := _naam()
	var k := _krap()
	var fase := str(_s["fase"])
	if fase == "af":
		return {"icoon": "✅", "zin": ["Precies op de trap!"]}
	# no "komt eraan" card: while he walks to his stone the game draws nothing
	# and the hotel's own bubble says who is coming (owner, 2026-09-23)
	if fase == "hop":
		return {"icoon": _ico(g), "zin": ["Tel maar mee"] if k
			else ["%s hinkelt" % nm, "Tel maar mee"]}
	if fase == "aantal":
		return {"icoon": "🪨", "zin": ["Hoeveel sprongen?"] if k
			else ["%s springt %d%s" % [nm, int(_s["sprong"]),
					" terug" if _richting() < 0 else " per keer"],
				"Hoeveel sprongen?"]}
	if str(_s["melding"]) == "ver":
		return {"icoon": _ico(g), "zin": ["Oei, te ver!"] if k
			else ["Oei, te ver!", "Kies je sprong terug"]}
	if str(_s["melding"]) == "kort":
		return {"icoon": _ico(g), "zin": ["Nog even verder"] if k
			else ["%s staat op %d" % [nm, int(_s["s"])], "Nog even verder"]}
	return {"icoon": _ico(g), "zin": ["Kies je sprong"] if k
		else ["%s staat op %d, trap bij %d" % [nm, int(_s["s"]), int(_s["doel"])],
			"Kies je sprong"]}

## Half the card, and the strip that hangs under it — the block the aim point
## has to leave room for on both sides.
const KAART_HALF := 60.0

## The world point that projects onto this point of the frame (the inverse of
## `World.mik_punt`, at height 0).  `x − z` and `x + z` are exactly what the
## isometry uses, so one division per axis gives the voxel back.
func _plek_op_scherm(px: float, py: float) -> Dictionary:
	var nul: Vector2 = ctx.wereld.mik_punt(0.0, 0.0, 0.0)
	var sc: Dictionary = ctx.wereld.schaal()
	var u := (px - nul.x) / maxf(0.01, float(sc["pxPerVoxelX"]))
	var d := (py - nul.y) / maxf(0.01, float(sc["pxPerVoxelY"]))
	return {"kamer": "tuin", "x": (d + u) / 2.0, "z": (d - u) / 2.0, "y": 0.0}

## Where the card hangs (games-b.md §3.7).  Standing it lies on the grass IN
## FRONT of the stones, under the last stone and under the animal's paws; lying
## down it lies BESIDE them, its right edge clear of the animal.
##
## The HTML reached that by drawing the card, reading the DOM back and shifting
## it, up to four rounds per step (`kaartPast`).  Here `World.mik_punt()` and
## `World.vlak_van()` are exact BEFORE the first draw, so the same two rules are
## one calculation: aim at the screen point the card should have and hand that
## point back to the world (architecture.md §1.2).  The frame's own middle is
## the vertical target in landscape, so the choice strip has room under the card
## AND above it; `Hits` does the rest (§4.3), and this game therefore needs no
## resize listener at all.
func _kaart_plek() -> Dictionary:
	var m := _pad_maat()
	var band := int(_s.get("band", 3))
	var f: Rect2 = ctx.wereld.kader_rect()
	var midden: Vector2 = ctx.wereld.mik_punt(
		(float(m["eerste"]) + float(m["laatste"])) / 2.0, float(m["zSteen"]), 0.0)
	if f.size.x / maxf(1.0, f.size.y) > 1.15:
		# beside the path: the whole block keeps 26 css-px between its right edge
		# and the first stone, halfway up the frame so the strip has room under
		# the card AND above it
		var eerste: Rect2 = ctx.wereld.vlak_van("hinkel_steen", float(m["eerste"]),
			float(m["zSteen"]), 0.0, {"getal": 0, "rij": 0, "dx": 0, "groot": true})
		var links: float = eerste.position.x if eerste.size.x > 0.0 \
			else ctx.wereld.mik_punt(float(m["eerste"]), float(m["zSteen"]), 0.0).x
		var half := float(UiSomkaart.BREED_KLEIN if Ui.smal() else UiSomkaart.BREED) * 0.5
		return _plek_op_scherm(links - 26.0 - half, f.size.y * 0.5)
	# under the path: below the last stone AND below the animal's paws
	var laatste: Rect2 = ctx.wereld.vlak_van("hinkel_steen", float(m["laatste"]),
		float(m["zSteen"]), 0.0, {"getal": -1, "rij": 0, "dx": 0,
			"groot": band != 3})
	var onder := laatste.end.y + 16.0 if laatste.size.y > 0.0 \
		else midden.y + 16.0
	var dier := _kaart_vlak()
	if dier.size.y > 0.0:
		onder = maxf(onder, dier.end.y + 8.0)
	return _plek_op_scherm(midden.x, onder + KAART_HALF)

## The rectangle the card has to stay clear of: the guest, plus the room the
## choice strip needs UNDER the card (the strip is glued `KLEEF` units below it).
##
## This is what replaces `kaartPast` (games-b.md §3.7).  The HTML drew the card,
## read the DOM back, shifted it and repeated that up to four times per step;
## here `World.vlak_van_dier()` is exact and synchronous before the first draw,
## and `Hits` lifts a fixed card off its own object in whole bands — so the card
## AND its strip are clear of the animal by construction, in one pass
## (architecture.md §1.2, §4.3).
func _kaart_vlak() -> Rect2:
	var g := _gast()
	if g.is_empty():
		return Rect2()
	var d = ctx.wereld.dier(str(g["id"]))
	if d == null or d.kamer != "tuin":
		return Rect2()
	var r: Rect2 = ctx.wereld.vlak_van_dier(str(g["id"]))
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return Rect2()
	var strook := float(Ui.tap_maat()) + 12.0 + float(Hits.KLEEF)
	return Rect2(r.position - Vector2(0.0, strook), r.size + Vector2(0.0, strook))

## Where the guest's own number hangs: it walks with him, in his room.
func _volg_dier(id: String, hoog: float) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "y": hoog, "kamer": d.kamer,
			"vlak": World.vlak_van_dier(id), "d": d.x + d.z + 0.6}

## The guest's number, big and readable above his head: while he is hopping that
## chip counts along (1 … 2 … 3), afterwards it shows the number of the stone he
## stands on.  The TARGET number is no chip but sits in the model of the
## staircase, so the two numbers can never land on each other.
func _zet_gast_getal(n: int, titel: String) -> void:
	var g := _gast()
	if g.is_empty():
		return
	var id := str(g["id"])
	var d = ctx.wereld.dier(id)
	ctx.ui.getal_tag({"x": d.x if d != null else 0.0, "z": d.z if d != null else 0.0},
		n, {"id": "hk_gast", "kamer": "tuin", "y": 30, "prio": 10,
			"titel": titel, "volg": _volg_dier(id, 30.0)})

func _teken_cijfers() -> void:
	var g := _gast()
	if g.is_empty():
		return
	# At the end he stands ON the staircase and the target board rises right
	# behind his head: a chip there lands on the very number he was aiming at.
	# The board says it (that is why `hinkel_trap` carries the number at all), the
	# card says it and the star bubble says it — the chip has counted its hops.
	if str(_s["fase"]) == "af":
		return
	if str(_s["fase"]) == "hop":
		var t := int(_s["tel"])
		_zet_gast_getal(t, "sprong %d" % t)
	else:
		var n := int(_s["s"])
		_zet_gast_getal(n, "%s staat op %d" % [str(g.get("naam", "")), n])

func _teken_kaart() -> void:
	var z := _zinnen()
	var plek := _kaart_plek()
	var fase := str(_s["fase"])
	var keuzes: Array = []
	if _op_start_steen() and fase == "sprong":
		var terug := _richting() < 0
		for k in _maten():
			var kk := int(k)
			keuzes.append({"id": "k%d" % kk, "icoon": "🪨",
				"tekst": ("terug %d" % kk) if terug else ("sprong %d" % kk),
				"kies": func(_id) -> void: _kies_sprong(kk)})
	elif _op_start_steen() and fase == "aantal":
		var zaad := int(_s["s"]) + int(_s["dag"]) + int(_s["pogingen"])
		for n in Sommen.Hinkel.keuze_getallen(_aantal_goed(int(_s["sprong"])), zaad):
			var nn := int(n)
			keuzes.append({"id": "n%d" % nn, "icoon": "🪨", "tekst": "%d keer" % nn,
				"kies": func(_id) -> void: _antwoord(nn)})
	var zin: Array = z["zin"]
	var o := {
		"id": "hk_som", "kamer": "tuin", "hoog": plek["y"], "icoon": str(z["icoon"]),
		"regel": str(zin[0]), "pad": false, "klas": "af" if fase == "af" else "",
		"keuze_titel": "hoeveel sprongen?" if fase == "aantal" else "kies je sprong",
		"vlak": _kaart_vlak(),
	}
	if zin.size() > 1:
		o["regel2"] = str(zin[1])
	if not keuzes.is_empty():
		o["keuzes"] = keuzes
	# At the end there is no sum any more: "van 7 naar 7" is an empty statement,
	# and the card carries only "✅ Precies op de trap!" with a tick.
	_kaart = ctx.ui.somkaart(plek, "" if fase == "af" else _som_regel(), o)
	if fase == "af":
		_kaart.klaar()
	# the help ladder: only from the SECOND slip do we count along together
	if fase == "aantal" and int(_s["missers"]) >= 2 and not _krap():
		_kaart.hulp(Sommen.Hinkel.tel_pad(int(_s["s"]), int(_s["doel"]),
			int(_s["sprong"])))

func _teken() -> void:
	if not actief or _s.is_empty():
		return
	ctx.hotspots.wis_alles()
	# nothing of the turn while he walks to his stone (`_haal_gast`)
	if _wacht_loopt:
		ctx.wereld.vuil()
		return
	_teken_cijfers()
	_teken_kaart()
	ctx.wereld.vuil()
	if OS.has_feature("web"):
		_meld_probe()

## One machine-readable line per redraw, for the browser probe — the same kind
## of line `res://games/_voorbeeld/spel.gd` prints, and the only way a driver
## outside the engine can see which button is which.  The card and its strip are
## placed on the NEXT drawn frame, so the report waits a tick.  Web only: the
## headless suite reads the same facts straight off the objects.
func _meld_probe() -> void:
	if not await na(0.25) or _s.is_empty():
		return
	print("[probe] hk fase=", _s["fase"], " s=", _s["s"], " doel=", _s["doel"],
		" sprong=", _s["sprong"], " band=", _s["band"], " missers=", _s["missers"],
		" ster=", _s["ster"], " opsteen=", _op_start_steen())
	var kaart := Hits.spot("hk_som")
	if kaart != null and is_instance_valid(kaart.knoop):
		print("[probe] hk kaart=", (kaart.knoop as Control).get_global_rect(),
			" dekking=", "%.2f" % Hits.dekking("hk_som"))
	var strook := Hits.spot("hk_som_keuzes")
	if strook != null and is_instance_valid(strook.knoop):
		var rij: Node = strook.knoop.get_node_or_null("Rij")
		if rij != null:
			for b in rij.get_children():
				print("[probe] hk keuze ", b.name, "=", (b as Control).get_global_rect())

# =================================================================== spelen

func _kies_sprong(k: int) -> void:
	if _s.is_empty() or str(_s.get("fase", "")) != "sprong":
		return
	_s["sprong"] = k
	_s["n"] = _aantal_goed(k)
	_s["fase"] = "aantal"
	# `Snd.tik()` already sounded: every choice button of the strip plays it
	# (ui/keuzestrook.gd), so calling it again would be two ticks on one tap.
	State.bewaar()
	_teken()

func _antwoord(n: int) -> void:
	if _s.is_empty() or str(_s.get("fase", "")) != "aantal" or n < 1:
		return
	# The strip only stands there once the guest is on his stone; through the
	# test hook an answer can still arrive early.  Then we fetch him first and
	# the same question comes back when he is there (nothing counts, nothing
	# is lost).
	if not _op_start_steen():
		_haal_gast()
		return
	var goed := _aantal_goed(int(_s["sprong"]))
	_s["pogingen"] = int(_s["pogingen"]) + 1
	if n != goed:
		_s["missers"] = int(_s["missers"]) + 1
	ctx.state.tel(n == goed, Time.get_ticks_msec() - _t0)
	# ALSO on a wrong answer the animal hops the chosen number and the card asks
	# on from there (architecture.md §13 Q-X3-8: never punishing, no attempt cap)
	_hop(n)

## The animal hops stone by stone; every landing counts on its own tag and
## sounds `hup`.
func _hop(aantal: int) -> void:
	var g := _gast()
	if g.is_empty():
		return
	if not _op_start_steen():
		_haal_gast()
		return
	var id := str(g["id"])
	var m := _pad_maat()
	var r := _richting()
	var sprong := maxi(1, int(_s["sprong"]))
	var s0 := int(_s["s"])
	# never hop off the line: at most to 0 or to the last stone
	@warning_ignore("integer_division")
	var maxh := (int(_s["E"]) - s0) / sprong if r > 0 else s0 / sprong
	var hops := maxi(0, mini(aantal, maxh))
	if hops == 0:
		ctx.snd.zacht()                 # there is no stone to go to
		if _kaart != null:
			_kaart.hulp(Sommen.Hinkel.tel_pad(s0, int(_s["doel"]), sprong))
		return
	var punten: Array = []
	for i in range(1, hops + 1):
		punten.append(Vector2(_dier_x(float(s0 + r * sprong * i)), float(m["zDier"])))
	_s["fase"] = "hop"
	_s["hops"] = hops
	_s["tel"] = 0
	State.bewaar()
	_teken()
	_hop_nr += 1
	var mijn := _hop_nr
	var eind := s0 + r * sprong * hops
	# one last correction before the series: he is in the garden, but perhaps a
	# few voxels beside his stone
	if not await _loop_eerst(id, mijn):
		return
	var per := func(i: int, _punt) -> void:
		if not actief or _s.is_empty() or mijn != _hop_nr:
			return
		_s["tel"] = i + 1
		ctx.snd.hup()
		_zet_gast_getal(i + 1, "sprong %d" % (i + 1))
	var gehaald: bool = await ctx.wereld.stappen(id, punten,
		{"pose": "spring", "tempo": 1.25, "per_stap": per})
	if not actief or _s.is_empty() or mijn != _hop_nr:
		return
	if not gehaald:
		_s["fase"] = "sprong"           # overtaken: ask the hop size again
		_s["sprong"] = 0
		_teken()
		return
	_geland(eind)

func _loop_eerst(id: String, mijn: int) -> bool:
	var m := _pad_maat()
	var d = ctx.wereld.dier(id)
	if d == null or d.kamer != "tuin":
		_haal_gast()
		return false
	var doel_x := _dier_x(float(int(_s["s"])))
	if absf(d.x - doel_x) <= 2.5 and absf(d.z - float(m["zDier"])) <= 3.5:
		return true
	await ctx.wereld.loop_naar(id, doel_x, float(m["zDier"]), {"tempo": 1.4})
	return actief and not _s.is_empty() and mijn == _hop_nr

func _geland(pos: int) -> void:
	var r := _richting()
	var te_ver := (r > 0 and pos > int(_s["doel"])) or (r < 0 and pos < int(_s["doel"]))
	var doel := int(_s["doel"])
	_s["s"] = pos
	_s["tel"] = 0
	if pos == doel:
		_gelukt()
		return
	_s["sprong"] = 0
	_s["fase"] = "sprong"
	_s["melding"] = "ver" if te_ver else "kort"
	ctx.snd.zacht()
	State.bewaar()
	_teken()
	# a soft word at the animal — never a cross (HOTEL.md §9)
	var g := _gast()
	if g.is_empty():
		return
	var id := str(g["id"])
	var d = ctx.wereld.dier(id)
	ctx.ui.wolk({"id": "hk_zeg", "kamer": "tuin", "klas": "hulp" if te_ver else "",
		"icoon": "🙃" if te_ver else "🪨", "getal": pos,
		"tekst": "te ver" if te_ver else "nog verder", "hoog": 52.0, "prio": 9,
		"x": d.x if d != null else 0.0, "z": d.z if d != null else 0.0,
		"volg": _volg_dier(id, 52.0)})
	_zeg_straks()

func _zeg_straks() -> void:
	if not await na(ZEG_S):
		return
	ctx.ui.wolk_weg("hk_zeg")

func _gelukt() -> void:
	var g := _gast()
	_s["fase"] = "af"
	_s["sprong"] = 0
	ctx.snd.ja()
	_teken()
	if int(_s["ster"]) == 0:
		_s["ster"] = 1
		ctx.taak_klaar("hinkel", {"sterren": 1})
	if not g.is_empty() and str(g.get("behoefte", "")) == "spelen" \
			and not bool(g.get("blij", false)):
		ctx.wereld.behoefte_klaar(str(g["id"]), "spelen")
		_s["wens"] = 1
	State.bewaar()
	Hotel.render()
	_sluit_straks()
	if g.is_empty():
		return
	# The animal hops ONTO the staircase (a greater depth than the staircase
	# itself, so it is drawn in front of it and stands on top) and dances there.
	var id := str(g["id"])
	var m := _pad_maat()
	var doel := int(_s["doel"])
	_hop_nr += 1
	var mijn := _hop_nr
	var per := func(_i, _punt) -> void: ctx.snd.hup()
	var gehaald: bool = await ctx.wereld.stappen(id,
		[Vector2(_x_op_rij(float(doel), float(m["zTop"]), int(_s["band"])) + 1.0,
			float(m["zTop"]))],
		{"pose": "spring", "tempo": 1.1, "per_stap": per})
	if not actief or _s.is_empty() or mijn != _hop_nr:
		return
	if gehaald:
		ctx.wereld.pose(id, "blij", 60)
	ctx.snd.hoera()
	var d = ctx.wereld.dier(id)
	ctx.ui.wolk({"id": "hk_goed", "kamer": "tuin", "icoon": "⭐",
		"tekst": "op de trap", "klas": "goed", "hoog": 52.0, "prio": 12,
		"x": d.x if d != null else 0.0, "z": d.z if d != null else 0.0,
		"volg": _volg_dier(id, 52.0)})

func _sluit_straks() -> void:
	if not await na(EIND_S):
		return
	if _s.is_empty() or str(_s.get("fase", "")) != "af":
		return
	ctx.data().erase("stand")
	_s = {}
	ctx.sluit()

# =================================================================== testhaken
##
## The headless suite drives a turn through the ctx and the choice strip, never
## through these; they only let a test READ the turn and the measurements it
## cannot see from outside (games-b.md §3, "haakjes voor de speeltest").

func proef_stand() -> Dictionary:
	return _s.duplicate(true)

func proef_maten() -> Array[int]:
	return _maten() if not _s.is_empty() else [] as Array[int]

func proef_pad_maat() -> Dictionary:
	return _pad_maat()

func proef_dier_x(n: float) -> float:
	return _dier_x(n)

func proef_op_start_steen() -> bool:
	return _op_start_steen()

func proef_steen_getal(i: int, band: int) -> int:
	return _steen_getal(i, band)

func proef_rij_van_steen(i: int, band: int) -> int:
	return _rij_van_steen(i, band)

func proef_zinnen() -> Dictionary:
	return _zinnen()

func proef_x_op_rij(n: float, z0: float) -> float:
	return _x_op_rij(n, z0, int(_s.get("band", 3)))

func proef_pad_maat_van(band: int) -> Dictionary:
	return _pad_maat_van(band)

func proef_steen_plek(i: int, band: int) -> Dictionary:
	return _steen_plek(i, band)

func proef_trap_plek() -> Dictionary:
	return _trap_plek()
