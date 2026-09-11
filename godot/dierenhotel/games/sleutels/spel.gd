extends MiniGame
## HET SLEUTELBORD — games-a.md §4, architecture.md §12.2 row `sleutels`.
##
## Aan de balie staat een gast met een sleutellabel; aan de wand hangt een rij
## nummerplaatjes waarvan er een of twee leeg zijn.  Je hangt de sleutel op het
## goede haakje, de gast loopt naar zijn eigen kamer en boven zijn deur in de
## gang komt een 💡-plaatje.
##
## Wat uit de HTML-versie is overgenomen en wat niet:
##
##  * De generator is bevroren (F1) en staat in `Sommen.Sleutels`; dit spel
##    rekent zelf niets uit.  Het is het enige spel van groep A met toeval, en
##    dat toeval is volledig gezaaid (`dag*7919 + N*131 + band*17 + ronde*8191 + 1`).
##  * `opbouw()` mat in de browser de echte DOM-maten op (`sl_kaart`, `sl_tag`,
##    `sl_key`, elke `sl_h<i>`) en koos daarna een van vier opstellingen.  Hier
##    kiest `_opbouw()` diezelfde vier opstellingen vóór de eerste tekenbeurt,
##    uit de kadermaat en `Control.get_combined_minimum_size()` — synchroon, dus
##    er is geen beeld waarin de rij nog verkeerd staat.
##  * De plek van het sleutelbord komt uit `Rooms` (de receptie is verbouwd:
##    de balie staat langs de achterwand, de deur zit linksboven), nooit uit een
##    getal in dit bestand.  De rij hangt op de diepte van het bord (`x + z`
##    blijft gelijk), dus ze staat waterpas op het scherm en houdt haar plek in
##    de tekenvolgorde.
##  * Het wolkje en de sleutel hangen aan de gast zodra hij aan de balie staat
##    (`volg` + zijn eigen plaatrechthoek), zodat de knoppenlaag precies weet
##    wat ze vrij moet laten; loopt hij nog door een andere kamer, dan wachten
##    ze op de balieplek in plaats van met hem mee te verhuizen — een hotspot in
##    een andere kamer is onzichtbaar, en onzichtbaar betekent ongemeten.

# ------------------------------------------------------------------ constanten

const TAAK := "sleutels"
const DROP := "haak"              ## de naam die een gesleepte sleutel draagt

const WACHT_LEEG := 1.9           ## geen gasten: het spel sluit zichzelf
const WACHT_AF := 2.6             ## het 💤-wolkje van de weglopende gast
const WACHT_EIND := 3.4           ## nagenieten in de gang
const WACHT_KADER := 0.22         ## kader veranderd -> opnieuw indelen

const DIER_HOOG := 28.0           ## de gasten zijn 23-28 voxels hoog
const GAT := 4.0                  ## lucht tussen kaart en rij (games-a.md §4.4)
const KNOP := 48.0                ## een plaatje is een tikdoel
const STAP_MIN := 53.0            ## minstens zoveel css-px tussen twee plaatjes
const RAND := 6.0                 ## lucht tot de kaderrand (Hits.RAND)
## Het lage-kaderbreekpunt van architecture.md §4.5: onder deze hoogte klapt de
## schil zelf al in en heeft de kaart geen plek meer bóven de rij.
const LAAG_KADER := 450.0

# --------------------------------------------------------------------- staat

var _p: Dictionary = {}           ## de opdracht (Sommen.Sleutels.maak_opdracht)
var _gasten: Array = []           ## de gasten met een bed, in check-in volgorde
var _kaart = null                 ## Ui.Kaart
var _licht := -1                  ## het plaatje dat is aangetikt
var _buren: Array[int] = []       ## de twee buren die na een misser oplichten
var _buur_gat := -1               ## het haakje waar de misser over ging
var _spook := false               ## Els heeft de goede getallen neergelegd
var _tip := ""                    ## haar hulpregel op de kaart
var _lay: Dictionary = {}         ## de laatst gekozen opstelling
var _bord_plek: Dictionary = {}   ## de plek van het sleutelbord, uit Rooms
var _kader_af: Callable           ## opzegging van ctx.ui.op_kader
var _kader_teller := 0            ## ontdubbelt de kaderwachters
var _af := false                  ## de ronde is uitgespeeld

# ---------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	return {
		"naam": "Het sleutelbord",
		"kamer": "receptie",
		"hotspot": {"obj": "sleutelbordz", "icoon": "🔑", "label": "Sleutels",
			"hoog": 13, "dz": 6},
		"unlock": func(n: int, _band: int) -> bool: return n >= 2,
		"taak": {"id": TAAK, "icoon": "🔑", "tekst": "Hang de sleutels op",
			"kamer": "receptie", "prio": 5,
			"wanneer": func(s: Dictionary) -> bool:
				return (s["gasten"] as Array).size() >= 2},
	}

# ------------------------------------------------------------- levenscyclus

func start(_c: SpelCtx) -> void:
	_licht = -1
	_buren = []
	_buur_gat = -1
	_spook = false
	_tip = ""
	_af = false
	_bord_plek = _zoek_bord()
	_gasten = _gasten_met_bed()
	if _gasten.is_empty():
		_geen_gasten()
		return
	var d := ctx.data()
	var n: int = ctx.state.n_gasten()
	var band: int = ctx.state.band()
	var dag := int(ctx.state.s["dag"])
	var ronde := int(d.get("ronde", 0))
	d["ronde"] = ronde
	var sig := Sommen.Sleutels.handtekening(n, clampi(band, 3, 5), dag, ronde)
	var oud = d.get("bord", null)
	if typeof(oud) != TYPE_DICTIONARY or str((oud as Dictionary).get("sig", "")) != sig \
			or bool((oud as Dictionary).get("klaar", false)) or not _gasten_kloppen(oud):
		var mee: Array = _gasten.slice(0, int(Sommen.Sleutels.MAXBLANCO.get(clampi(band, 3, 5), 2)))
		d["bord"] = Sommen.Sleutels.maak_opdracht(n, band, dag, mee, ronde)
	_p = d["bord"]
	if int(_p.get("t0", 0)) == 0:
		_p["t0"] = Time.get_ticks_msec()
	_haal_gast()
	_kader_af = ctx.ui.op_kader(_op_kader)
	_teken()
	print("[probe] spel=start id=", ctx.id, " band=", band, " borden=", _borden().size(),
		" sleutels=", _sleutels().size(), " opbouw=", _lay.get("modus", ""))


