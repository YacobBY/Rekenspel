extends MiniGame
## tobbe — "Tobbe-tijd" (games-a.md §6, architecture.md §12.2 row `tobbe`).
##
## Op het erf staan de tobbes.  Uit het schuurrek (de kist) komen schepjes sop;
## die verdeel je eerlijk over de tobbes.  Daarna gaan de dieren met de wens 🛁
## erin en komen er blinkend uit.
##
## Wat de poort anders doet dan de HTML, en waarom (het ticket noemt dit een
## layout-vrijheid, architecture.md §1.2/§4.3):
##   * `hits.js` mat elke knop na en schoof hem weg; hier legt de bandenrooster
##     alles in één pas neer.  Alle plek-wiskunde van §6.4 (`inDeLucht`,
##     `voorRijDiepte`, `opGras`, `somHoog`, `somPast`, `somLift`) verdwijnt
##     daarmee: het gereedschap krijgt één mikpunt onder de tobbe-rij en het
##     rooster is de container die er een rij van maakt.  Geen breedtebudget
##     van 146 px meer, dus geen ingekorte zinnen.
##   * het peilglaasje op de knop was DOM-kunst omdat er in de HTML geen water
##     ín de wereld kon staan.  Hier staat het sop echt in de tobbe: een eigen
##     model `tobbe_sop` waarvan de waterhoogte de inhoud is (HOTEL.md §9,
##     "uitleggen door te laten zien").  Het cijfer óp de tobbe blijft.
##   * `setTimeout` wordt `await na()`, dus `stop()` ruimt elke wachttijd op.

const KAMER := "tuin"
## `Sommen.Tobbe.HAND` — hoeveel schepjes één tik uit het rek haalt.
const HAND: Array = [1, 2, 5]
const DIER_ICO := {"puppy": "🐶", "poes": "🐱", "konijn": "🐰", "gans": "🦆"}

## Het sop en de droge bodem van de tobbe (art-sound-rules.md §8 kleuren).
const SOP := Color("#A9D8E6")
const SOP_L := Color("#C7E7F1")
const DROOG := Color("#C39A72")

## Hoeveel voxels hoog de rand van een tobbe is; het sop loopt daar tegenaan.
const KUIP_HOOG := 6

## Het plankje vóór de tobbes: hoeveel echte pixels opzij elk stuk gereedschap
## mikt, zodat elk zijn eigen kolom in het bandenrooster houdt (zie
## `_gereedschap_punt`).  De sommenkaart staat in het midden op 0.
const GEREEDSCHAP := {"kan": -150.0, "hulp": -80.0, "klaar": 80.0, "kraan": 150.0}

## De stand van de beurt.  Leeft in `ctx.data()["stand"]` en overleeft dus een
## herlaad; awaits en timers doen dat nooit (architecture.md §6.2 regel 3).
var _s: Dictionary = {}
## De plekken van de tobbes, van links naar rechts op het scherm (`x - z`).
var _p: Array = []
var _kaart = null
var _probe := false

# =====================================================================
#  1. AANMELDEN
# =====================================================================

## `taak` staat er met opzet NIET in: `Hotel._bouw_spel_taak()` draagt het
## kaartje `bad` (prio 1, 🛁, "<naam> wil in bad" / "Tobbe-tijd") al, en een
## Callable in `definitie()` zou aan het weggegooide scan-exemplaar hangen —
## `Games.scan()` doet `proef.free()` zodra het de definitie gelezen heeft.
func definitie() -> Dictionary:
	return {
		"naam": "Tobbe-tijd",
		"kamer": KAMER,
		"hotspot": {"obj": "tobbe", "icoon": "🛁", "label": "Tobbe", "hoog": 12},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"wens": "bad",
		"stub": false,
	}

# =====================================================================
#  2. HET RECEPT EN DE STAND
# =====================================================================

## Meespelende gasten: iedereen met een bed (games-a.md §6.1).
func _gasten() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(g)
	return uit

## Wie in bad MOET; is die lijst leeg, dan mag iedereen.
func _badgasten() -> Array:
	var wil: Array = []
	for g in ctx.state.s["gasten"]:
		if str(g.get("behoefte", "")) == "bad" and not bool(g.get("blij", false)):
			wil.append(g)
	return wil if not wil.is_empty() else _gasten()

func _nieuwe_stand(n: int, band: int, dag: int) -> Dictionary:
	var r := Sommen.Tobbe.recept(n, band, dag)
	var soort := str(r["soort"])
	var m := int(r["M"])
	var t := int(r["T"])
	var tobbes: Array = []
	var inbad: Array = []
	for i in m:
		tobbes.append(0)
		inbad.append([])
	if soort == "half":
		tobbes[0] = t
	return {
		"dag": dag, "N": n, "band": int(r["band"]), "soort": soort,
		"n0": int(r["n0"]), "perDier": int(r["perDier"]), "basis": int(r["basis"]),
		"T": t, "M": m, "per": int(r["per"]), "rest": int(r["rest"]),
		# Elke ronde begint met rekenen (PLAN.md R1/R3, taak N4): ook `eerlijk`.
		# Het sop blijft daarbij staan waar het staat — op het rek bij `eerlijk`,
		# in de eerste tobbe bij `half` — want het antwoord opent de handeling,
		# het voert haar niet uit.
		"stap": "vraag",
		"rek": t if soort == "eerlijk" else (int(r["basis"]) if soort == "dubbel" else 0),
		"tob": tobbes, "kan": 0, "inbad": inbad, "hand": 1,
		"missers": 0, "lijn": 0, "hulp": 0, "wens": 0, "ster": 0,
		"mors": -1, "tel": 0, "zeg": {}, "t0": 0,
	}

## Een stand die uit de savegame komt is door JSON gegaan: elk getal is dan een
## float en elke lijst een gewone Array.  Zonder dit rekent `"3.0" + 1` verder
## en staat er "3.0 + 3.0 =" op de kaart.
func _normaliseer(st: Dictionary) -> Dictionary:
	for sleutel in ["dag", "N", "band", "n0", "perDier", "basis", "T", "M", "per",
			"rest", "rek", "kan", "hand", "missers", "lijn", "hulp", "wens",
			"ster", "mors", "tel", "t0"]:
		st[sleutel] = int(st.get(sleutel, 0))
	st["soort"] = str(st.get("soort", "eerlijk"))
	st["stap"] = str(st.get("stap", "vullen"))
	var tobbes: Array = []
	for v in st.get("tob", []):
		tobbes.append(int(v))
	while tobbes.size() < st["M"]:
		tobbes.append(0)
	st["tob"] = tobbes
	var inbad: Array = []
	for l in st.get("inbad", []):
		var rij: Array = []
		for id in l:
			rij.append(str(id))
		inbad.append(rij)
	while inbad.size() < st["M"]:
		inbad.append([])
	st["inbad"] = inbad
	if typeof(st.get("zeg", {})) != TYPE_DICTIONARY:
		st["zeg"] = {}
	return st

