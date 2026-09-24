class_name HotelPrikbord
extends RefCounted
## The task board (world.md §3.7).  Three cards at most, rebuilt whenever the
## fingerprint of everything a card depends on changes.
##
## Two rules that look small and are not:
##
## * **The fair rotation.** There are more games than the three places on the
##   board.  Every ORDINARY game chip (it has a `spel` and `prio >= LAAG`)
##   counts equally (`_bord_prio` clamps them to LAAG) and they shift one place
##   per day, so a chip with a low number cannot camp on the board forever
##   while another never appears.  Animal wishes (prio 0..4) keep their own
##   order and their own priority.  Ported as is from `hotel.js roteerSpel`
##   (architecture.md §13, Q-X3-14).
## * **The sort must be STABLE.**  The rotation only survives the sort because
##   equal priorities keep their order; `Array.sort_custom` is introsort and is
##   NOT stable, so the comparison carries the original index.  Without that
##   the whole rotation silently collapses back to "the same three every day".

const LAAG := 5           ## from this priority up, a game chip is "ordinary"
const PLEKKEN := 3        ## the board holds three cards
## The bell's card (world.md §7.7): the first guest, and then while some
## bedroom can take one more animal.
const BEL_EERST := "Bel een gast"
const BEL_PLEK := "Nog plek voor een gast"

var _sig := ""

## Everything a card depends on, as one string.  Changes -> rebuild.
func signatuur() -> String:
	var s: Dictionary = State.s
	var d := PackedStringArray([
		str(s["dag"]), str(s["ronde"]), str((s["gasten"] as Array).size()),
		str(s["munten"]), str((s["uitcheck"] as Array).size()),
		"1" if State.plek_voor_gast() else "0",
		"1" if s["nieuweGast"] != null else "0"])
	for q in Hotel.spel_taken():
		d.append("sp:%s:%s" % [q["id"], q["tekst"]])
	for g in s["gasten"]:
		d.append("%s:%s:%s:%d:%d" % [g.get("id", ""), _of(str(g.get("bed", ""))),
			g.get("behoefte", ""),
			1 if g.get("gegeten", false) else 0, 1 if g.get("blij", false) else 0])
	for b in Hotel.alle_bakken():
		d.append("%s.%s=%d" % [b["kamer"], b["slot"], int(b["niveau"])])
	return "|".join(d)

static func _of(v: String) -> String:
	return v if not v.is_empty() else "-"

## Rebuild today's board.  Returns `State.s["taken"]`.
func bouw(forceer := false) -> Array:
	var sig := signatuur()
	if not forceer and sig == _sig and not (State.s["taken"] as Array).is_empty():
		return State.s["taken"]
	_sig = sig
	var s: Dictionary = State.s
	var t: Array = []

	# ---- the hotel's own cards, all prio 0, in this order (world.md §3.7)
	var zonder_bed: Array = []
	for g in s["gasten"]:
		if str(g.get("bed", "")).is_empty():
			zonder_bed.append(g)
	var lege_bak := Hotel.lege_bakken()
	# Room for one more guest: a free bed, or floor where the check-in puts a
	# new bed down (owner, 2026-09-24).  "Nog een bed vrij" was the old rule.
	var plek := State.plek_voor_gast()
	if plek and (s["gasten"] as Array).is_empty():
		t.append(_kaart("bel", "🔔", BEL_EERST, "receptie", "bel"))
	elif plek:
		t.append(_kaart("bel", "🔔", BEL_PLEK, "receptie", "bel"))
	if not zonder_bed.is_empty():
		t.append(_kaart("bed", "🛏", "%s wil een bed" % zonder_bed[0]["naam"],
			"receptie", "bel"))
	if not lege_bak.is_empty():
		t.append(_kaart("voer", "🍪", "Vul de voerkar", "keuken", "game:voerkar"))
	if not (s["uitcheck"] as Array).is_empty():
		var g0 := State.gast_van(str(s["uitcheck"][0]))
		t.append(_kaart("uit", "💰", "Reken af: %s" % g0.get("naam", "gast"),
			"receptie", "avond"))
	var spelen: Array = []
	for g in s["gasten"]:
		if str(g.get("behoefte", "")) == "spelen" and not g.get("blij", false):
			spelen.append(g)
	if not spelen.is_empty():
		var kamer := str(spelen[0].get("kamer", ""))
		t.append(_kaart("spelen", "🧶", "%s wil spelen" % spelen[0]["naam"],
			kamer if not kamer.is_empty() else "kamer1", "kamer"))

	# ---- the game chips, in their turn for today
	var alles: Array = t + _roteer(Hotel.spel_taken())

	# ---- what was ticked today keeps its tick for the rest of the day, and a
	#      card that leaves the list while it was on the board is marked done
	#      instead of quietly vanishing (world.md §3.7).
	var vorige: Array = (s["taken"] as Array).duplicate()
	var af := {}
	for q in vorige:
		if q.get("klaar", false):
			af[str(q["id"])] = 1
	for q in vorige:
		var nog := false
		for a in alles:
			if str(a["id"]) == str(q["id"]):
				nog = true
				break
		if nog:
			continue
		q["klaar"] = true
		af[str(q["id"])] = 1
		alles.append(q)

	alles = _stabiel_op_prio(alles)
	var uit: Array = []
	for i in mini(PLEKKEN, alles.size()):
		var q: Dictionary = alles[i]
		q["klaar"] = af.has(str(q["id"]))
		uit.append(q)
	s["taken"] = uit
	return uit