## Geen enkele gast heeft een bed: één wolkje op het sleutelbord en het spel
## sluit zichzelf.  Nooit een foutmelding, nooit een dood scherm.
func _geen_gasten() -> void:
	ctx.ui.wolk({"id": "sl_leeg", "kamer": ctx.kamer,
		"x": _bord_plek.get("x", 0.0), "z": _bord_plek.get("z", 0.0), "hoog": 26.0,
		"icoon": "🛏", "tekst": "nog geen gasten", "klas": "hulp", "prio": 10})
	if not await na(WACHT_LEEG):
		return
	ctx.ui.wolk_weg("sl_leeg")
	ctx.sluit()


func stop() -> void:
	if _kader_af.is_valid():
		_kader_af.call()
		_kader_af = Callable()
	# wie nog met zijn sleutellabel aan de balie stond gaat terug naar zijn
	# eigen kamer en in bed: het hotel blijft opgeruimd achter
	for s in _sleutels():
		if not bool((s as Dictionary).get("op", false)):
			_naar_kamer(str((s as Dictionary).get("gast", "")), false)
	ctx.hotspots.laat()
	if not _p.is_empty():
		State.bewaar()
	Hotel.render()
	print("[probe] spel=stop id=", ctx.id, " klaar=", bool(_p.get("klaar", false)))

# ------------------------------------------------------------------ de gasten

## `gastenMetBed()` — alle gasten met een bed én een kamer, in de volgorde van
## de savegame (dat is de check-in volgorde, A1 §13 Q-X2-4).
func _gasten_met_bed() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		var gast: Dictionary = g
		if not str(gast.get("bed", "")).is_empty() and not str(gast.get("kamer", "")).is_empty():
			uit.append(gast)
	return uit


## Staan de gasten van deze opdracht er nog (niet uitgecheckt)?
func _gasten_kloppen(p) -> bool:
	if typeof(p) != TYPE_DICTIONARY:
		return false
	var lijst: Array = (p as Dictionary).get("sleutels", [])
	if lijst.is_empty():
		return false
	for s in lijst:
		var g: Dictionary = ctx.state.gast_van(str((s as Dictionary).get("gast", "")))
		if g.is_empty() or str(g.get("bed", "")).is_empty() or str(g.get("kamer", "")).is_empty():
			return false
	return true


## De gast van de huidige sleutel komt naar de balie — tenzij hij daar al
## binnen 8 voxels (manhattan) staat.
func _haal_gast() -> void:
	var s := _sleutel_nu()
	if s.is_empty():
		return
	var id := str(s.get("gast", ""))
	var g: Dictionary = ctx.state.gast_van(id)
	if g.is_empty():
		return
	var plek := _plek(0.75, 0.85)
	var d = ctx.wereld.dier(id)
	if d != null and d.kamer == ctx.kamer \
			and absf(d.x - plek.x) + absf(d.z - plek.y) < 8.0:
		return
	ctx.wereld.reis(id, ctx.kamer, {"x": plek.x, "z": plek.y, "na": "wacht"})
	g["waar"] = ctx.kamer
	ctx.wereld.vuil()


## Het dier gaat naar zijn eigen kamer en kruipt in bed.
func _naar_kamer(gast_id: String, blij: bool) -> void:
	var g: Dictionary = ctx.state.gast_van(gast_id)
	if g.is_empty():
		return
	if not str(g.get("kamer", "")).is_empty() and not str(g.get("bed", "")).is_empty():
		ctx.wereld.slaap(gast_id, str(g["kamer"]), str(g["bed"]))
		g["waar"] = g["kamer"]
		if blij:
			ctx.wereld.mood(gast_id, "blij")
	else:
		ctx.wereld.solo(gast_id, "blij")
	ctx.wereld.vuil()

# ------------------------------------------------------------- de opdracht

func _borden() -> Array:
	return _p.get("borden", [])


func _sleutels() -> Array:
	return _p.get("sleutels", [])


func _sleutel_nu() -> Dictionary:
	var lijst := _sleutels()
	var nu := int(_p.get("nu", 0))
	return {} if nu < 0 or nu >= lijst.size() else lijst[nu]


## Het bord in beeld: dat van de huidige sleutel, of het laatste als alles op is.
func _bord_nu() -> Dictionary:
	var borden := _borden()
	if borden.is_empty():
		return {}
	var s := _sleutel_nu()
	if not s.is_empty():
		return borden[clampi(int(s.get("bord", 0)), 0, borden.size() - 1)]
	return borden[borden.size() - 1]


func _haken(b: Dictionary) -> Array:
	return b.get("haken", [])


func _drie_cijfers(b: Dictionary) -> bool:
	return int(b.get("van", 0)) + (int(b.get("n", 0)) - 1) * int(b.get("stap", 1)) >= 100


## `nrTekst` — hoe je één plaatje noemt.
func _nr_tekst(w: int) -> String:
	return "kamer %d" % w if str(_p.get("variant", "")) == "kamers" else "nummer %d" % w


## Wat de voorleesstem van een kamernummer maakt.
func _verdieping(w: int) -> String:
	@warning_ignore("integer_division")
	return "kamer %d, verdieping %d, kamer %d" % [w, w / 100, w % 100]


## De rij zoals je hem in je schrift schrijft: `5, 10, __, 20, 25`.
func _rij_tekst(b: Dictionary) -> String:
	var stuks: Array[String] = []
	for h in _haken(b):
		var haak: Dictionary = h
		stuks.append("__" if _is_leeg(haak) else str(int(haak.get("w", 0))))
	var label := str(b.get("label", ""))
	return ("%s: " % label if not label.is_empty() else "") + ", ".join(stuks)


func _is_leeg(h: Dictionary) -> bool:
	return bool(h.get("blanco", false)) and str(h.get("sleutel", "")).is_empty()


## `burenVan` — links en rechts, aan de rand de twee plaatjes die er wél zijn.
func _buren_van(b: Dictionary, i: int) -> Array[int]:
	var n := _haken(b).size()
	var uit: Array[int] = []
	if i - 1 >= 0:
		uit.append(i - 1)
	if i + 1 < n:
		uit.append(i + 1)
	if uit.size() < 2 and i + 2 < n:
		uit.append(i + 2)
	if uit.size() < 2 and i - 2 >= 0:
		uit.append(i - 2)
	uit.sort()
	return uit