## Minder tobbes dan het recept vroeg: de som opnieuw verdelen.
func _herschaal(m: int) -> void:
	var r := Sommen.Tobbe.herschaal(int(_s["T"]), m)
	_s["M"] = int(r["M"])
	_s["per"] = int(r["per"])
	_s["rest"] = int(r["rest"])
	var tobbes: Array = (_s["tob"] as Array).slice(0, m)
	var inbad: Array = (_s["inbad"] as Array).slice(0, m)
	while tobbes.size() < m:
		tobbes.append(0)
		inbad.append([])
	_s["tob"] = tobbes
	_s["inbad"] = inbad

func _rand_van_de_tobbe() -> int:
	return int(_s["per"]) + 2

func _kan_nodig() -> bool:
	return int(_s["rest"]) > 0 or int(_s["band"]) >= 5

func _mv(n: int, enk: String, meerv: String) -> String:
	return Ui.meervoud(n, enk, meerv)

## Samen doortellen: `_tel_mee(6, 2)` -> "6 … 12."  (ui.js `telMee`; de motor
## heeft die helper nog niet — zie "Contract gaps" in het rapport.)
func _tel_mee(stap: int, aantal: int, staart := ".") -> String:
	var l := PackedStringArray()
	var som := 0
	for i in aantal:
		som += stap
		l.append(str(som))
	return " … ".join(l) + staart

# =====================================================================
#  3. TOBBES NEERZETTEN
# =====================================================================

## Een plekje voor een tobbe erbij: uit het vrije vloerraster van de tuin, zó
## gekozen dat de knoppen elkaar op het SCHERM niet afdekken (games-a.md §6.3).
func _kies_plek(gekozen: Array) -> Dictionary:
	var r := Rooms.get_kamer(KAMER)
	if r == null:
		return {}
	var beste := {}
	var beste_score := -INF
	for v in r.vrij:
		var vx := float(v["x"])
		var vz := float(v["z"])
		var ok := true
		var sep := INF
		var rij := 0.0
		for q in gekozen:
			var du: float = absf((vx - vz) - (float(q["x"]) - float(q["z"])))
			var dd: float = absf((vx + vz) - (float(q["x"]) + float(q["z"])))
			if du < 50.0 and dd < 46.0:
				ok = false
			sep = minf(sep, du)
			rij = maxf(rij, dd)
		if not ok:
			continue
		var score := -rij * 1.5 - absf(sep - 62.0) * 0.6
		if score > beste_score:
			beste_score = score
			beste = {"x": vx, "z": vz}
	return beste

## Het erf heeft één vaste tobbe; de rest zet het spel er zelf bij.  De ids
## staan in het eigen laatje (`d.kuipen`), zodat er na "Verder spelen" nooit een
## tweede rij bij komt.  Élke badkuip die in de tuin staat telt mee — ook eentje
## die het kind in het meubelboek kocht.
func _zorg_tobbes(m: int) -> Array:
	var uit: Array = []
	var vast := Rooms.slot(KAMER, "tobbe")
	if not vast.is_empty():
		uit.append({"x": float(vast["x"]), "z": float(vast["z"]), "id": "tobbe"})
	var d := ctx.data()
	if typeof(d.get("kuipen", null)) != TYPE_ARRAY:
		d["kuipen"] = []
	var kuipen: Array = d["kuipen"]
	for stuk in World.kamer_meubels(KAMER):
		var id := str(stuk.get("id", ""))
		if str(stuk.get("type", "")) == "badkuip" or kuipen.has(id):
			uit.append({"x": float(stuk["x"]), "z": float(stuk["z"]), "id": id})
	while uit.size() < m:
		var plek := _kies_plek(uit)
		if plek.is_empty():
			break
		var stuk := World.plaats_meubel(KAMER, "badkuip", plek["x"], plek["z"])
		if stuk.is_empty():
			break
		var id := str(stuk.get("meubel", stuk.get("id", "")))
		if not kuipen.has(id):
			kuipen.append(id)
		uit.append({"x": float(stuk["x"]), "z": float(stuk["z"]), "id": id})
	uit.sort_custom(func(a, b) -> bool:
		return (float(a["x"]) - float(a["z"])) < (float(b["x"]) - float(b["z"])))
	return uit.slice(0, m)

# =====================================================================
#  4. PLEKKEN — alles hangt aan de tobbe-rij
# =====================================================================

func _rij_u() -> float:
	var u := 0.0
	for p in _p:
		u += float(p["x"]) - float(p["z"])
	return u / maxf(1.0, float(_p.size()))

func _rij_d() -> float:
	var d := 0.0
	for p in _p:
		d += float(p["x"]) + float(p["z"])
	return d / maxf(1.0, float(_p.size()))

## Het midden van de tobbe-rij: daar mikken de wolkjes en het gereedschap op.
func _rij_punt() -> Dictionary:
	var u := _rij_u()
	var d := _rij_d()
	return {"kamer": KAMER, "x": (d + u) * 0.5, "z": (d - u) * 0.5}

## Vóór de rij, op het gras: daar hangt de sommenkaart.  26 voxels diepte is
## ruim een tobbe-plaat, dus de kaart raakt de rij nooit, op elke schaal.
func _voor_punt() -> Dictionary:
	return _gereedschap_punt(0.0)

## Het plankje vóór de tobbes, met een VASTE plek per stuk gereedschap.
##
## Dit is de "container" van het ticket.  Mikten kraantje, kannetje, ✓, ↩ en Els
## allemaal op hetzelfde punt, dan deelde het bandenrooster de vrije blokken in
## de volgorde uit waarin het ze tegenkwam — en die volgorde verandert zodra er
## een knop bij komt of weggaat (↩ verschijnt na het eerste schepje, het wolkje
## komt en gaat).  Gemeten in de browser sprong de ✓ zo over vier banden en 280
## px heen tussen twee tekenbeurten: een kind tikt dan mis.  Elk stuk krijgt nu
## zijn eigen mikpunt op het plankje, in ECHTE pixels opzij (een vingerafstand,
## geen wereldafstand — architecture.md §13 Q-X4-11), en houdt daarmee zijn
## kolom.  `obj: "tobbe"` erbij maakt ook de band vast: het rooster hangt ze
## onder de tobbe in plaats van onder het eerste voorwerp dat het in de buurt
## van het mikpunt vindt (een graspol, en die wisselt per tekenbeurt mee met
## `World.decor_versie()`).
func _gereedschap_punt(u_px: float) -> Dictionary:
	var per_x: float = maxf(0.5, float(World.schaal()["pxPerVoxelX"]))
	var u := _rij_u() + u_px / per_x
	var d := 0.0
	for p in _p:
		d = maxf(d, float(p["x"]) + float(p["z"]))
	d += 26.0
	return {"kamer": KAMER, "x": (d + u) * 0.5, "z": (d - u) * 0.5}