func taak_af(id: String) -> bool:
	var raak := false
	for q in State.s["taken"]:
		if str(q.get("id", "")) == id or str(q.get("spel", "")) == id:
			q["klaar"] = true
			raak = true
	return raak

## What the three cards look like right now.  `Hotel.render()` compares this
## before and after a rebuild: a card whose TEXT changed (`Boef wil een bed` ->
## `Muis wil een bed`) must repaint too, not only one that appeared or was
## ticked, so counting the open cards is not enough.
func kaart_afdruk() -> String:
	var d := PackedStringArray()
	for q in State.s["taken"]:
		d.append("%s:%s:%d" % [q.get("id", ""), q.get("tekst", ""),
			1 if q.get("klaar", false) else 0])
	return "|".join(d)

## The badge on the prikbord hotspot: how many cards are still open.
func open_taken() -> int:
	var n := 0
	for q in State.s["taken"]:
		if not q.get("klaar", false):
			n += 1
	return n

func vergeet() -> void:
	_sig = ""

# ------------------------------------------------------------------ intern

static func _kaart(id: String, icoon: String, tekst: String, kamer: String,
		actie: String) -> Dictionary:
	return {"id": id, "spel": "", "icoon": icoon, "tekst": tekst,
			"kamer": kamer, "actie": actie, "prio": 0, "klaar": false}

static func _laag_taak(q: Dictionary) -> bool:
	return not str(q.get("spel", "")).is_empty() and int(q.get("prio", 0)) >= LAAG

static func _bord_prio(q: Dictionary) -> int:
	var p := int(q.get("prio", 0))
	return LAAG if p >= LAAG else p

## `roteerSpel`: day `d` starts the list of ordinary chips at `(d - 1) mod n`;
## the wish chips stay exactly where they are.
func _roteer(sp: Array) -> Array:
	var laag: Array = []
	for q in sp:
		if _laag_taak(q):
			laag.append(q)
	var n := laag.size()
	if n < 2:
		return sp
	var start := posmod(int(State.s["dag"]) - 1, n)
	var rij: Array = laag.slice(start) + laag.slice(0, start)
	var k := 0
	var uit: Array = []
	for q in sp:
		if _laag_taak(q):
			uit.append(rij[k])
			k += 1
		else:
			uit.append(q)
	return uit

## Stable sort on `_bord_prio`: the index breaks every tie, so the rotation
## order of the ordinary chips survives.
static func _stabiel_op_prio(lijst: Array) -> Array:
	var paren: Array = []
	for i in lijst.size():
		paren.append([_bord_prio(lijst[i]), i, lijst[i]])
	paren.sort_custom(func(a, b) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1])
	var uit: Array = []
	for p in paren:
		uit.append(p[2])
	return uit