## Het getallenlijntje in het antwoordvakje: `10 … ? … 20`.
func _buren_tekst() -> String:
	var b := _bord_nu()
	if _buren.is_empty() or b.is_empty():
		return ""
	var rij := _buren.duplicate()
	rij.append(_buur_gat)
	rij.sort()
	var stuks: Array[String] = []
	var haken := _haken(b)
	for k in rij:
		if k < 0 or k >= haken.size():
			continue
		var h: Dictionary = haken[k]
		stuks.append("?" if (k == _buur_gat and _is_leeg(h)) else str(int(h.get("w", 0))))
	return " … ".join(stuks)

# ------------------------------------------------------- plekken uit Rooms

## Elke plek is een breuk van de kamer (`Rooms.plek` / `Rooms.hoogte`), zodat
## niets hier een voxelgetal van de receptie hard neerzet.
func _plek(fx: float, fz: float) -> Vector2:
	var p := Rooms.plek(ctx.kamer, fx, fz)
	return Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0)))


func _hoog(f: float) -> float:
	return float(Rooms.hoogte(ctx.kamer, f))


## Waar het sleutelbord hangt — uit `Rooms`, nooit uit een getal hier.  Valt de
## kamer ooit zonder bord, dan blijft het midden van de wand over.
func _zoek_bord() -> Dictionary:
	var stuk: Dictionary = ctx.wereld.mik("sleutelbordz", ctx.kamer)
	if not stuk.is_empty():
		return {"x": float(stuk.get("x", 0.0)), "z": float(stuk.get("z", 0.0))}
	var mid := _plek(0.625, 0.625)
	return {"x": mid.x, "z": mid.y}


func _bord_som() -> float:
	return float(_bord_plek.get("x", 0.0)) + float(_bord_plek.get("z", 0.0))


## De plek van haakje `i`.  De diepte `x + z` blijft die van het sleutelbord:
## de rij staat waterpas op het scherm en houdt haar plek in de tekenvolgorde.
## Het eerste plaatje hangt één stap naast het bord, zodat geen plaatje binnen
## `Hits.VLAK_NABIJ` van een meubelstuk komt en er dus aan vast gaat plakken.
##
## Past de hele rij niet op één regel (een kader dat smaller is dan vijf
## tikdoelen naast elkaar), dan zakt wat overblijft één band lager in plaats van
## dat de knoppenlaag er één plaatje uit tilt: elk plaatje blijft 48 x 48 en de
## volgorde blijft leesbaar.  De HTML kende dat niet — daar viel de rij uit
## elkaar.
func _haak_plek(i: int, dx: float, y: float, schuif: float, per_regel := 0) -> Dictionary:
	var breed := maxi(1, per_regel if per_regel > 0 else i + 1)
	@warning_ignore("integer_division")
	var regel := i / breed
	var kol := i % breed
	var x: float = float(_bord_plek.get("x", 0.0)) + schuif + dx * float(kol + 1)
	return {"x": x, "z": _bord_som() - x, "y": y - float(regel) * _band_in_voxels()}


## Eén knoppenband (52 units) uitgedrukt in voxelhoogte.
func _band_in_voxels() -> float:
	var per: float = ctx.wereld.px_per_hoogte()
	return float(Hits.RIJ) / maxf(0.001, per)

# -------------------------------------------------------------- de opstelling