## Hoe hoog boven de tobbe de knop hangt (games-a.md §6.4: 52 echte pixels).
func _kuip_hoog() -> float:
	return maxf(1.0, roundf(52.0 / maxf(1.0, World.px_per_hoogte())))

func _volg_tobbe(i: int) -> Callable:
	return func() -> Dictionary:
		if i >= _p.size():
			return {}
		var px := float(_p[i]["x"])
		var pz := float(_p[i]["z"])
		return {"x": px, "z": pz, "kamer": KAMER,
			"vlak": World.vlak_van("tobbe", px, pz, 0.0)}

func _volg_kist() -> Callable:
	return func() -> Dictionary:
		var k := World.mik("kist", KAMER)
		if k.is_empty():
			return {}
		var kx := float(k["x"])
		var kz := float(k["z"])
		return {"x": kx, "z": kz, "kamer": KAMER,
			"vlak": World.vlak_van("kist", kx, kz, 0.0)}

# =====================================================================
#  5. START / STOP
# =====================================================================

func start(_c: SpelCtx) -> void:
	_probe = _probe_aan()
	_kaart = null
	Art.registreer_model("tobbe_sop", _sop_voxels)
	var gasten := _gasten()
	if gasten.is_empty():
		_meld_en_sluit("🛏", "nog geen gasten")
		return
	var d := ctx.data()
	var n := gasten.size()
	var band: int = ctx.state.band()
	var dag := int(ctx.state.s["dag"])
	var oud = d.get("stand", null)
	if typeof(oud) == TYPE_DICTIONARY and not (oud as Dictionary).is_empty():
		_s = _normaliseer((oud as Dictionary).duplicate(true))
	else:
		_s = {}
	if _s.is_empty() or int(_s.get("T", 0)) == 0 or str(_s.get("stap", "")) == "af" \
			or int(_s.get("dag", 0)) != dag or int(_s.get("N", 0)) != n \
			or int(_s.get("band", 0)) != band:
		_s = _nieuwe_stand(n, band, dag)
	d["stand"] = _s
	_s["t0"] = Time.get_ticks_msec()
	_p = _zorg_tobbes(int(_s["M"]))
	if _p.size() < 2:
		_meld_en_sluit("🛁", "geen plek")
		return
	if _p.size() < int(_s["M"]):
		_herschaal(_p.size())
	_bewaar()
	_teken()
	if str(_s["stap"]) == "baden":
		_bubbels()

## Zeepbellen boven wie in bad zit, zolang de badstap duurt (review plan
## pijler 4).  Eén lus tegelijk; `na()` stopt hem met het spel.
var _bubbelt := false
func _bubbels() -> void:
	if _bubbelt:
		return
	_bubbelt = true
	while actief and not _s.is_empty() and str(_s["stap"]) == "baden":
		for id in _in_bad_ids():
			var d := World.dier(str(id))
			if d != null and d.kamer == KAMER:
				ctx.wereld.spetter(KAMER, d.x, d.z, 1, ArtEffect.ZEEP_KL, true, 7.0)
		if not await na(0.45):
			break
	_bubbelt = false

## Geen gasten of geen plek: één wolkje, en na 1800 ms sluit het spel.
func _meld_en_sluit(icoon: String, tekst: String) -> void:
	var t := World.mik("tobbe", KAMER)
	ctx.ui.wolk({"id": "tb_leeg", "kamer": KAMER,
		"x": float(t.get("x", 32)), "z": float(t.get("z", 94)), "hoog": 20.0,
		"icoon": icoon, "tekst": tekst, "prio": 12})
	if not await na(1.8):
		return
	ctx.ui.wolk_weg("tb_leeg")
	ctx.sluit()

func stop() -> void:
	if ctx != null:
		if not _s.is_empty():
			ctx.data()["stand"] = _s
			ctx.state.bewaar()
		World.decor_wis_eigenaar(ctx.id)
		ctx.hotspots.laat()
	_s = {}
	_p = []
	_kaart = null

func _bewaar() -> void:
	if ctx == null or _s.is_empty():
		return
	ctx.data()["stand"] = _s
	ctx.state.bewaar()

## De ster (en het vinkje op het prikbord) hoort bij de HELE ronde: het rekenen
## plus het baden.  Hij valt hooguit één keer per ronde (games-a.md §6.5 D/F).
func _ster() -> bool:
	if _s.is_empty() or int(_s["ster"]) != 0:
		return false
	_s["ster"] = 1
	ctx.taak_klaar("bad", {"sterren": 1})
	return true

# =====================================================================
#  6. HET EIGEN MODEL: het sop in de tobbe
# =====================================================================

## Het water ín de tobbe, zo hoog als er sop in zit.  De ingebouwde `tobbe`
## tekent altijd een halfvolle kuip; dit plaatje ligt er precies overheen en
## vult de binnenkant opnieuw: droge bodem tot waar het sop komt, sop daarboven.
func _sop_voxels(params: Dictionary) -> Array:
	var n := int(params.get("n", 0))
	var cap := maxi(1, int(params.get("cap", 3)))
	var h := clampi(JsGetal.rond(float(KUIP_HOOG) * float(n) / float(cap)), 0, KUIP_HOOG)
	if n > 0:
		h = maxi(1, h)
	var v: Array = []
	for x in range(-5, 6):
		for z in range(-5, 6):
			if x * x + z * z > 15:
				continue
			for y in maxi(4, h):
				var kleur := DROOG
				if y < h:
					kleur = SOP_L if y == h - 1 else SOP
				v.append({"x": x, "y": y, "z": z, "k": kleur})
	return v

func _sop_bij() -> void:
	var vol := str(_s["stap"]) == "baden" or str(_s["stap"]) == "af"
	var cap := maxi(_rand_van_de_tobbe(), 3)
	for i in _p.size():
		var n: int = int(_s["per"]) if vol else int(_s["tob"][i])
		World.decor(KAMER, {
			"id": "tb_sop%d" % i, "model": "tobbe_sop", "door": ctx.id,
			"x": float(_p[i]["x"]), "z": float(_p[i]["z"]), "hoog": 0.0,
			"params": {"n": n, "cap": cap},
		})

# =====================================================================
#  7. TEKENEN — alles hangt aan een voorwerp in de tuin
# =====================================================================