## De vier opstellingen van games-a.md §4.4, gekozen uit de KADERMAAT en de
## gemeten Controlmaten in plaats van uit een DOM-meting ná een tekenbeurt:
##
##   `gewoon`  de rij vlak boven het sleutelbord, de kaart erboven;
##   `stapel`  de kaart tegen de bovenrand en de rij precies zoveel lager als de
##             kaart nodig heeft (portret en de smalle telefoon);
##   `naast`   liggende telefoon: de kaart uiterst links, de rij rechts ernaast
##             op haar eigen hoogte;
##   `krap`    er past niets naast en niets boven elkaar: de rij gaat vóór en
##             zakt zo laag als het kader toelaat, de kaart neemt wat overblijft.
##
## De drempels zijn geen ronde getallen maar de vraag zelf: past de kaart nog
## bóven de rij (`kort`), en past ze ernáást (`smal`)?  Alles rekent in
## kader-units, precies zoals de knoppenlaag:
##   scherm-x = px0 + (x − z)·2k     scherm-y = py0 + (x + z − 2y)·k
## `_hoogte_voor()` is de omgekeerde weg (het `hoogteVoor` van de HTML).
func _opbouw(b: Dictionary) -> Dictionary:
	var kader: Rect2 = ctx.wereld.kader_rect()
	var k: float = float(ctx.wereld.schaal().get("k", 1.0))
	var n := _haken(b).size()
	var basis := _hoog(0.2) if _drie_cijfers(b) else _hoog(0.1625)
	var dx_min := maxf(1.0, ceilf(STAP_MIN / maxf(0.001, 4.0 * k)))
	var dx := maxf(basis, dx_min)
	var wolk_y := _hoog(0.4625)
	var kaart_maat := _kaart_maat()

	# de rij hangt vlak boven het sleutelbord zelf: dat is haar plek in de
	# wereld, en de plaat van het bord komt uit `Rooms`, nooit uit een getal hier
	var bord_vlak := _bord_vlak()
	var rij_py_nat := _py_van(_hoog(0.6))
	if bord_vlak.size.y > 0.0:
		rij_py_nat = bord_vlak.position.y - GAT - KNOP * 0.5
	rij_py_nat = clampf(rij_py_nat, RAND + KNOP * 0.5,
		maxf(RAND + KNOP * 0.5, kader.size.y - RAND - KNOP * 0.5))
	# de kaart hoort bij de rij en staat er normaal gesproken boven
	var kaart_py_nat := rij_py_nat - KNOP * 0.5 - GAT - kaart_maat.y * 0.5
	# `kort` is het lage-kaderbreekpunt van architecture.md §4.5 (`height < 450`,
	# het punt waarop de schil zelf al inklapt): daar staat de kaart bóven de rij
	# het halve wereldbeeld in de weg.  `smal` is de vraag zelf: passen de kaart
	# en de rij naast elkaar, met de kleinst toegestane stap tussen twee plaatjes?
	var rij_min := float(n - 1) * 4.0 * dx_min * k + KNOP
	var kort := kader.size.y < LAAG_KADER
	var smal := kader.size.x < kaart_maat.x + GAT + rij_min + 2.0 * RAND
	var modus := "krap" if (kort and smal) else ("naast" if kort else "stapel")

	# 1. de kaart kiest eerst — zij is `vast` en de rij moet weten waar zij komt
	var kaart_py := kaart_py_nat
	var links_min := RAND
	match modus:
		"stapel":
			kaart_py = maxf(kaart_py_nat, RAND + kaart_maat.y * 0.5)
		"naast":
			# de kaart uiterst links op halve hoogte, de rij rechts ernaast
			kaart_py = clampf(kader.size.y * 0.5, RAND + kaart_maat.y * 0.5,
				maxf(RAND + kaart_maat.y * 0.5, kader.size.y - RAND - kaart_maat.y * 0.5))
			var kaart_px := clampf(_px_van({"x": float(_bord_plek.get("x", 0.0)),
				"z": float(_bord_plek.get("z", 0.0)), "y": 0.0}),
				2.0 + kaart_maat.x * 0.5,
				maxf(2.0 + kaart_maat.x * 0.5, kader.size.x - 2.0 - kaart_maat.x * 0.5))
			links_min = kaart_px + kaart_maat.x * 0.5 + GAT
		"krap":
			kaart_py = RAND + kaart_maat.y * 0.5
	# ze mag over de wereld staan, maar niet over het bord waar ze aan hangt
	# (`Hits._wijk_omhoog` doet dat ook, maar dan weet de rij het niet)
	kaart_py = _wijk_kaart(kaart_py, kaart_maat, bord_vlak, kader)
	var kaart_r := _kaart_rect(kaart_py, kaart_maat, kader)

	# 2. de breedte: kleinere stappen, dan pas een tweede regel
	dx = _pas_dx(dx, dx_min, n, kader, k, links_min)
	var per_regel := _per_regel(dx, n, kader, k, links_min)
	@warning_ignore("integer_division")
	var regels := (n + per_regel - 1) / per_regel
	var hoog := KNOP + float(regels - 1) * float(Hits.RIJ)
	# ... en dan schuift de rij langs de wand tot ze binnen haar ruimte valt
	var schuif := _pas_schuif(dx, 0.0, per_regel, kader, k, links_min)

	# 3. de hoogte van de rij, ten opzichte van de kaart zoals die er nu staat
	var rij_py := rij_py_nat
	match modus:
		"stapel":
			rij_py = maxf(rij_py_nat, kaart_r.end.y + GAT + KNOP * 0.5)
		"krap":
			# de rij gaat vóór en zakt zo laag als het kader toelaat; ligt de
			# kaart daar al, dan gaat de rij er juist bovenop staan
			rij_py = kader.size.y - RAND - hoog + KNOP * 0.5
			if rij_py - KNOP * 0.5 < kaart_r.end.y + GAT:
				rij_py = kaart_r.position.y - GAT - hoog + KNOP * 0.5
	rij_py = clampf(rij_py, RAND + KNOP * 0.5,
		maxf(RAND + KNOP * 0.5, kader.size.y - RAND - hoog + KNOP * 0.5))
	# en ze mag op geen enkel meubelstuk en niet op de kaart staan
	rij_py = _wijk_van_voorwerpen(rij_py, dx, schuif, kader, kaart_py, kaart_maat,
		per_regel, regels)

	if modus == "stapel" and is_equal_approx(rij_py, rij_py_nat) \
			and is_equal_approx(kaart_py, kaart_py_nat) \
			and is_equal_approx(dx, basis) and is_zero_approx(schuif) and regels == 1:
		modus = "gewoon"
	return {"modus": modus, "haak_y": _hoogte_voor(rij_py), "dx": dx, "schuif": schuif,
		"wolk_y": wolk_y, "kaart_y": _hoogte_voor(kaart_py), "kaart_py": kaart_py,
		"kaart_maat": kaart_maat, "rij_py": rij_py, "n": n,
		"per_regel": per_regel, "regels": regels}


## Hoeveel plaatjes er op één regel passen.  Onder de vijf tikdoelen breed
## (een kader van ~250 units) gaat de rij op twee regels verder.
func _per_regel(dx: float, n: int, kader: Rect2, k: float, links_min: float) -> int:
	var stap := 4.0 * dx * k
	if stap <= 0.0:
		return n
	var ruimte := kader.size.x - links_min - RAND - KNOP
	return clampi(int(floorf(ruimte / stap)) + 1, 1, n)


## De plaat van het sleutelbord op het scherm, uit `Rooms` + `World`.
func _bord_vlak() -> Rect2:
	var stuk: Dictionary = ctx.wereld.mik("sleutelbordz", ctx.kamer)
	if stuk.is_empty():
		return Rect2()
	var model := str(stuk.get("model", stuk.get("n", "")))
	if model.is_empty() or not Art.heeft_model(model):
		return Rect2()
	return ctx.wereld.vlak_van(model, float(stuk.get("x", 0.0)), float(stuk.get("z", 0.0)),
		float(stuk.get("hoog", stuk.get("y", 0.0))), stuk.get("params", {}))


## Waar de sommenkaart terechtkomt: op haar mikpunt, in het kader geklemd —
## precies wat `Hits._plaats_midden` doet, zodat de rij weet waar ze wél mag.
func _kaart_rect(py: float, maat: Vector2, kader: Rect2) -> Rect2:
	var mx := _px_van({"x": float(_bord_plek.get("x", 0.0)),
		"z": float(_bord_plek.get("z", 0.0)), "y": 0.0})
	var r := Rect2(Vector2(mx - maat.x * 0.5, py - maat.y * 0.5), maat)
	r.position.x = clampf(r.position.x, 2.0, maxf(2.0, kader.size.x - maat.x - 2.0))
	r.position.y = clampf(r.position.y, 2.0, maxf(2.0, kader.size.y - maat.y - 2.0))
	return r


## De kaart mag over de wereld staan, maar niet over het bord waar ze aan hangt
## (HOTEL.md §9).  `Hits` doet dit ook; hier is het nodig omdat de rij moet
## weten waar de kaart écht komt te staan.
func _wijk_kaart(py: float, maat: Vector2, vlak: Rect2, kader: Rect2) -> float:
	if vlak.size.y <= 0.0:
		return py
	for stap in 6:
		for teken in ([0] if stap == 0 else [-1, 1]):
			var p := py + float(teken * stap) * float(Hits.RIJ)
			if p - maat.y * 0.5 < RAND or p + maat.y * 0.5 > kader.size.y - RAND:
				continue
			var snij := _kaart_rect(p, maat, kader).intersection(vlak)
			if snij.size.x <= 0.001 or snij.size.y <= 0.001:
				return p
	return py


## De schermhoogte van een punt op de diepte van de rij.
func _py_van(y: float) -> float:
	var p: Vector2 = ctx.wereld.mik_punt(float(_bord_plek.get("x", 0.0)),
		float(_bord_plek.get("z", 0.0)), y)
	return p.y


func _px_van(plek: Dictionary) -> float:
	var p: Vector2 = ctx.wereld.mik_punt(float(plek["x"]), float(plek["z"]), float(plek["y"]))
	return p.x


## `hoogteVoor(som, py)` — de hoogte die een punt op deze diepte op scherm-y
## `py` zet.  Naar beneden afgerond: hooguit één stapje LAGER dan gevraagd.
func _hoogte_voor(py: float) -> float:
	var per: float = ctx.wereld.px_per_hoogte()
	if per <= 0.0:
		return 0.0
	return floorf((_py_van(0.0) - py) / per)


## Kleinere stappen als de rij anders breder wordt dan de ruimte die ze heeft
## (`links_min` is de linkerrand van die ruimte: de kaderrand, of de rechterkant
## van de kaart in de opstelling `naast`).
func _pas_dx(dx: float, dx_min: float, n: int, kader: Rect2, k: float,
		links_min: float) -> float:
	if n <= 1:
		return dx
	var ruimte := kader.size.x - links_min - RAND - KNOP
	var past := ruimte / maxf(0.001, float(n - 1) * 4.0 * k)
	return maxf(dx_min, minf(dx, floorf(past)))


## De hele rij schuift langs de wand tot ze binnen haar ruimte valt.  Eén stap
## `(x+1, z−1)` verplaatst haar `4k` px naar rechts en houdt de diepte gelijk,
## dus ze blijft waterpas en houdt haar plek in de tekenvolgorde (`schuifVoor`).
func _pas_schuif(dx: float, schuif: float, n: int, kader: Rect2, k: float,
		links_min: float) -> float:
	var stap := maxf(0.001, 4.0 * k)
	var rechts := _px_van(_haak_plek(maxi(0, n - 1), dx, 0.0, schuif)) + KNOP * 0.5
	if rechts > kader.size.x - RAND:
		schuif -= ceilf((rechts - (kader.size.x - RAND)) / stap)
	var links := _px_van(_haak_plek(0, dx, 0.0, schuif)) - KNOP * 0.5
	if links < links_min:
		schuif += ceilf((links_min - links) / stap)
	return schuif


## De rij stapt in hele banden omhoog (en anders omlaag) tot ze geen meubelstuk
## en niet de sommenkaart meer raakt.  Dat is wat `hits.js` met vier
## ontwijkrondes deed en wat hier één keer, vóór de eerste tekenbeurt gebeurt.
func _wijk_van_voorwerpen(rij_py: float, dx: float, schuif: float, kader: Rect2,
		kaart_py: float, kaart_maat: Vector2, per_regel: int, regels: int) -> float:
	var vakken := _vlakken()
	vakken.append_array(_vaste_vlakken())
	vakken.append(_kaart_rect(kaart_py, kaart_maat, kader).grow(GAT))
	for stap in 8:
		for teken in ([0] if stap == 0 else [-1, 1]):
			var py: float = rij_py + float(teken * stap) * float(Hits.RIJ)
			var r := _rij_vlak(py, dx, schuif, per_regel, regels)
			if r.position.y < RAND or r.end.y > kader.size.y - RAND:
				continue
			if not _raakt(r, vakken):
				return py
	return rij_py


## De rechthoek die alle plaatjes samen op het scherm innemen; `py` is de
## middenlijn van de eerste regel, want elk plaatje staat met zijn midden op
## zijn mikpunt.
func _rij_vlak(py: float, dx: float, schuif: float, per_regel: int, regels: int) -> Rect2:
	var links := _px_van(_haak_plek(0, dx, 0.0, schuif, per_regel)) - KNOP * 0.5
	var rechts := _px_van(_haak_plek(maxi(0, per_regel - 1), dx, 0.0, schuif, per_regel)) \
		+ KNOP * 0.5
	return Rect2(Vector2(links, py - KNOP * 0.5),
		Vector2(maxf(KNOP, rechts - links), KNOP + float(regels - 1) * float(Hits.RIJ)))


func _raakt(r: Rect2, vakken: Array[Rect2]) -> bool:
	for v in vakken:
		var snij := r.intersection(v)
		if snij.size.x > 0.001 and snij.size.y > 0.001:
			return true
	return false


## Elke plaatrechthoek die op dit moment in de kamer staat: het vaste decor uit
## `Rooms`, het losse decor van de wereld en de gasten zelf.
func _vlakken() -> Array[Rect2]:
	var uit: Array[Rect2] = []
	var r := Rooms.get_kamer(ctx.kamer)
	var stukken: Array = []
	if r != null:
		stukken.append_array(r.decor)
		stukken.append_array(r.slots.values())
	stukken.append_array(ctx.wereld.decor_lijst(ctx.kamer))
	stukken.append_array(ctx.wereld.dingen(ctx.kamer))
	for stuk in stukken:
		if typeof(stuk) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = stuk
		var model := str(s.get("model", s.get("n", "")))
		if model.is_empty() or not Art.heeft_model(model):
			continue
		var vlak: Rect2 = ctx.wereld.vlak_van(model, float(s.get("x", 0.0)), float(s.get("z", 0.0)),
			float(s.get("hoog", s.get("y", 0.0))), s.get("params", {}))
		if vlak.size.x > 0.0:
			uit.append(vlak)
	for d in ctx.wereld.dieren(ctx.kamer):
		var vlak: Rect2 = ctx.wereld.vlak_van_dier(d.id)
		if vlak.size.x > 0.0:
			uit.append(vlak)
	return uit


## Wat vóór de rij zijn plek al heeft gekozen: alles in de vaste laag met een
## hogere prioriteit dan de rij zelf (de kaart van het hotel, het cijferpad).
## Die staan er al als de rij aan de beurt is, dus de rij moet er zelf omheen —
## anders tilt `Hits._wijk_omhoog` één plaatje een band op en is de rij geen rij
## meer.  Wat lager staat (een naamplaatje, een cijfer) wijkt juist vóór de rij.
func _vaste_vlakken() -> Array[Rect2]:
	var uit: Array[Rect2] = []
	var dbg := Hits.debug()
	for id in dbg.keys():
		var spot := Hits.spot(id)
		if spot == null or spot.door == ctx.id:
			continue
		var d: Dictionary = dbg[id]
		if int(d.get("laag", 9)) != Hits.Laag.VAST or int(d.get("prio", 0)) <= 12:
			continue
		uit.append(d["rect"])
	return uit