func _teken() -> void:
	if ctx == null or not actief or _s.is_empty() or _p.is_empty():
		return
	ctx.hotspots.wis_alles()
	_sop_bij()
	var stap := str(_s["stap"])
	if stap == "baden" or stap == "af":
		_teken_baden()
		World.vuil()
		_meld()
		return
	_teken_tobbes()
	_teken_rek()
	if stap == "vraag":
		_teken_vraag()
		World.vuil()
		_meld()
		return
	_teken_som()
	_teken_kraan()
	if _kan_nodig():
		_teken_kan()
	# één korte regel: het recept van vandaag, zolang er nog niets staat
	if int(_s["rek"]) == int(_s["T"]) and int(_s["missers"]) == 0:
		var k := World.mik("kist", KAMER)
		ctx.ui.wolk({"id": "tb_recept", "kamer": KAMER,
			"x": float(k.get("x", _rij_punt()["x"])), "z": float(k.get("z", _rij_punt()["z"])),
			"hoog": 26.0, "icoon": "🧴", "getal": int(_s["T"]),
			"tekst": _mv(int(_s["M"]), "tobbe", "tobbes"), "prio": 9})
	var klaar := _gereedschap_punt(GEREEDSCHAP["klaar"])
	ctx.hotspots.maak({
		"id": "tb_klaar", "kamer": KAMER, "x": klaar["x"], "z": klaar["z"], "y": 0.0,
		"op": "onder", "obj": "tobbe", "icoon": "✓", "label": "klaar", "prio": 13,
		"titel": "zo is het goed", "aan": func(_spot) -> void: _check()})
	var hulp := _gereedschap_punt(GEREEDSCHAP["hulp"])
	if int(_s["missers"]) >= 2:
		ctx.hotspots.maak({
			"id": "tb_els", "kamer": KAMER, "x": hulp["x"], "z": hulp["z"], "y": 0.0,
			"op": "onder", "obj": "tobbe", "icoon": "🩺", "label": "Els", "prio": 8,
			"titel": "buurvrouw Els doet het voor", "aan": func(_spot) -> void: _hulp()})
	elif int(_s["rek"]) < int(_s["T"]) or _iets_in_de_tobbes():
		ctx.hotspots.maak({
			"id": "tb_opnieuw", "kamer": KAMER, "x": hulp["x"], "z": hulp["z"], "y": 0.0,
			"op": "onder", "obj": "tobbe", "icoon": "🔄", "label": "opnieuw", "prio": 7,
			"titel": "opnieuw beginnen", "aan": func(_spot) -> void: _leeg()})
	if int(_s["hulp"]) != 0:
		_spook_neer()
	_teken_zeg()
	World.vuil()
	_meld()

func _iets_in_de_tobbes() -> bool:
	for n in _s["tob"]:
		if int(n) > 0:
			return true
	return false

func _teken_tobbes() -> void:
	var vol := str(_s["stap"]) == "baden" or str(_s["stap"]) == "af"
	for i in _p.size():
		var n: int = int(_s["per"]) if vol else int(_s["tob"][i])
		var mors := int(_s["mors"]) == i
		var titel := "tobbe %d: %d" % [i + 1, n]
		if int(_s["lijn"]) != 0:
			titel += " van %d" % int(_s["per"])
		var beestjes := ""
		if vol:
			for id in _s["inbad"][i]:
				beestjes += _ico(ctx.state.gast_van(str(id)))
		ctx.hotspots.maak({
			"id": "tb_kuip%d" % i, "kamer": KAMER,
			"x": float(_p[i]["x"]), "z": float(_p[i]["z"]), "y": _kuip_hoog(),
			"kind": "drop", "drop": "tobbe", "data": {"tob": i},
			"val": func(lading: Dictionary, data: Dictionary) -> void: _val(lading, data),
			"icoon": "💦" if mors else "🫧",
			"label": ("%d %s" % [n, beestjes]).strip_edges(),
			"klas": "hotkar", "prio": 12, "titel": titel,
			"volg": _volg_tobbe(i),
			"aan": func(_spot) -> void: _tik_tobbe(i)})
		# het aantal als cijfer ÓP de tobbe; tijdens de hulp van Els liggen daar
		# de spookcijfers, en twee getallen op één tobbe leest niemand
		if int(_s["hulp"]) == 0:
			ctx.ui.getal_tag({"x": float(_p[i]["x"]), "z": float(_p[i]["z"])}, n,
				{"id": "tb_n%d" % i, "kamer": KAMER, "y": 0.0,
				"titel": "schepjes in tobbe %d" % (i + 1), "volg": _volg_tobbe(i)})
		else:
			ctx.ui.getal_tag({"x": 0.0, "z": 0.0}, null, {"id": "tb_n%d" % i})

func _teken_rek() -> void:
	var kist := World.mik("kist", KAMER)
	if kist.is_empty():
		return
	var rek := int(_s["rek"])
	ctx.hotspots.bron({"x": float(kist["x"]), "z": float(kist["z"])}, {
		"id": "tb_rek", "kamer": KAMER, "icoon": "🧴", "hoog": 14.0,
		# prio 11 in plaats van 10: zonder het rek is er geen sop en dus geen
		# beurt, dus het rek gaat vóór het kraantje en vóór Els (zie het kannetje)
		"aantal": rek, "hand": int(_s["hand"]) if rek > 0 else 0, "prio": 11,
		"titel": "rek met %s, pak %d" % [_mv(rek, "schepje", "schepjes"), int(_s["hand"])],
		"tik": func(_spot) -> void: _wissel_hand(),
		"sleep": "tobbe", "data": {"wat": "schep"},
		"volg": _volg_kist()})

func _teken_som() -> void:
	# het kannetje hoort in de som mee, anders zou er "4 + 4 = 9" staan
	var delen: Array = (_s["tob"] as Array).duplicate()
	if _kan_nodig():
		delen.append(int(_s["kan"]))
	var stukken := PackedStringArray()
	var totaal := 0
	for v in delen:
		stukken.append(str(int(v)))
		totaal += int(v)
	var af := str(_s["stap"]) != "vullen" and str(_s["stap"]) != "vraag"
	var punt := _voor_punt()
	_kaart = ctx.ui.somkaart(punt, " + ".join(stukken) + " =", {
		"id": "tb_som", "kamer": KAMER, "hoog": 0.0, "pad": false, "icoon": "🧴",
		"regel": ("Overal %d erin" % int(_s["per"])) if af
			else ("%d in %s" % [int(_s["T"]), _mv(int(_s["M"]), "tobbe", "tobbes")]),
		"regel2": "Zo is het goed!" if af else "Verdeel het eerlijk",
		"titel": "de som van de tobbes"})
	if _kaart != null:
		_kaart.zet(str(totaal))

func _teken_kraan() -> void:
	var plek := _gereedschap_punt(GEREEDSCHAP["kraan"])
	ctx.hotspots.maak({
		"id": "tb_kraan", "kamer": KAMER, "x": plek["x"], "z": plek["z"], "y": 0.0,
		"op": "onder", "obj": "tobbe", "icoon": "🚰", "label": "halveren", "prio": 9,
		"titel": "splitskraantje: halveren", "aan": func(_spot) -> void: _kraantje()})