## De maat die de sommenkaart nodig heeft.  Een Control kent zijn minimum
## synchroon zodra hij in de themaboom hangt, dus er hoeft niets gemeten te
## worden ná een tekenbeurt.
func _kaart_maat() -> Vector2:
	var s := Hits.spot("sl_kaart")
	if s != null and is_instance_valid(s.knoop):
		var m: Vector2 = s.knoop.get_combined_minimum_size()
		if m.x > 0.0 and m.y > 0.0:
			return m
	return Vector2(UiSomkaart.BREED_KLEIN if Ui.smal() else UiSomkaart.BREED, 96.0)

# ----------------------------------------------------------------- tekenen

## Alles wat dit spel op het scherm zet, in één beurt: eerst de kaart (die weet
## haar maat meteen), dan de opstelling, dan de rij, de sleutel, het wolkje,
## Els en de deurplaatjes in de gang.
func _teken() -> void:
	if not actief or _p.is_empty():
		return
	ctx.hotspots.wis_alles()
	var b := _bord_nu()
	if b.is_empty():
		return
	var s := _sleutel_nu()
	_teken_kaart(b, s)
	_lay = _opbouw(b)
	_verzet_kaart(_lay)
	_teken_haken(b, _lay)
	_teken_sleutel(s)
	_teken_wolk(s, _lay)
	_teken_els()
	_deur_plaatjes()
	ctx.wereld.vuil()
	_meld_rij()


## Eén machineleesbare regel per tekenbeurt, voor de browserproef: welke sleutel
## in de hand zit en waar elk plaatje ligt.  De knoppenlaag plaatst pas in de
## volgende tekenbeurt, dus de regel wacht één beurt (`res://games/_voorbeeld/`
## doet hetzelfde).
func _meld_rij() -> void:
	if not await na(0.05):
		return
	var s := _sleutel_nu()
	var rijtje: Array[String] = []
	for i in _haken(_bord_nu()).size():
		var spot := Hits.spot("sl_h%d" % i)
		if spot != null and is_instance_valid(spot.knoop):
			rijtje.append("sl_h%d=%s" % [i, str((spot.knoop as Control).get_global_rect())])
	print("[probe] sleutels opbouw=", _lay.get("modus", ""), " nu=", int(_p.get("nu", 0)),
		" sleutel=", int(s.get("nummer", -1)), " goed=", int(s.get("haak", -1)),
		" missers=", int(_p.get("missers", 0)), " klaar=", bool(_p.get("klaar", false)),
		" rij=[", " ".join(rijtje), "]")


## De rij staat er nooit kaal (HOTEL.md §9): één gewone vraag erboven, met het
## pictogram vooraan op diezelfde regel.
func _teken_kaart(b: Dictionary, s: Dictionary) -> void:
	var vraag := "De rij is nu af"
	if not s.is_empty():
		vraag = "Welk kamernummer hoort in het gat?" if str(_p.get("variant", "")) == "kamers" \
			else "Welk nummer hoort in het gat?"
	_kaart = ctx.ui.somkaart("sleutelbordz", _rij_tekst(b), {
		"id": "sl_kaart", "kamer": ctx.kamer, "hoog": _hoog(0.775), "pad": false,
		"icoon": "🔑", "regel": vraag, "titel": vraag,
	})
	if _kaart == null:
		return
	if s.is_empty():
		_kaart.klaar()
	else:
		_kaart.zet("🔑%d" % int(s.get("nummer", 0)))
	if not _buren.is_empty():
		_kaart.hulp(_buren_tekst())
	elif not _tip.is_empty():
		_kaart.hulp(_tip)


## De kaart gaat naar de hoogte die de opstelling voor haar koos.  Het mikpunt
## van een hotspot mag verzet worden; de knoppenlaag leest het elke beurt
## opnieuw, dus er hoeft geen Control opnieuw gebouwd te worden — en zo staat de
## kaart al goed vóór haar eerste tekenbeurt.
func _verzet_kaart(lay: Dictionary) -> void:
	var spot := Hits.spot("sl_kaart")
	if spot == null:
		return
	spot.y = float(lay.get("kaart_y", spot.y))


## De nummerplaatjes aan de wand: sleepdoelen met hun getal erop.
func _teken_haken(b: Dictionary, lay: Dictionary) -> void:
	var haken := _haken(b)
	var drie := _drie_cijfers(b)
	for i in haken.size():
		var h: Dictionary = haken[i]
		var leeg := _is_leeg(h)
		var w := int(h.get("w", 0))
		var plek := _haak_plek(i, float(lay["dx"]), float(lay["haak_y"]),
			float(lay["schuif"]), int(lay.get("per_regel", 0)))
		var titel := ("hier hoort %d" % w if _spook else "leeg haakje") if leeg else _nr_tekst(w)
		var id := "sl_h%d" % i
		var idx := i
		ctx.hotspots.maak({
			"id": id, "kamer": ctx.kamer,
			"x": plek["x"], "z": plek["z"], "y": plek["y"],
			# `midden` + `vast`: het plaatje staat precies op zijn mikpunt en
			# wijkt nooit.  De rij ÍS de som (de kaart schrijft haar alleen na),
			# dus ze hoort bij de vaste laag: de kaart kiest eerst, de rij daarna
			# en al het andere gaat eromheen.  Een band per plaatje laten kiezen
			# trekt de rij juist uit elkaar — elk plaatje kiest dan zijn eigen
			# band, en dan is de rekenrij geen rij meer.  Dat de rij van geen
			# enkel voorwerp iets afdekt is de taak van `_opbouw`.
			"kind": "drop", "drop": DROP, "data": {"i": idx}, "op": "midden",
			"vast": true, "prio": 12, "titel": titel,
			"icoon": "🔑" if not str(h.get("sleutel", "")).is_empty() else "",
			"label": (str(w) if (_spook or not leeg) else "?"),
			"aan": func(_s) -> void: _tik_haak(idx),
			"val": func(_lading, _data) -> void: _hang(idx),
		})
		_kleur_haak(id, leeg and _spook, _licht == i or _buren.has(i), drie)


## Het lichtje op een plaatje: aangetikt of buurman van een misser.  Een
## spookcijfer van Els staat er lichter op — dat is de `hotspook` van de HTML.
func _kleur_haak(id: String, spook: bool, licht: bool, drie: bool) -> void:
	var spot := Hits.spot(id)
	if spot == null or not is_instance_valid(spot.knoop):
		return
	var knop := spot.knoop as Button
	if knop == null:
		return
	knop.modulate = Color(1, 1, 1, 0.55) if spook else Color(1, 1, 1, 1)
	if licht:
		knop.add_theme_stylebox_override("normal",
			UiThema.vulling(UiThema.vlak(UiThema.ZON, 16, 2, UiThema.WIT), 8, 6))
		knop.add_theme_stylebox_override("hover",
			UiThema.vulling(UiThema.vlak(UiThema.ZON, 16, 2, UiThema.WIT), 8, 6))
	else:
		knop.remove_theme_stylebox_override("normal")
		knop.remove_theme_stylebox_override("hover")
	if drie:
		knop.add_theme_font_size_override("font_size", maxi(UiThema.VLOER, Ui.maten["klein"] - 1))


## De sleutel bij zijn poot: de sleepbron.  Zolang de gast nog onderweg is naar
## de balie wacht hij op de sleutelplek; zodra de gast er staat schuift hij mee
## en weet de knoppenlaag welke plek ze vrij moet laten.
func _teken_sleutel(s: Dictionary) -> void:
	if s.is_empty():
		return
	var id := str(s.get("gast", ""))
	var nummer := int(s.get("nummer", 0))
	ctx.hotspots.bron(_gast_punt(id, _plek(0.675, 0.975)), {
		"id": "sl_key", "icoon": "🔑", "aantal": nummer, "hoog": _hoog(0.05),
		"prio": 12, "op": "onder", "kamer": ctx.kamer,
		"titel": "de sleutel van %s: %s" % [str(s.get("naam", "")), _nr_tekst(nummer)],
		"sleep": DROP, "drop": "", "data": {"nummer": nummer},
		"volg": _volg_gast(id),
		"tik": func(_s) -> void: _wijs_aan(),
	})


## Het wolkje boven de kop van de gast: pictogram, nummer én woorden in
## hetzelfde wolkje (HOTEL.md §9).
func _teken_wolk(s: Dictionary, lay: Dictionary) -> void:
	if s.is_empty():
		return
	var id := str(s.get("gast", ""))
	var wacht := _gast_punt(id, _plek(0.75, 0.85))
	ctx.ui.wolk({
		"id": "sl_tag", "kamer": ctx.kamer, "hoog": float(lay.get("wolk_y", DIER_HOOG)),
		"x": wacht["x"], "z": wacht["z"],
		"icoon": "🔑", "getal": int(s.get("nummer", 0)),
		"tekst": "kijk bij de buren" if not _buren.is_empty() else "hang mij op",
		"klas": "hulp" if not _buren.is_empty() else "", "prio": 10,
		"volg": _volg_gast(id),
	})


## Buurvrouw Els: pas na twee pogingen, en ze legt spookcijfers neer.
func _teken_els() -> void:
	if int(_p.get("missers", 0)) < 2 or bool(_p.get("klaar", false)):
		return
	var plek := _plek(0.25, 0.975)
	ctx.hotspots.maak({
		"id": "sl_els", "kamer": ctx.kamer, "x": plek.x, "z": plek.y,
		"y": _hoog(0.075), "op": "onder", "icoon": "🩺", "label": "Els",
		"klas": "hotwolk hulp", "prio": 8,
		"titel": "buurvrouw Els doet het voor",
		"aan": func(_s) -> void: _hulp(),
	})


## Waar een gast staat, elke beurt opnieuw — met zijn eigen plaatrechthoek, zodat
## de knoppenlaag hem heel laat (world.md §2.10 doet dit voor de naamplaatjes).
##
## Loopt hij op dit moment in een ANDERE kamer (hij komt nog aan de balie aan, of
## hij is net op weg naar zijn bed), dan blijft het wolkje staan waar het stond
## in plaats van met hem mee te verhuizen.  Dat is geen smaakkwestie: een hotspot
## in een andere kamer is onzichtbaar, en een onzichtbare hotspot krijgt van de
## knoppenlaag geen maat — de zin van het wolkje viel dan letter voor letter
## naast het scherm (gemeten in de browserproef, 1024 x 768).
func _volg_gast(id: String) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null or d.kamer != ctx.kamer:
			return {}
		return {"x": d.x, "z": d.z, "kamer": ctx.kamer, "vlak": World.vlak_van_dier(id)}


## De plek van een gast in DEZE kamer; staat hij er niet, dan de wachtplek.
func _gast_punt(id: String, terug: Vector2) -> Dictionary:
	var d = ctx.wereld.dier(id)
	if d == null or d.kamer != ctx.kamer:
		return {"x": terug.x, "z": terug.y, "kamer": ctx.kamer}
	return {"x": d.x, "z": d.z, "kamer": ctx.kamer}


## De plaatjes met het lampje boven de deuren in de gang: één per kamer, met de
## nummers van de sleutels die daar zijn opgehangen.
func _deur_plaatjes() -> void:
	var gang := Rooms.get_kamer("gang")
	if gang == null:
		return
	var per: Dictionary = {}
	for s in _sleutels():
		var sl: Dictionary = s
		if not bool(sl.get("op", false)):
			continue
		var g: Dictionary = ctx.state.gast_van(str(sl.get("gast", "")))
		if g.is_empty() or str(g.get("kamer", "")).is_empty():
			continue
		var kamer := str(g["kamer"])
		if not per.has(kamer):
			per[kamer] = {"nrs": [], "namen": []}
		(per[kamer]["nrs"] as Array).append(str(int(sl.get("nummer", 0))))
		(per[kamer]["namen"] as Array).append(str(sl.get("naam", "")))
	for naar in gang.deur_punten.keys():
		var dp: Dictionary = gang.deur_punten[naar]
		var id := "sl_deur_%s" % str(naar)
		if not per.has(naar):
			ctx.ui.getal_tag({"x": 0.0, "z": 0.0}, null, {"id": id, "kamer": "gang"})
			continue
		var q: Dictionary = per[naar]
		ctx.ui.getal_tag({"x": float(dp.get("x", 0.0)), "z": float(dp.get("z", 0.0))},
			"💡 " + " · ".join(q["nrs"]),
			{"id": id, "kamer": "gang", "y": 26.0, "prio": 6,
			"vlak": World.vlak_van_deur("gang", str(naar)),
			"titel": "%s slaapt hier: %s" % [" en ".join(q["namen"]), " en ".join(q["nrs"])]})

# ------------------------------------------------------------------- spelen

## Een tik op de sleutel of op een plaatje leest het getal voor.
func _wijs_aan() -> void:
	var s := _sleutel_nu()
	if s.is_empty():
		return
	var nummer := int(s.get("nummer", 0))
	Ui.spreek(_verdieping(nummer) if str(_p.get("variant", "")) == "kamers" else str(nummer))