func _teken_kan() -> void:
	var plek := _gereedschap_punt(GEREEDSCHAP["kan"])
	ctx.hotspots.maak({
		"id": "tb_kan", "kamer": KAMER, "x": plek["x"], "z": plek["z"], "y": 0.0,
		"op": "onder", "obj": "tobbe", "icoon": "🫗", "label": str(int(_s["kan"])),
		"kind": "drop", "drop": "tobbe", "data": {"tob": "kan"},
		"val": func(lading: Dictionary, data: Dictionary) -> void: _val(lading, data),
		# prio 12, niet de 9 van games-a.md §6.4: het kannetje draagt bij een rest
		# een DEEL VAN DE SOM, net als een tobbe. Gemeten in de browser (band 5,
		# zeven gasten in de tuin): de naamplaatjes zijn `vast` en nemen zeven van
		# de zestien plekken per kamer, waarna het kannetje als eerste wegviel en
		# het kind de som niet meer kón afmaken.
		"prio": 12, "titel": "kannetje: %d" % int(_s["kan"]),
		"aan": func(_spot) -> void: _schep("kan", int(_s["hand"]))})

## Eén vaste boodschapplek boven de tobbes: het kind weet waar het praatje komt.
func _teken_zeg() -> void:
	var z: Dictionary = _s.get("zeg", {})
	if z.is_empty():
		return
	var rij := _rij_punt()
	ctx.ui.wolk({"id": "tb_zeg", "kamer": KAMER, "x": rij["x"], "z": rij["z"],
		"hoog": 34.0, "icoon": str(z.get("icoon", "")),
		"getal": z.get("getal", null), "tekst": str(z.get("tekst", "")),
		"klas": str(z.get("klas", "hulp")), "prio": 11})

func _zeg(o) -> void:
	_s["zeg"] = o if typeof(o) == TYPE_DICTIONARY else {}

func _ico(g: Dictionary) -> String:
	return str(DIER_ICO.get(str(g.get("soort", "")), "🐾"))

# =====================================================================
#  8. DE VRAAGSTAP — waar elke ronde begint
# =====================================================================

func _teken_vraag() -> void:
	var kist := World.mik("kist", KAMER)
	var rij := _rij_punt()
	var basis := int(_s["basis"])
	var t := int(_s["T"])
	var m := int(_s["M"])
	var per := int(_s["per"])
	var rest := int(_s["rest"])
	if str(_s["soort"]) == "dubbel":
		ctx.ui.wolk({"id": "tb_recept", "kamer": KAMER,
			"x": float(kist.get("x", rij["x"])), "z": float(kist.get("z", rij["z"])),
			"hoog": 26.0, "icoon": "🧴", "getal": basis,
			"tekst": "morgen dubbel", "prio": 9})
		_kaart = ctx.ui.somkaart(rij, "%d + %d =" % [basis, basis], {
			"id": "tb_vraag", "kamer": KAMER, "hoog": 34.0, "max": 2,
			"goed": int(_s["T"]), "liever": [basis, basis + 1, int(_s["T"]) + 1],
			"icoon": "🧴", "regel": "Morgen twee keer %d" % basis,
			"regel2": "Hoeveel samen?", "titel": "de dubbele som",
			"on_ok": func(n, k) -> void: _antwoord(n, int(_s["T"]), k)})
	elif str(_s["soort"]) == "half":
		ctx.ui.wolk({"id": "tb_recept", "kamer": KAMER, "x": rij["x"], "z": rij["z"],
			"hoog": 26.0, "icoon": "🚰", "getal": t,
			"tekst": "in twee helften", "prio": 9})
		# Bij een ONEVEN aantal is "de helft van 9" niet 4: er blijft een schepje
		# over (band 5).  Dan zegt de zin dat ook, anders staat er een leesbare
		# leugen boven de som.
		_kaart = ctx.ui.somkaart(rij, "helft van %d =" % t, {
			"id": "tb_vraag", "kamer": KAMER, "hoog": 34.0, "max": 2,
			"goed": int(_s["per"]), "liever": [t, rest, int(_s["per"]) + 1],
			"icoon": "🚰",
			"regel": ("%d halveren, %d over" % [t, rest]) if rest > 0
				else ("De helft van %s" % _mv(t, "schepje", "schepjes")),
			"regel2": "Hoeveel in elke helft?", "titel": "de helft van het sop",
			"on_ok": func(n, k) -> void: _antwoord(n, int(_s["per"]), k)})
	else:
		# `eerlijk` — de deelsom staat er vóór het eerste schepje.  Twee tobbes
		# krijgen "de helft van T" (groep 3 kent het deelteken nog niet, zie
		# IDEAS.md), drie tobbes het echte deelteken; drie tobbes komt alleen op
		# band 5 voor (`Sommen.Tobbe.recept`: M = 3 vanaf band 5).
		_kaart = ctx.ui.somkaart(rij,
			("helft van %d =" % t) if m == 2 else ("%d : %d =" % [t, m]), {
			"id": "tb_vraag", "kamer": KAMER, "hoog": 34.0, "max": 2,
			"goed": per, "liever": [t, per + 1, rest],
			"icoon": "🧴", "regel": "%d schepjes, %d tobbes" % [t, m],
			"regel2": "Hoeveel in elke tobbe?", "titel": "de som van het sop",
			"on_ok": func(n, k) -> void: _antwoord(n, int(_s["per"]), k)})
	_teken_zeg()

func _antwoord(n, goed: int, k) -> void:
	if n == null or _s.is_empty():
		return
	if int(n) != goed:
		_s["missers"] = int(_s["missers"]) + 1
		_s["lijn"] = 1
		ctx.snd.zacht()
		k.zet("")
		# samen doortellen: net zoveel sprongen als er tobbes zijn
		var staart := (" … en %d over." % int(_s["rest"])) if int(_s["rest"]) > 0 else "."
		k.hulp(_tel_mee(int(_s["basis"]), 2) if str(_s["soort"]) == "dubbel"
			else _tel_mee(goed, int(_s["M"]), staart))
		_bewaar()
		return
	k.zet(str(int(n)))
	k.klaar()
	ctx.snd.ja()
	# Het goede antwoord OPENT het verdelen, het doet het niet voor (taak N4):
	# bij `dubbel` ligt er vanaf nu twee keer zoveel op het rek, bij `eerlijk`
	# staat alles nog op het rek en bij `half` staat alles nog in de eerste
	# tobbe — halveren doet het kind zelf met 🚰 of door over te gieten.
	if str(_s["soort"]) == "dubbel":
		_s["rek"] = int(_s["T"])
	_s["stap"] = "vullen"
	_s["lijn"] = 1
	_bewaar()
	if not await na(0.65):
		return
	_teken()

# =====================================================================
#  9. SCHEPPEN, GIETEN, KRAANTJE
# =====================================================================

func _wissel_hand() -> void:
	if _s.is_empty():
		return
	_s["hand"] = HAND[(HAND.find(int(_s["hand"])) + 1) % HAND.size()]
	ctx.snd.tik()
	_teken()

## Het sleepdoel van een tobbe of het kannetje.
func _val(lading: Dictionary, data: Dictionary) -> void:
	if _s.is_empty():
		return
	if str(lading.get("wat", "")) == "dier":
		_in_bad(str(lading.get("id", "")), data.get("tob", null))
		return
	_schep(data.get("tob", null), int(_s["hand"]))

func _schep(doel, k: int) -> void:
	if _s.is_empty() or str(_s["stap"]) != "vullen" or doel == null:
		return
	k = mini(maxi(1, k), int(_s["rek"]))
	if k <= 0:
		ctx.snd.zacht()
		_zeg({"icoon": "🧴", "getal": 0, "tekst": "rek is leeg"})
		_teken()
		return
	_s["mors"] = -1
	_zeg(null)
	_s["rek"] = int(_s["rek"]) - k
	if typeof(doel) == TYPE_STRING and str(doel) == "kan":
		_s["kan"] = int(_s["kan"]) + k
		ctx.snd.plop(1)
	else:
		var i := int(doel)
		if i < 0 or i >= int(_s["M"]):
			_s["rek"] = int(_s["rek"]) + k
			return
		_s["tob"][i] = int(_s["tob"][i]) + k
		ctx.snd.plop(int(_s["hand"]))
		if int(_s["tob"][i]) > _rand_van_de_tobbe():
			_overloop(i)
			return
	_bewaar()
	_teken()

## Tikken op een tobbe terwijl het rek leeg is: dan giet je van deze tobbe over
## naar de leegste — zo kun je ook zonder kraantje eerlijk verdelen.
func _giet(i: int) -> void:
	var doel := -1
	for j in int(_s["M"]):
		if j != i and (doel < 0 or int(_s["tob"][j]) < int(_s["tob"][doel])):
			doel = j
	if doel < 0 or int(_s["tob"][i]) <= 0:
		ctx.snd.zacht()
		return
	var k: int = mini(int(_s["hand"]), int(_s["tob"][i]))
	_s["tob"][i] = int(_s["tob"][i]) - k
	_s["tob"][doel] = int(_s["tob"][doel]) + k
	_s["mors"] = -1
	_zeg(null)
	ctx.snd.plop(1)
	if int(_s["tob"][doel]) > _rand_van_de_tobbe():
		_overloop(doel)
		return
	_bewaar()
	_teken()

func _tik_tobbe(i: int) -> void:
	if _s.is_empty():
		return
	if str(_s["stap"]) == "baden":
		_volgende_in_bad(i)
		return
	if str(_s["stap"]) != "vullen":
		return
	if int(_s["rek"]) > 0:
		_schep(i, int(_s["hand"]))
	else:
		_giet(i)

## Het splitskraantje: de volste tobbe wordt gehalveerd naar de leegste.
func _kraantje() -> void:
	if _s.is_empty() or str(_s["stap"]) != "vullen":
		return
	var bron := 0
	for i in range(1, int(_s["M"])):
		if int(_s["tob"][i]) > int(_s["tob"][bron]):
			bron = i
	var doel := -1
	for i in int(_s["M"]):
		if i != bron and (doel < 0 or int(_s["tob"][i]) < int(_s["tob"][doel])):
			doel = i
	if doel < 0 or int(_s["tob"][bron]) < 2:
		ctx.snd.zacht()
		_zeg({"icoon": "🚰", "tekst": "eerst sop erin"})
		_teken()
		return
	var m := int(_s["tob"][bron])
	@warning_ignore("integer_division")
	var h := m / 2
	var r := m - 2 * h
	if r != 0 and int(_s["band"]) < 5:
		# even/oneven, groep 3: halveren mag hier niet met een rest
		_s["lijn"] = 1
		ctx.snd.zacht()
		_zeg({"icoon": "⚖️", "getal": m, "tekst": "is oneven"})
		_teken()
		return
	_s["tob"][bron] = h
	_s["tob"][doel] = int(_s["tob"][doel]) + h
	_s["kan"] = int(_s["kan"]) + r
	_s["mors"] = -1
	ctx.snd.plop(2)
	if r != 0:
		_zeg({"icoon": "🫗", "getal": r, "tekst": "blijft over", "klas": ""})
	else:
		_zeg({"icoon": "🚰", "getal": h, "tekst": "en %d" % h, "klas": "goed"})
	_bewaar()
	_teken()
	if int(_s["tob"][bron]) > _rand_van_de_tobbe():
		_overloop(bron)

func _leeg() -> void:
	if _s.is_empty():
		return
	for i in int(_s["M"]):
		_s["tob"][i] = 0
	_s["kan"] = 0
	_s["rek"] = int(_s["T"])
	if str(_s["soort"]) == "half":
		_s["tob"][0] = int(_s["T"])
		_s["rek"] = 0
	_s["mors"] = -1
	_s["hulp"] = 0
	_zeg(null)
	_spook_weg()
	ctx.snd.terug()
	_bewaar()
	_teken()

# =====================================================================
#  10. DE VRIENDELIJKE CONTROLE — nooit een kruis
# =====================================================================

## Te vol: het sop gaat terug op het rek en de dieren liggen dubbel.  Er komt
## nooit een kruis (architecture.md §1.1 F5).
func _overloop(i: int) -> void:
	_s["rek"] = int(_s["rek"]) + int(_s["tob"][i])
	_s["tob"][i] = 0
	_s["missers"] = int(_s["missers"]) + 1
	_s["lijn"] = 1
	_s["mors"] = i
	ctx.snd.zacht()
	_zeg({"icoon": "🦆", "tekst": "te vol"})
	for g in ctx.state.s["gasten"]:
		if str(g.get("waar", "")) == KAMER:
			World.mood(str(g["id"]), "bouncy")
	_bewaar()
	_teken()
	if not await na(1.4):
		return
	if _s.is_empty() or int(_s["mors"]) != i:
		return
	_s["mors"] = -1
	_teken()

func _check() -> void:
	if _s.is_empty() or str(_s["stap"]) != "vullen":
		return
	if int(_s["rek"]) > 0:
		_mis({"icoon": "🥄", "getal": int(_s["rek"]), "tekst": "nog op het rek"})
		return
	for i in int(_s["M"]):
		if int(_s["tob"][i]) > int(_s["per"]):
			_overloop(i)
			return
	var gelijk := true
	for i in range(1, int(_s["M"])):
		if int(_s["tob"][i]) != int(_s["tob"][0]):
			gelijk = false
	if not gelijk:
		_mis({"icoon": "⚖️", "tekst": "even hoog"})
		return
	if int(_s["kan"]) != int(_s["rest"]):
		_mis({"icoon": "🫗", "getal": int(_s["rest"]), "tekst": "hoort hierin"})
		return
	if int(_s["tob"][0]) != int(_s["per"]):
		_mis({"icoon": "🥄", "getal": int(_s["per"]) - int(_s["tob"][0]), "tekst": "erbij"})
		return
	_geslaagd()