func _tik_haak(i: int) -> void:
	var b := _bord_nu()
	var haken := _haken(b)
	if i < 0 or i >= haken.size():
		return
	var h: Dictionary = haken[i]
	if _is_leeg(h) and not _sleutel_nu().is_empty():
		_hang(i)
		return
	# een plaatje met een getal: tikken laat het oplichten en leest het voor
	_licht = i
	_buren = []
	_buur_gat = -1
	_teken()
	Ui.spreek(_verdieping(int(h.get("w", 0))) if str(_p.get("variant", "")) == "kamers"
		else str(int(h.get("w", 0))))


## De sleutel ophangen: slepen naar een haakje of erop tikken met de sleutel in
## je hand.  Bezet of het verkeerde getal is een misser — nooit een straf.
func _hang(i: int) -> void:
	var b := _bord_nu()
	var haken := _haken(b)
	var s := _sleutel_nu()
	if s.is_empty() or i < 0 or i >= haken.size():
		return
	var h: Dictionary = haken[i]
	if not str(h.get("sleutel", "")).is_empty():
		_mis(i)
		return
	if int(h.get("w", 0)) == int(s.get("nummer", 0)):
		_goed(i)
	else:
		_mis(i)


func _goed(i: int) -> void:
	var b := _bord_nu()
	var h: Dictionary = _haken(b)[i]
	var s := _sleutel_nu()
	var gast := str(s.get("gast", ""))
	var nummer := int(s.get("nummer", 0))
	h["sleutel"] = gast
	s["op"] = true
	_buren = []
	_buur_gat = -1
	_licht = i
	_spook = false
	_tip = ""
	ctx.snd.munt()
	ctx.snd.ja()
	var nu := Time.get_ticks_msec()
	ctx.state.tel(int(s.get("mis", 0)) == 0, maxi(0, nu - int(_p.get("t0", nu))))
	_p["t0"] = nu
	_naar_kamer(gast, true)
	_p["nu"] = int(_p.get("nu", 0)) + 1
	var volgende := _sleutel_nu()
	_teken()
	# de gast die net zijn sleutel kreeg loopt weg: kort wolkje mee
	var afscheid := _gast_punt(gast, _plek(0.75, 0.85))
	ctx.ui.wolk({"id": "sl_af", "kamer": ctx.kamer, "hoog": 40.0, "prio": 13,
		"x": afscheid["x"], "z": afscheid["z"],
		"icoon": "💤", "getal": nummer, "tekst": "naar mijn kamer", "klas": "goed",
		"volg": _volg_gast(gast)})
	_wolk_weg_straks()
	if not volgende.is_empty():
		_haal_gast()
		State.bewaar()
		return
	_klaar()


func _wolk_weg_straks() -> void:
	if not await na(WACHT_AF):
		return
	ctx.ui.wolk_weg("sl_af")
	ctx.wereld.vuil()


func _mis(i: int) -> void:
	var b := _bord_nu()
	var s := _sleutel_nu()
	_p["missers"] = int(_p.get("missers", 0)) + 1
	if not s.is_empty():
		s["mis"] = int(s.get("mis", 0)) + 1
	_licht = -1
	_buren = _buren_van(b, i)
	_buur_gat = i
	ctx.snd.zacht()          # de zachte "nee", nooit een zoemer (F5)
	ctx.snd.terug()          # de sleutel glijdt terug
	_teken()
	_wiebel(i)
	State.bewaar()


## Het haakje wiebelt even; de sleutel blijft in je hand.  In rustmodus staat
## het stil, net als de CSS-animatie in de HTML.
func _wiebel(i: int) -> void:
	if ctx.wereld.rust() or Ui.rust_modus():
		return
	var spot := Hits.spot("sl_h%d" % i)
	if spot == null or not is_instance_valid(spot.knoop):
		return
	var knop := spot.knoop
	knop.pivot_offset = knop.size * 0.5
	var tw := knop.create_tween()
	tw.tween_property(knop, "rotation", 0.10, 0.06)
	tw.tween_property(knop, "rotation", -0.10, 0.10)
	tw.tween_property(knop, "rotation", 0.0, 0.08)


## Buurvrouw Els legt het goede getal als spookcijfer óp elk leeg haakje en zet
## de sprong in het hulpregeltje van de kaart.
func _hulp() -> void:
	var b := _bord_nu()
	var label := str(b.get("label", ""))
	_spook = true
	_tip = "om en om" if (label == "oneven" or label == "even") \
		else "+ %d" % int(b.get("stap", 1))
	ctx.state.zet_gezien("sleutels_els")
	ctx.snd.brief()
	_teken()


func _klaar() -> void:
	_p["klaar"] = true
	_af = true
	ctx.taak_klaar(TAAK, {"sterren": 1})
	ctx.snd.tover()
	State.bewaar()
	_teken()
	# de finale in de gang: daar hangen de plaatjes met de lampjes boven de deuren
	ctx.wereld.naar("gang")
	Hotel.render()
	var kist: Dictionary = ctx.wereld.mik("kist", "gang")
	ctx.ui.wolk({"id": "sl_klaar", "kamer": "gang",
		"x": float(kist.get("x", 0.0)), "z": float(kist.get("z", 0.0)),
		"hoog": 24.0, "icoon": "⭐", "tekst": "alle sleutels hangen",
		"klas": "goed", "prio": 13,
		"tik": func(_s) -> void: ctx.sluit()})
	if not await na(WACHT_EIND):
		return
	if _af:
		ctx.sluit()

# ------------------------------------------------------------------- kader

## Kantelt het scherm, dan is het kader anders en hoort de opstelling opnieuw
## gekozen te worden — net als het cijferpad van `Ui` wachten we tot de wereld
## haar nieuwe maat heeft genomen (220 ms, games-a.md §8 punt 8).
func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	_kader_teller += 1
	var mijn := _kader_teller
	if not await na(WACHT_KADER):
		return
	if mijn == _kader_teller and not _p.is_empty():
		_teken()

# ------------------------------------------------------- voor de speeltest

## De stand van deze beurt, zodat een test hem kan nalezen zonder in de
## interne velden te graaien.
func debug() -> Dictionary:
	return {"bord": _p, "opbouw": _lay, "spook": _spook, "tip": _tip,
		"licht": _licht, "buren": _buren, "buren_tekst": _buren_tekst(),
		"rij_tekst": _rij_tekst(_bord_nu()), "bord_plek": _bord_plek}