func _mis(o: Dictionary) -> void:
	_s["missers"] = int(_s["missers"]) + 1
	_s["lijn"] = 1
	_s["mors"] = -1
	ctx.snd.zacht()
	_zeg(o)
	_bewaar()
	_teken()

func _geslaagd() -> void:
	_s["stap"] = "baden"
	_s["lijn"] = 1
	_s["mors"] = -1
	_s["tel"] = 0
	_zeg(null)
	_spook_weg()
	# het water is klaar: wie in bad moet komt er zelf aan lopen
	var p0: Dictionary = _p[0]
	for g in _moet_nog_in_bad():
		var d := World.dier(str(g["id"]))
		if d != null and d.kamer == KAMER:
			continue
		World.reis(str(g["id"]), KAMER, {"x": maxf(12.0, float(p0["x"]) - 16.0),
			"z": float(p0["z"]), "na": "wacht"})
		g["waar"] = KAMER
	# Het adaptieve signaal telt hier al mee; de STER hoort bij de hele ronde en
	# valt pas als de gasten gebaad hebben — anders krijgt één ronde twee sterren.
	ctx.state.tel(int(_s["missers"]) == 0, Time.get_ticks_msec() - int(_s["t0"]))
	ctx.snd.tover()
	_bewaar()
	_teken()
	_bubbels()
	var rij := _rij_punt()
	ctx.ui.wolk({"id": "tb_goed", "kamer": KAMER, "x": rij["x"], "z": rij["z"],
		"hoog": 34.0, "icoon": "✅", "getal": int(_s["per"]), "tekst": "even hoog",
		"klas": "goed", "prio": 12})
	if not await na(2.2):
		return
	ctx.ui.wolk_weg("tb_goed")

# ---------- Els doet het voor: de goede aantallen als spookcijfers ----------

func _spook_weg() -> void:
	if ctx == null:
		return
	for i in _p.size():
		ctx.ui.getal_tag({"x": 0.0, "z": 0.0}, null, {"id": "tb_s%d" % i})
	ctx.ui.getal_tag({"x": 0.0, "z": 0.0}, null, {"id": "tb_sk"})

func _spook_neer() -> void:
	for i in _p.size():
		ctx.ui.getal_tag({"x": float(_p[i]["x"]), "z": float(_p[i]["z"])}, int(_s["per"]),
			{"id": "tb_s%d" % i, "kamer": KAMER, "y": 0.0, "klas": "hotspook",
			"titel": "zoveel hoort erin", "volg": _volg_tobbe(i)})
	if int(_s["rest"]) > 0:
		var rij := _rij_punt()
		ctx.ui.getal_tag({"x": rij["x"], "z": rij["z"]}, int(_s["rest"]),
			{"id": "tb_sk", "kamer": KAMER, "y": 6.0, "klas": "hotspook",
			"titel": "zoveel blijft over"})

func _hulp() -> void:
	if _s.is_empty():
		return
	_s["hulp"] = 1
	_zeg({"icoon": "🩺", "getal": int(_s["per"]), "tekst": "ieder evenveel"})
	ctx.state.zet_gezien("tobbe_els")
	ctx.snd.brief()
	_bewaar()
	_teken()

# =====================================================================
#  11. DE DIEREN IN BAD
# =====================================================================

func _in_bad_ids() -> Array:
	var uit: Array = []
	for l in _s["inbad"]:
		for id in l:
			uit.append(str(id))
	return uit

## Elke tobbe zit vol (twee dieren, games-a.md §6.5 E).  Dan kan er niemand meer
## bij, en zonder deze uitgang zou de ronde vastlopen: met vijf badgasten en twee
## tobbes blijft `_wachtenden()` altijd gevuld, dus zou de ✓ "klaar met
## badderen" nooit verschijnen en zou het spel nooit `af` worden.  Gevonden in de
## browserproef (band 4, vijf gasten).  De gast die overblijft houdt zijn wens
## 🛁 gewoon tot morgen — nooit straffen.
func _alle_tobbes_vol() -> bool:
	for l in _s["inbad"]:
		if (l as Array).size() < 2:
			return false
	return true

func _wachtenden() -> Array:
	var er := _in_bad_ids()
	var uit: Array = []
	for g in _badgasten():
		if not er.has(str(g["id"])):
			uit.append(g)
	return uit

func _moet_nog_in_bad() -> Array:
	var er := _in_bad_ids()
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if str(g.get("behoefte", "")) == "bad" and not bool(g.get("blij", false)) \
				and not er.has(str(g["id"])):
			uit.append(g)
	return uit

func _teken_baden() -> void:
	_teken_tobbes()
	_teken_som()
	var wacht := _wachtenden()
	for g in wacht.slice(0, 3):
		var id := str(g["id"])
		var d := World.dier(id)
		if d == null or d.kamer != KAMER:
			continue
		ctx.hotspots.maak({
			"id": "tb_dier" + id, "kamer": KAMER, "x": d.x, "z": d.z, "y": 34.0,
			"icoon": _ico(g), "label": str(g.get("naam", "")),
			"klas": "hotbron", "prio": 11, "titel": "%s wil in bad" % str(g.get("naam", "")),
			"volg": func() -> Dictionary:
				var q := World.dier(id)
				return {} if q == null else {"x": q.x, "z": q.z, "y": 34.0, "kamer": q.kamer},
			# ÉÉN tik-afhandelaar; het slepen zit op de tobbe, niet hier.  Wie je
			# aantikt gaat in bad, in de leegste tobbe (eigenaar, 2026-09-23: het
			# kind kiest met welk dier het speelt).  Tot dan ging bij elke tik de
			# EERSTE wachtende erin, ook als je een ander dier aantikte — de HTML
			# deed dat ook, maar daar kon je het dier zelf nog naar een tobbe
			# slepen, en dat slepen is in de poort nooit meegekomen.
			"aan": func(_spot) -> void: _in_bad(id, _leegste())})
	var rij := _rij_punt()
	if str(_s["stap"]) == "af":
		ctx.ui.wolk({"id": "tb_af", "kamer": KAMER, "x": rij["x"], "z": rij["z"],
			"hoog": 34.0, "icoon": "⭐", "tekst": "blinkend schoon", "klas": "goed",
			"prio": 13, "tik": func(_spot) -> void: ctx.sluit()})
	elif not wacht.is_empty() and (_s.get("zeg", {}) as Dictionary).is_empty():
		# één praatje tegelijk
		ctx.ui.wolk({"id": "tb_bad", "kamer": KAMER, "x": rij["x"], "z": rij["z"],
			"hoog": 34.0, "icoon": "🛁", "getal": wacht.size(),
			"tekst": "mag in de tobbe" if wacht.size() == 1 else "mogen in de tobbe",
			"prio": 10})
	if str(_s["stap"]) == "baden" and (wacht.is_empty() or _alle_tobbes_vol()) \
			and not _in_bad_ids().is_empty():
		var klaar := _gereedschap_punt(GEREEDSCHAP["klaar"])
		ctx.hotspots.maak({
			"id": "tb_klaar", "kamer": KAMER, "x": klaar["x"], "z": klaar["z"], "y": 0.0,
			"op": "onder", "obj": "tobbe", "icoon": "✓", "label": "klaar", "prio": 13,
			"titel": "klaar met badderen", "aan": func(_spot) -> void: _klaar_met_baden()})
	_teken_zeg()
	# een dier met de wens 🛁 kan nog onderweg zijn: dan tekenen we straks
	# opnieuw, hooguit acht keer, nooit een eindeloze lus
	if str(_s["stap"]) == "baden" and int(_s["tel"]) < 8:
		var onderweg := false
		for g in _moet_nog_in_bad():
			var q := World.dier(str(g["id"]))
			if q == null or q.kamer != KAMER:
				onderweg = true
		if onderweg:
			_s["tel"] = int(_s["tel"]) + 1
			_wacht_op_dier()

func _wacht_op_dier() -> void:
	if not await na(0.9):
		return
	if _s.is_empty() or str(_s["stap"]) != "baden":
		return
	_teken()

func _volgende_in_bad(i: int) -> void:
	var w := _wachtenden()
	if w.is_empty():
		return
	if i < 0:
		i = _leegste()       # geen tobbe aangewezen: pak de leegste
	_in_bad(str(w[0]["id"]), i)

## De tobbe waar het minst dieren in zitten (bij gelijkspel de linker).
func _leegste() -> int:
	var i := 0
	for j in range(1, int(_s["M"])):
		if (_s["inbad"][j] as Array).size() < (_s["inbad"][i] as Array).size():
			i = j
	return i

func _in_bad(id: String, i) -> void:
	if _s.is_empty() or str(_s["stap"]) != "baden" or id.is_empty():
		return
	if i == null or typeof(i) == TYPE_STRING:
		return
	var k := int(i)
	if k < 0 or k >= int(_s["M"]):
		return
	if _in_bad_ids().has(id):
		return
	if (_s["inbad"][k] as Array).size() >= 2:
		ctx.snd.zacht()
		_zeg({"icoon": "🛁", "getal": 2, "tekst": "zit vol"})
		_teken()
		return
	var g: Dictionary = ctx.state.gast_van(id)
	if g.is_empty():
		return
	(_s["inbad"][k] as Array).append(id)
	var p: Dictionary = _p[k]
	World.reis(id, KAMER, {"x": maxf(12.0, float(p["x"]) - 7.0),
		"z": float(p["z"]) + 7.0, "na": "blij"})
	World.mood(id, "bouncy")
	if str(g.get("behoefte", "")) == "bad":
		# Eerst het taakje afvinken (dat is ook de ster), DAARNA pas de wens
		# afmelden: `behoefte_klaar` tekent het prikbord meteen opnieuw, en een
		# kaartje dat dan nog niet afgevinkt is verdwijnt zonder vinkje.
		_ster()
		World.behoefte_klaar(id, "bad")
		_s["wens"] = 1
	g["waar"] = KAMER
	ctx.snd.plop(1)
	_zeg({"icoon": "😌", "tekst": "lekker warm", "klas": "goed"})
	_bewaar()
	Hotel.render()
	_teken()
	_wolkje_weg_straks()
	if int(_s["wens"]) != 0 and (_moet_nog_in_bad().is_empty() or _alle_tobbes_vol()):
		_straks_klaar()

func _wolkje_weg_straks() -> void:
	if not await na(2.6):
		return
	if _s.is_empty():
		return
	var z: Dictionary = _s.get("zeg", {})
	if str(z.get("icoon", "")) == "😌":
		_zeg(null)
		_teken()

func _straks_klaar() -> void:
	if not await na(1.2):
		return
	_klaar_met_baden()

func _klaar_met_baden() -> void:
	if _s.is_empty() or str(_s["stap"]) != "baden" or _in_bad_ids().is_empty():
		return
	_s["stap"] = "af"
	_zeg(null)
	_ster()
	ctx.snd.hoera()
	_bewaar()
	Hotel.render()
	_teken()
	if not await na(3.2):
		return
	if _s.is_empty() or str(_s["stap"]) != "af":
		return
	ctx.sluit()

# =====================================================================
#  12. PROBE — machineleesbare regels voor de browserdriver
# =====================================================================

## Alleen aan met `?tobbeprobe=1` (web) of `-- --tobbe-probe` (desktop), zodat
## de testsuite en het echte spel er niets van merken.
static func _probe_aan() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--tobbe-probe":
			return true
	if OS.has_feature("web"):
		var zoek = JavaScriptBridge.eval("location.search", true)
		if zoek != null and str(zoek).contains("tobbeprobe=1"):
			return true
	return false

func stand() -> Dictionary:
	return _s.duplicate(true)

func plekken() -> Array:
	return _p.duplicate(true)

func _meld() -> void:
	if not _probe:
		return
	print("[probe] tobbe stand=", JSON.stringify({
		"stap": str(_s["stap"]), "soort": str(_s["soort"]), "band": int(_s["band"]),
		"T": int(_s["T"]), "M": int(_s["M"]), "per": int(_s["per"]),
		"rest": int(_s["rest"]), "rek": int(_s["rek"]), "tob": _s["tob"],
		"kan": int(_s["kan"]), "hand": int(_s["hand"]), "missers": int(_s["missers"]),
		"hulp": int(_s["hulp"]), "ster": int(_s["ster"]), "inbad": _s["inbad"]}))
	if not await na(0.1):
		return
	# `dekking_max` telt alleen de KNOPPEN: een vaste kaart en een cijfer mogen
	# volgens architecture.md §4.3 als enige over de wereld staan, en `kaartdek`
	# houdt die apart zichtbaar in plaats van ze te verzwijgen.
	var dek := 0.0
	var dek_id := ""
	var kaartdek := 0.0
	var krap := 0
	var dbg := Hits.debug()
	for id in dbg.keys():
		var spot := Hits.spot(id)
		if spot == null or not is_instance_valid(spot.knoop) or not spot.knoop.visible:
			continue
		if spot.door == ctx.id or id.begins_with("tb_"):
			print("[probe] tobbe knop ", id, "=", (spot.knoop as Control).get_global_rect())
		if int(dbg[id]["laag"]) == Hits.Laag.VAST:
			kaartdek = maxf(kaartdek, Hits.dekking(id))
		elif Hits.dekking(id) > dek:
			dek = Hits.dekking(id)
			dek_id = id
		if bool(dbg[id]["krap"]):
			krap += 1
	print("[probe] tobbe hits=", dbg.size(), " krap=", krap,
		" dekking_max=", "%.2f" % dek, " op=", dek_id,
		" kaartdek=", "%.2f" % kaartdek)
