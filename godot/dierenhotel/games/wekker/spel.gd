extends MiniGame
## G2 — DE WEKKERDIENST (games-b.md §2, architecture.md §6.5).
##
## Alles gebeurt in de gang, er komt geen rekenblad naast de kamer:
##   * aan de achterwand hangt de grote halklok — los decor van een eigen
##     voxelmodel (`wekker_klok`) met een wijzerplaat, twaalf uurstreepjes en
##     TWEE wijzers die echt met de parameters meedraaien; elke tik zet nieuwe
##     params, dus de motor bakt precies één plaatje opnieuw;
##   * op de klok staat zijn eigen tijd als cijfer (`ctx.ui.getal_tag`);
##   * onder de klok hangt één sommenkaart met de wekkerwens van de gast, de
##     stand van de klok als sombalk en één knoppenstrook met pictogram én
##     woord;
##   * bij het slapende dier hangt zijn eigen wekkerkaartje (💤);
##   * goed gezet: de klok slaat, het dier wordt wakker (houding blij +
##     ☀-wolkje) en er valt een ster;
##   * verkeerd gezet: het dier slaapt door, de kaart zegt wat de klok NU zegt
##     en wat de gast WIL, en de wijzers blijven staan zodat je verder kunt
##     draaien.  Nooit terugzetten, nooit rood, geen timer (F5).
##
## HULPLADDER — hier wijkt het spel bewust af van de standaard (K3): de
## eerste misser geeft de gewone hulpregel, de TWEEDE geeft de telladder
## (uur voor uur van nu naar de wektijd), en pas bij de DERDE misser komen
## de spookwijzers (architecture.md §13, Q-X3-6; HOTEL.md §5).
##
## Wat de HTML-versie met eigen pixeldrempels deed (`kortWoord`, 370/400 px,
## `strookNakijken` na 140 ms) doet de motor nu synchroon: `UiKeuzes` meet zich
## vóór de eerste tekening en kiest zelf het korte woord (architecture.md §4.4).
## Elk woord staat hieronder nog steeds letterlijk in `kort`.

const KAMER := "gang"
const MODEL := "wekker_klok"      ## §13 Q-X1-11: een spelmodel heet <spel>_<naam>
const DECOR := "klok"
const HAAK_TERUG := {"n": "kist", "x": 114, "z": 14}
const RUST_KLOK := "rust_wk_klok"   ## de klok aan de muur zolang er niet gespeeld wordt
const RUST_UUR := 7                 ## ... en hij wijst het wekkertijdstip van het hotel

## Plek van de klok: aan de wand z = 0, tussen twee deuren.
const KX := 48.0
const KZ := 1.0
const CY := 34                    ## hart van de wijzerplaat, voxels boven de vloer

## Stralen op het SCHERM (games-b.md §2.5).
const R_PLAAT := 19.0
const R_RAND := 22.0
const R_KAST := 25.0
const R_STREEP := 16.5
const R_UUR := 10.0
const R_MIN := 15.5

const KL_KAST := Color("#7E6255")
const KL_RAND := Color("#E8C58E")
const KL_PLAAT := Color("#FFF7E4")
const KL_STREEP := Color("#7E6255")
const KL_UUR := Color("#4A3B33")
const KL_MIN := Color("#C9788F")
const KL_HART := Color("#E0A86B")
const KL_BEL := Color("#E8C58E")
const KL_SPOOK_U := Color("#9A8578")
const KL_SPOOK_M := Color("#D9A0B0")

## Kindtekst, letterlijk (games-b.md §2.10).  De suite leest ze hiervandaan.
const T_NAAM := "Wekkerdienst"
const T_LABEL := "Wekker"
const T_ICOON := "⏰"
const T_TAAK := "Wekker zetten"
const T_LEEG := "nog geen gasten"
const T_ZET := "Zet de klok"
const T_ZET_MORGEN := "Zet de klok voor morgen"
const T_DUUR2 := "Hoe laat is hij wakker?"
const T_STROOK := "draai de klok"
const T_STROOK_DUUR := "hoe laat wordt hij wakker?"
const T_HULP_BEGIN := "💛 draai tot de klok klopt"
const T_HULP0 := "💛 draai eerst aan de wijzers"
const T_HULP1 := "💛 draai nog wat verder"
const T_HULP_LAD := "💛 nog %d uur"
## K3: de tekst van games-b.md §2.10 was "👻 de spookwijzers wijzen mee";
## die past niet op één regel van de kaart (185 px, hulp ~161 px) en liet de
## kaart met 27 px groeien.  Ingekort op verzoek van de eigenaar (2026-09-21)
## zodat de kaarthoogte over alle treden gelijk blijft; de spec mag hiervan
## op de hoogte worden gebracht.
const T_HULP2 := "👻 spoken wijzen mee"
const T_SLAAPT_NOG := "slaapt nog"
const T_NOG_NIET := "nog niet"
const T_GOEDEMORGEN := "goedemorgen"
const T_AF := "allemaal gewekt"
const T_PLAAT := "de wijzerplaat"
const T_UUR := "uur erbij"
const T_UUR_K := "uur"
const T_KWARTIER := "kwartier erbij"
const T_KWARTIER_K := "kwartier"
const T_VIJF := "5 minuten erbij"
const T_VIJF_K := "5 min"
const T_KLAAR := "Klaar"

const RIJ_MAX := 3                ## een ronde blijft kindermaat
const LEEG_S := 1.8               ## geen gasten: wolkje, dan zichzelf sluiten
const JA_S := 0.22                ## de gong, en 220 ms later "ja"
const VOLGENDE_S := 2.2

var _s: Dictionary = {}           ## de beurt; leeft in ctx.data()["stand"]
var _kaart: Ui.Kaart = null
var _kader_af: Callable = Callable()
var _t0 := 0                      ## begin van deze beurt, voor state.tel()
var _zeg := ""                    ## wat er nu bij de gast staat

# ---------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	# Het icoontje hoort ÓP de klok, maar het register zoekt de plek van een
	# hotspot alleen bij losse dingen, slots en het VASTE decor van de kamer;
	# de klok is los decor.  De knop hangt dus aan een vast stuk in de gang en
	# schuift met dx/dz naar de klok — en die plek komt uit `Rooms`, zodat het
	# icoontje meeschuift als de kist ooit verhuist.
	#
	# ... en zolang er niet gespeeld wordt HANGT die klok er ook (eigenaar,
	# 2026-09-23: "Dan hangt elk spel aan iets wat je echt ziet"; en "⏰ Wekker"
	# hing tot dan op het pootjesschilderij, alsof dat de wekker was).  Het
	# register zet `rust_wk_klok` neer zolang er geen spel loopt en het
	# icoontje hangt eraan (`hotspot.rust`); bij de start maakt hij plaats
	# voor de klok van de beurt.
	var haak := _haak_plek()
	return {
		"naam": T_NAAM,
		"kamer": KAMER,
		"hotspot": {
			"obj": str(haak["n"]),
			"dx": int(KX) - int(haak["x"]),
			"dz": int(KZ) - int(haak["z"]),
			"hoog": 26, "icoon": T_ICOON, "label": T_LABEL,
			"rust": RUST_KLOK,
		},
		"modellen": {MODEL: Callable(get_script(), "_klok_model")},
		"rust": [{"id": RUST_KLOK, "model": MODEL, "x": KX, "z": KZ, "ver": true,
			"params": {"uur": RUST_UUR, "min": 0}}],
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"stub": false,
		"taak": {
			"id": "wekker", "icoon": T_ICOON, "prio": 3, "tekst": T_TAAK,
			# Alleen autoloads en letterlijke waarden: deze Callable wordt
			# bewaard nadat het proefexemplaar van de scene is vrijgegeven.
			"wanneer": func(s: Dictionary) -> bool:
				var gasten: Array = s.get("gasten", [])
				if gasten.is_empty():
					return false
				if str(s.get("ronde", "")) == "avond":
					return true
				for g in gasten:
					if str(g.get("bed", "")).is_empty():
						continue
					if World.slaapt(str(g.get("id", ""))):
						return true
				return false,
		},
	}

## Het vaste decorstuk waar het icoontje aan hangt: het eerste stuk `kist`,
## anders het eerste decorstuk, anders (114, 14).  Zelfde zoekorde als het
## register zelf gebruikt.
static func _haak_plek() -> Dictionary:
	var r := Rooms.get_kamer(KAMER)
	if r == null:
		return HAAK_TERUG
	var eerste: Dictionary = {}
	for stuk in r.decor:
		if typeof(stuk) != TYPE_DICTIONARY or not stuk.has("n"):
			continue
		if eerste.is_empty():
			eerste = stuk
		if str(stuk["n"]) == "kist":
			return {"n": "kist", "x": int(stuk.get("x", 114)), "z": int(stuk.get("z", 14))}
	if eerste.is_empty():
		return HAAK_TERUG
	return {"n": str(eerste["n"]), "x": int(eerste.get("x", 114)),
		"z": int(eerste.get("z", 14))}

# --------------------------------------------------------------- start / stop

func start(_c: SpelCtx) -> void:
	# Het model is STATISCH en wordt bij elke start opnieuw aangemeld: een
	# Callable naar een gewone methode houdt de spelknoop vast, en die wordt na
	# `stop()` vrijgegeven — het volgende bakje zou dan op een dode verwijzing
	# vallen.  Een statische functie hangt aan het script, niet aan de knoop.
	Art.registreer_model(MODEL, _klok_model)
	_kaart = null
	var rij := rijtje()
	if rij.is_empty():
		_geen_gasten()
		return
	var d := ctx.data()
	var dag := int(ctx.state.s["dag"])
	var n := maxi(1, int(ctx.state.n_gasten()))
	var band := Sommen.Wekker.band_klem(int(ctx.state.band()))
	var oud := _lees_stand(d.get("stand", null))
	# Het dier dat het kind op de spelbalk koos wordt als eerste gewekt
	# (eigenaar, 2026-09-23).  Een ronde waarin het al aan de beurt was of is
	# gaat gewoon door; elke andere ronde is gewoon niet afgemaakt.
	var wil := ctx.voorkeur(spelers())
	if not wil.is_empty():
		rij = _rij_vanaf(wil)
	# Een belofte overleeft geen herlaad: de stand komt altijd uit ctx.data().
	# Hergebruiken mag alleen als dag, N en band nog kloppen, de beurt niet af
	# is, de gast nog bestaat en het doeluur gezet is (games-b.md §2.11).
	var zelfde := not oud.is_empty() \
		and int(oud.get("dag", -1)) == dag \
		and int(oud.get("N", -1)) == n \
		and int(oud.get("band", -1)) == band \
		and int(oud.get("af", 0)) == 0 \
		and int(oud.get("doelU", 0)) > 0 \
		and not gast_van(str(oud.get("gast", ""))).is_empty() \
		and (wil.is_empty() or _had_zijn_beurt(oud, wil))
	if zelfde:
		_s = oud
		# Na een herlaad slaapt iedereen weer, en de stap `wakker` hoort bij
		# een tijdje dat niet bewaard is: terug naar het zetten.
		_s["slaapt"] = slaapt_gast(gast_van(str(_s["gast"])))
		if str(_s.get("stap", "")) == "wakker":
			_s["stap"] = "zet"
		if (_s.get("rij", []) as Array).is_empty():
			_s["rij"] = _ids_van(rij)
	else:
		var eerste: Dictionary = rij[0]
		_s = _nieuwe_beurt(n, band, dag, 0, str(eerste["id"]), slaapt_gast(eerste))
		_s["rij"] = _ids_van(rij)
	d["stand"] = _s
	ctx.speelt(str(_s.get("gast", "")))
	_t0 = Time.get_ticks_msec()
	if ctx.wereld.kamer_nu() != KAMER:
		ctx.wereld.naar(KAMER)
	teken(true)
	# Kantelen maakt het kader smaller of breder; het lege tagje op de
	# wijzerplaat is in css-px gemeten en hoort dan opnieuw gelegd te worden.
	# De knoppenstrook meet zichzelf (architecture.md §4.4), dus daar hoeft dit
	# spel niets meer voor te doen.
	_kader_af = ctx.ui.op_kader(_op_kader)
	if not ctx.wereld.kamer_veranderd.is_connected(_op_kamer):
		ctx.wereld.kamer_veranderd.connect(_op_kamer)
	State.bewaar()
	print("[probe] spel=start id=", ctx.id, " kamer=", ctx.kamer,
		" band=", band, " stap=", str(_s.get("stap", "")))

func stop() -> void:
	if _kader_af.is_valid():
		_kader_af.call()
		_kader_af = Callable()
	if ctx == null:
		return
	if ctx.wereld.kamer_veranderd.is_connected(_op_kamer):
		ctx.wereld.kamer_veranderd.disconnect(_op_kamer)
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	# Al het eigen decor weg, ook zonder de knoppenlaag (games-b.md §2.11).
	ctx.wereld.decor_wis_eigenaar(ctx.id)
	ctx.hotspots.wis_alles()
	ctx.hotspots.laat()
	_s = {}

func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	if not actief or _s.is_empty() or int(_s.get("af", 0)) != 0:
		return
	_plaat_vrij()
	_hang_kaart()

func _geen_gasten() -> void:
	var plek: Dictionary = ctx.wereld.mik(str(_haak_plek()["n"]), KAMER)
	ctx.ui.wolk({"id": "wk_leeg", "kamer": KAMER,
		"x": float(plek.get("x", 114.0)), "z": float(plek.get("z", 14.0)),
		"hoog": 20.0, "icoon": "🛏", "tekst": T_LEEG})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg("wk_leeg")
	ctx.sluit()

# ------------------------------------------------------------------ de gasten

## `rijtje()` — eerst alle gasten met een bed die slapen, is dat leeg dan alle
## gasten met een bed, is dat leeg dan alle gasten.  Daarvan de eerste drie.
func rijtje() -> Array:
	return _wekbaar().slice(0, RIJ_MAX)

## Dezelfde lijst, zonder de grens van drie: iedereen die vandaag gewekt kan
## worden, in check-in volgorde.
func _wekbaar() -> Array:
	var alle: Array = ctx.state.s["gasten"]
	var l: Array = []
	for g in alle:
		if not str(g.get("bed", "")).is_empty() and slaapt_gast(g):
			l.append(g)
	if l.is_empty():
		for g in alle:
			if not str(g.get("bed", "")).is_empty():
				l.append(g)
	if l.is_empty():
		l = alle.duplicate()
	return l

## Wie als eerste gewekt mag worden als het kind zelf het dier kiest (de
## spelbalk): iedereen die gewekt kan worden, in check-in volgorde.
func spelers() -> Array:
	return _ids_van(_wekbaar())

## Het rijtje van een ronde die bij `id` begint en dan rond gaat: het gekozen
## dier eerst, daarna de volgende slapers, hooguit drie.
func _rij_vanaf(id: String) -> Array:
	var l := _wekbaar()
	var i := _ids_van(l).find(id)
	if i > 0:
		l = l.slice(i) + l.slice(0, i)
	return l.slice(0, RIJ_MAX)

## Was `id` in de bewaarde ronde al aan de beurt, of is hij het nu?  Dan gaat
## die ronde gewoon verder.
func _had_zijn_beurt(oud: Dictionary, id: String) -> bool:
	var plek := (oud.get("rij", []) as Array).find(id)
	return plek >= 0 and plek <= int(oud.get("idx", 0))

func _ids_van(rij: Array) -> Array:
	var uit: Array = []
	for g in rij:
		uit.append(str(g.get("id", "")))
	return uit

## Het rijtje van DEZE ronde, zoals het bij de start werd vastgelegd, ontdaan
## van gasten die intussen zijn uitgecheckt.
##
## AFWIJKING van games-b.md §2.9, met reden.  De bron roept in `volgende()`
## opnieuw `rijtje()` aan, maar een gast die net gewekt is slaapt niet meer en
## valt daarmee uit dat rijtje — de index schuift op en de volgende slaper wordt
## overgeslagen: van drie gasten worden er twee gewekt.  Het rijtje van de ronde
## staat daarom in de stand, waar het ook een herlaad overleeft.
func ronde_rij() -> Array:
	var uit: Array = []
	for id in (_s.get("rij", []) as Array):
		if not gast_van(str(id)).is_empty():
			uit.append(str(id))
	if uit.is_empty():
		uit = _ids_van(rijtje())
	return uit

func slaapt_gast(g: Dictionary) -> bool:
	if g.is_empty():
		return false
	return bool(ctx.wereld.slaapt(str(g.get("id", ""))))

func gast_van(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for g in (ctx.state.s["gasten"] as Array):
		if str(g.get("id", "")) == id:
			return g
	return {}

func naam_van(id: String) -> String:
	var g := gast_van(id)
	return str(g["naam"]) if not g.is_empty() else "De gast"

# -------------------------------------------------------------------- de beurt

## De getallen komen uit de bevroren generator; dit spel rekent zelf niets uit
## (architecture.md §2.2).
func _nieuwe_beurt(n: int, band: int, dag: int, idx: int, gast: String,
		dutje: bool) -> Dictionary:
	var b: Dictionary = Sommen.Wekker.beurt(band, n, dag, idx)
	b["gast"] = gast
	b["slaapt"] = dutje
	b["missers"] = 0
	# `draaien` telt elke draai aan de wijzers, `gekeurd` de stand van die teller
	# bij de vorige ✅.  Zijn ze gelijk, dan is er sinds de vorige keuring niets
	# veranderd en is een tik op ✅ geen nieuwe poging (R3).
	b["draaien"] = 0
	b["gekeurd"] = 0
	b["ster"] = 0
	b["af"] = 0
	# K3: de hulpregel is nooit leeg — de kaart staat vanaf de eerste tik
	# klaar met wat het kind moet doen.
	b["hulp"] = T_HULP_BEGIN
	_t0 = Time.get_ticks_msec()
	return b

## Wat uit de opslag terugkomt is JSON: elk getal is een float.  Alles wat dit
## spel als int leest wordt hier één keer teruggezet.
func _lees_stand(v) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var uit: Dictionary = {}
	for k in ["dag", "N", "band", "idx", "doelU", "doelM", "u", "m", "duur",
			"missers", "draaien", "gekeurd", "ster", "af"]:
		uit[k] = int(float(v.get(k, 0)))
	uit["stap"] = str(v.get("stap", "zet"))
	uit["gast"] = str(v.get("gast", ""))
	uit["hulp"] = str(v.get("hulp", ""))
	# K3: een oude opslag kan een lege hulpregel hebben; vul die bij, behalve
	# bij een reeds ontwaakte gast — daar hoort geen hulpregel bij.
	if uit["hulp"] == "" and uit["stap"] != "wakker":
		uit["hulp"] = T_HULP_BEGIN
	uit["slaapt"] = bool(v.get("slaapt", false))
	var keuzes: Array = []
	for q in (v.get("keuzes", []) as Array):
		keuzes.append(int(float(q)))
	uit["keuzes"] = keuzes
	var rij: Array = []
	for id in (v.get("rij", []) as Array):
		rij.append(str(id))
	uit["rij"] = rij
	return uit

func stand() -> Dictionary:
	return _s

func _af_nu() -> bool:
	return _s.is_empty() or int(_s.get("af", 0)) != 0

func _bewaar() -> void:
	if ctx != null:
		ctx.data()["stand"] = _s
		State.bewaar()

# ------------------------------------------------------ het model: de halklok

## In één wandvlak (z vast) geldt op het scherm X = 2·dx en Y = dx − 2·dy.  Een
## wijzerplaat die op het SCHERM rond is, is in voxels dus een scheve ellips;
## `_naar_vox` rekent een schermpunt terug naar voxels.  `JsGetal.rond` en niet
## `round`: halven gaan naar +∞, zoals in de bron.
static func _naar_vox(bx: float, by: float) -> Vector2i:
	var dx := bx / 2.0
	return Vector2i(JsGetal.rond(dx), JsGetal.rond((dx - by) / 2.0))

static func _hoek_uur(u: int, m: int) -> float:
	return ((float(posmod(u, 12)) + float(m) / 60.0) / 12.0) * TAU

static func _hoek_min(m: int) -> float:
	return (float(posmod(m, 60)) / 60.0) * TAU

## Een streepje of wijzer onder schermhoek `a` (0 = 12 uur, met de klok mee),
## van straal r0 tot r1; `dik` is de halve breedte in schermpunten.  Een `stap`
## groter dan 1 geeft een STIPPELlijn: zo lezen de spookwijzers als een hint en
## niet als een tweede stel echte wijzers.
static func _streep(v: Array, r0: float, r1: float, a: float, dik: float,
		kl: Color, z: int, stap: float) -> void:
	var s := sin(a)
	var c := cos(a)
	var r := r0
	while r <= r1 + 0.01:
		var t := -dik
		while t <= dik + 0.01:
			var q := _naar_vox(r * s + t * c, -r * c + t * s)
			v.append({"x": q.x, "y": CY + q.y, "z": z, "k": kl})
			t += 0.5
		r += stap

static func _klok_model(p: Dictionary) -> Array:
	var v: Array = []
	var uur := int(p.get("uur", 12))
	var mn := int(p.get("min", 0))
	# kast, rand en wijzerplaat in één ronde: per voxel de schermafstand
	for dx in range(-13, 14):
		var bx := 2.0 * float(dx)
		for dy in range(-19, 20):
			var by := float(dx) - 2.0 * float(dy)
			var d2 := bx * bx + by * by
			if d2 > R_KAST * R_KAST:
				continue
			if d2 > R_RAND * R_RAND:
				v.append({"x": dx, "y": CY + dy, "z": 0, "k": KL_KAST})
				v.append({"x": dx, "y": CY + dy, "z": 1, "k": KL_KAST})
			elif d2 > R_PLAAT * R_PLAAT:
				v.append({"x": dx, "y": CY + dy, "z": 1, "k": KL_RAND})
				v.append({"x": dx, "y": CY + dy, "z": 2, "k": KL_RAND})
			else:
				v.append({"x": dx, "y": CY + dy, "z": 1, "k": KL_PLAAT})
	# twee belletjes bovenop: dit is de wekker van het hotel.  Ze staan op
	# SCHERMhoogte even hoog, anders zet de scheve projectie ze schuin.
	var q := _naar_vox(-13.0, -23.0)
	var q2 := _naar_vox(13.0, -23.0)
	ArtVorm.bx(v, q.x - 1, CY + q.y, 1, 3, 3, 2, KL_BEL)
	ArtVorm.bx(v, q2.x - 1, CY + q2.y, 1, 3, 3, 2, KL_BEL)
	# twaalf uurstreepjes; 12, 3, 6 en 9 als streepje, de rest een stipje
	for i in range(1, 13):
		var a := float(i) * PI / 6.0
		if i % 3 == 0:
			_streep(v, R_STREEP - 2.5, R_STREEP + 0.5, a, 0.5, KL_STREEP, 2, 0.5)
			continue
		var s := _naar_vox(R_STREEP * sin(a), -R_STREEP * cos(a))
		v.append({"x": s.x, "y": CY + s.y, "z": 2, "k": KL_STREEP})
	# spookwijzers eerst, zodat de echte wijzers er overheen komen
	if p.get("spookU", null) != null:
		var su := int(p.get("spookU", 12))
		var sm := int(p.get("spookM", 0))
		_streep(v, 2.0, R_UUR, _hoek_uur(su, sm), 1.0, KL_SPOOK_U, 2, 1.5)
		_streep(v, 2.0, R_MIN, _hoek_min(sm), 0.5, KL_SPOOK_M, 2, 1.5)
	_streep(v, 0.0, R_UUR, _hoek_uur(uur, mn), 1.0, KL_UUR, 2, 0.5)
	_streep(v, 0.0, R_MIN, _hoek_min(mn), 0.5, KL_MIN, 2, 0.5)
	ArtVorm.bx(v, -1, CY - 1, 2, 2, 2, 1, KL_HART)
	return v

# ------------------------------------------------- de klok in de wereld zetten

func klok_params() -> Dictionary:
	var p := {"uur": int(_s.get("u", 12)), "min": int(_s.get("m", 0))}
	# Hulpladder: vanaf de TWEEDE misser wijzen bleke spookwijzers mee, zowel
	# op de gewone zetkaart als op de kaart na een misser (HOTEL.md §5).  Ze
	# horen bij twee ECHTE pogingen: er moet ook twee keer aan de wijzers
	# gedraaid zijn, anders verklapt tikken alleen al de wektijd (R3).  Dat
	# sluit ook de zijdeur van de tijdsduurvraag, die missers optelt zonder dat
	# er ooit een wijzer bewoog.
	var stap := str(_s.get("stap", ""))
	if int(_s.get("missers", 0)) >= 3 and int(_s.get("draaien", 0)) >= 2 \
			and (stap == "zet" or stap == "mis"):
		p["spookU"] = int(_s.get("doelU", 12))
		p["spookM"] = int(_s.get("doelM", 0))
	return p

func _zet_klok() -> void:
	ctx.wereld.decor(KAMER, {"id": DECOR, "model": MODEL, "x": KX, "z": KZ,
		"ver": true, "params": klok_params()})
	var w := tijd_woord(int(_s.get("u", 12)), int(_s.get("m", 0)))
	# het cijfer ÓP de klok (HOTEL.md §9), net boven de kast
	ctx.ui.getal_tag(DECOR, w, {"id": "wk_tijd", "kamer": KAMER, "y": 48.0,
		"prio": 12, "titel": "de klok staat op %s" % w})
	_plaat_vrij()

## De wijzerplaat vrijhouden (games-b.md §2.6, bindend).  De deurknoppen van
## het hotel hangen in de gang precies in de band waar de klok hangt; gemeten
## stonden "Kamer 1" en "Kamer 2" ÓP de wijzerplaat.  Dit spel legt daarom één
## LEEG tagje van zichzelf precies op de plaat: niet te zien en niet te tikken,
## maar het reserveert de cellen.  Zodra het spel stopt staan de deurknoppen
## weer waar ze willen.
##
## CONTRACTGAT.  `Hits` heeft geen anker dat een element met opzet ÓP zijn eigen
## voorwerp zet: `midden` tilt zich juist van dat voorwerp af (`_bezet_voor`,
## "de som hangt boven het bakje"), en zonder eigen `vlak` zoekt `Hits` er zelf
## een voorwerp bij op positie.  Dat is voor elke andere kaart precies goed, maar
## dit tagje moet juist ÓP de klok blijven liggen.  Er is geen manier om "ik heb
## geen voorwerp" te zeggen; het tagje geeft daarom een rechthoekje van 1 x 1
## buiten het kader mee.  Zie het verslag onder "Contract gaps".
const GEEN_VLAK := Rect2(Vector2(-16.0, -16.0), Vector2(1.0, 1.0))

func _plaat_vrij() -> String:
	var k := float(ctx.wereld.schaal().get("k", 1.0))
	var d := maxf(20.0, float(JsGetal.rond(2.0 * R_RAND * k)))
	var hoog: float = ctx.wereld.px_per_hoogte()
	var vloer: float = ctx.wereld.mik_punt(KX, KZ, 0.0).y
	var mik_y := vloer - float(CY) * hoog
	var boven := mik_y - d * 0.5
	var onder := mik_y + d * 0.5
	# Op een laag liggend kader snijdt de camera de bovenkant van de kast weg en
	# wordt het cijfer op de klok tegen de bovenrand geklemd.  De reservering
	# blijft daar ónder: wat toch niet te zien is hoeft niet vrijgehouden.
	var t := Hits.spot("wk_tijd")
	if t != null and is_instance_valid(t.knoop):
		boven = maxf(boven, float(Hits.RAND) + t.knoop.get_combined_minimum_size().y)
	onder = maxf(onder, boven + 20.0)
	var id := ctx.hotspots.maak({"id": "wk_plaat", "kind": "tag", "kamer": KAMER,
		"x": KX, "z": KZ, "y": (vloer - (boven + onder) * 0.5) / maxf(hoog, 0.001),
		"op": "midden", "prio": 15,
		"titel": T_PLAAT, "maat": Vector2(d, onder - boven),
		"vlak": GEEN_VLAK})
	# `UiGetalTag` tekent een geel pilletje; dit tagje mag niets laten zien.
	# Onzichtbaar via `modulate`, niet via `visible`: `Hits.plaats()` zet de
	# zichtbaarheid elke tekening zelf.
	var s := Hits.spot(id)
	if s != null and is_instance_valid(s.knoop):
		s.knoop.modulate = Color(1.0, 1.0, 1.0, 0.0)
	return id

# ------------------------------------------------------------------ de kaart

func tijd_woord(u: int, m: int) -> String:
	return Sommen.Wekker.tijd_woord(u, m)

## De zin blijft binnen het budget van F4: hooguit 8 woorden EN 40 tekens, en
## op één regel past ongeveer 34 tekens.  Met de langste naam en de langste
## tijd loopt "... wil om ... op" daar net over; dan zegt de kaart het korter.
## K3: na een misser zegt de kaart dezelfde wens nog eens — de klokstand
## staat in de balk, niet in de zin; de kaart hoeft niet te herhalen.
func zin_zet() -> Array:
	var naam := naam_van(str(_s.get("gast", "")))
	var wil := tijd_woord(int(_s.get("doelU", 12)), int(_s.get("doelM", 0)))
	var een := "%s wil om %s op" % [naam, wil]
	if een.length() > 34:
		een = "Wek %s om %s" % [naam, wil]
	return [een, T_ZET if bool(_s.get("slaapt", false)) else T_ZET_MORGEN]

func zin_duur() -> Array:
	return ["%s slaapt nog %d uur" % [naam_van(str(_s.get("gast", ""))),
		int(_s.get("duur", 1))], T_DUUR2]

## De sombalk is de stand van de klok, die live meeloopt terwijl je draait.
## K3: de balk staat altijd — ook na een misser is "nu: ..." de anker die het
## kind vertelt waar de klok staat ten opzichte van de gewenste tijd.
func som_balk() -> String:
	return "nu: %s" % tijd_woord(int(_s.get("u", 12)), int(_s.get("m", 0)))

func knoppen() -> Array:
	var band := int(_s.get("band", 3))
	var l: Array = [{"id": "uur", "icoon": "🕐", "tekst": T_UUR, "kort": T_UUR_K,
		"kies": func(_k: String) -> void: draai(60)}]
	if band >= 4:
		l.append({"id": "kwartier", "icoon": "🕒", "tekst": T_KWARTIER,
			"kort": T_KWARTIER_K, "kies": func(_k: String) -> void: draai(15)})
	if band >= 5:
		l.append({"id": "vijf", "icoon": "🕧", "tekst": T_VIJF, "kort": T_VIJF_K,
			"kies": func(_k: String) -> void: draai(5)})
	l.append({"id": "klaar", "icoon": "✅", "tekst": T_KLAAR,
		"kies": func(_k: String) -> void: klaar_tik()})
	return l

func tijd_knoppen() -> Array:
	var l: Array = []
	for q in (_s.get("keuzes", []) as Array):
		var u := int(q)
		l.append({"id": "u%d" % u, "icoon": Sommen.Wekker.uur_ico(u, 0),
			"tekst": "%d uur" % u, "kies": func(_k: String) -> void: kies_tijd(u)})
	return l

func _teken_kaart(nieuw: bool) -> void:
	var duur := str(_s.get("stap", "")) == "duur"
	var zin: Array = zin_duur() if duur else zin_zet()
	if nieuw and _kaart != null:
		_kaart.weg()
		_kaart = null
	if _kaart == null:
		_kaart = ctx.ui.somkaart(DECOR, som_balk(), {
			"id": "wk_som", "kamer": KAMER, "hoog": 3.0, "icoon": T_ICOON,
			"pad": false, "regel": zin[0], "regel2": zin[1],
			"keuze_titel": T_STROOK_DUUR if duur else T_STROOK,
			"keuzes": tijd_knoppen() if duur else knoppen(),
		})
		if _kaart != null and not str(_s.get("hulp", "")).is_empty():
			_kaart.hulp(str(_s["hulp"]))
		return
	_kaart.regel(zin[0])
	_kaart.regel2(zin[1])
	_kaart.som(som_balk())
	_kaart.hulp(str(_s.get("hulp", "")))

## De kaart hangt precies `GAT` onder de rechthoek van de klok.  Dan hoeft het
## bandrooster haar niet van de wijzerplaat af te tillen (`midden` doet dat
## anders in hele banden van 52) en houdt de keuzestrook eronder haar plek, ook
## op een laag liggend kader.
##
## Alles is gemeten en niets gegokt: de rechthoek komt van de gebakken plaat van
## het model, de hoogte van de kaart van haar eigen minimummaat vóór de eerste
## tekening.  Dit vervangt de kaderdrempels van de HTML-versie (370/400 px),
## precies zoals architecture.md §4.3/§4.4 vraagt.
func _hang_kaart() -> void:
	var s := Hits.spot("wk_som")
	if s == null or not is_instance_valid(s.knoop):
		return
	var hoog: float = ctx.wereld.px_per_hoogte()
	if hoog <= 0.001:
		return
	var klok: Rect2 = ctx.wereld.vlak_van(MODEL, KX, KZ, 0.0, klok_params())
	if klok.size.y <= 0.0:
		return
	# the card's HONEST height: its own Control minimum is a tower of one word
	# per line until its labels are laid out at their width (B4), and with
	# that tower the card was hung far under the floor and landed on the foot
	# of the frame, 290 units from the clock (owner, 2026-09-23)
	var kh: float = s.knoop.get_combined_minimum_size().y
	if s.knoop is UiSomkaart:
		var eerlijk := Ui.kaart_mat(s.knoop as UiSomkaart)
		if eerlijk.y > 0.0:
			kh = eerlijk.y
	var vloer: float = ctx.wereld.mik_punt(KX, KZ, 0.0).y
	# between the clock and the card the clock's own time ("10 uur") keeps its
	# place, one band of the button grid: the tag steps down in whole bands
	# off the clock face, and without that room the card pushed it under
	# itself — and the answer strip, which glues under the card, went to the
	# foot of the frame
	s.y = (vloer - (klok.end.y + float(Hits.GAT) + float(Hits.RIJ) + kh * 0.5)) / hoog

## Het wekkerkaartje bij het dier: in zijn eigen kamer te zien.  Hetzelfde id
## werkt hetzelfde wolkje bij, dus er wordt niets afgebroken en opnieuw gebouwd.
## Het wolkje hangt bij het dier in ZIJN kamer; staat de camera ergens anders,
## dan gaat het weg in plaats van dat het verborgen wordt.
##
## CONTRACTGAT.  `Hits.plaats()` zet `knoop.visible` alleen voor hotspots die in
## de kamer staan die in beeld is: een hotspot uit een andere kamer wordt niet
## in `lijstje` opgenomen en houdt dus de zichtbaarheid waarmee zijn Control
## werd aangemaakt.  Zo'n Control is nooit ingedeeld en tekent zichzelf
## linksboven in het kader uit (de zin breekt per letter).  Gemeten in de
## browserproef: `wk_gast=[P: (17, 64), S: (4, 4)] kamer=kamer1 nu=gang`.
## Zie het verslag onder "Contract gaps".
func _teken_gast(zeg: String) -> void:
	_zeg = zeg
	var gast := str(_s.get("gast", ""))
	var d = ctx.wereld.dier(gast)
	if gast.is_empty() or _af_nu() or d == null or d.kamer != ctx.wereld.kamer_nu():
		ctx.ui.wolk_weg("wk_gast")
		return
	var tekst := zeg if not zeg.is_empty() \
		else tijd_woord(int(_s.get("doelU", 12)), int(_s.get("doelM", 0)))
	ctx.ui.wolk({"id": "wk_gast", "kamer": d.kamer, "x": d.x, "z": d.z,
		"volg": _volg_dier(gast), "hoog": 54.0,
		"icoon": "💤" if bool(_s.get("slaapt", false)) else T_ICOON,
		"tekst": tekst})

## Loopt het kind zelf naar de kamer van de slaper (of brengt het spel de camera
## daarheen), dan hoort het wekkerkaartje daar te staan — en nergens anders.
func _op_kamer(_kamer: String) -> void:
	if not actief or _s.is_empty() or _af_nu():
		return
	# Tijdens het wakker worden is het wekkerkaartje er met opzet niet meer
	# (games-b.md §2.9): het feest hoort bij de ☀, niet bij de wektijd.
	var stap := str(_s.get("stap", ""))
	if stap == "zet" or stap == "mis" or stap == "duur":
		_teken_gast(_zeg)
	var gast := str(_s.get("gast", ""))
	var d = ctx.wereld.dier(gast)
	if Hits.spot("wk_zon") != null and (d == null or d.kamer != ctx.wereld.kamer_nu()):
		ctx.ui.wolk_weg("wk_zon")

func _volg_dier(id: String) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "y": 54.0, "kamer": d.kamer,
			"vlak": World.vlak_van_dier(id)}

func teken(nieuw: bool, zeg: String = "") -> void:
	_zet_klok()
	_teken_kaart(nieuw)
	_hang_kaart()
	_teken_gast(zeg)
	_meld()

## Eén machineleesbare regel per tekening, plus de plek van elke keuzeknop, voor
## de browserproef (architecture.md §14.4).  De schil meldt alleen bij het
## opstarten waar de hotspots staan; een strook die tijdens het spelen opnieuw
## wordt gebouwd moet zichzelf melden.  De knoppen krijgen hun rechthoek pas in
## de volgende plaatsing, vandaar het wachtje.
func _meld() -> void:
	if not await na(0.25) or _s.is_empty():
		return
	print("[probe] wekker band=", int(_s.get("band", 0)),
		" idx=", int(_s.get("idx", 0)), " stap=", str(_s.get("stap", "")),
		" u=", int(_s.get("u", 0)), " m=", int(_s.get("m", 0)),
		" doelU=", int(_s.get("doelU", 0)), " doelM=", int(_s.get("doelM", 0)),
		" missers=", int(_s.get("missers", 0)),
		" draaien=", int(_s.get("draaien", 0)),
		" spook=", klok_params().has("spookU"), " goed=", goed(),
		" af=", int(_s.get("af", 0)), " sterren=", int(State.s["sterren"]))
	var st := Hits.spot("wk_som_keuzes")
	if st != null and is_instance_valid(st.knoop):
		var rij := st.knoop.get_node_or_null("Rij")
		if rij != null:
			for k in rij.get_children():
				print("[probe] wekkerknop ", k.name, "=",
					(k as Control).get_global_rect(), " tekst=", (k as Button).text)
	for id in ["wk_som", "wk_som_keuzes", "wk_plaat", "wk_tijd", "wk_gast", "wk_zon"]:
		var q := Hits.spot(id)
		if q != null and is_instance_valid(q.knoop) and q.knoop.visible:
			print("[probe] wekkerplek ", id, "=", q.knoop.get_global_rect(),
				" kamer=", q.kamer, " nu=", World.kamer_nu(),
				" dekking=", "%.2f" % Hits.dekking(id),
				" krap=", Hits.debug().get(id, {}).get("krap", false))

# -------------------------------------------------------------------- tikken

## "uur erbij" / "kwartier erbij" / "5 minuten erbij": de wijzers draaien
## VOORUIT, na 12 begint het gewoon weer bij 1.  Nooit terugzetten.
func draai(stap_min: int) -> Dictionary:
	if not actief or _af_nu() or str(_s.get("stap", "")) == "duur":
		return {}
	var t: Dictionary = Sommen.Wekker.van_min(
		Sommen.Wekker.in_min(int(_s["u"]), int(_s["m"])) + stap_min)
	_s["u"] = int(t["u"])
	_s["m"] = int(t["m"])
	_s["draaien"] = int(_s.get("draaien", 0)) + 1
	if str(_s.get("stap", "")) == "mis":
		_s["stap"] = "zet"        # verder draaien: de gewone zin terug
	# Elke draai geeft een zachte gong; `Snd.klok()` remt zichzelf af op
	# 120 ms, zodat twee tikken op één knop één slag geven (architecture.md §8).
	ctx.snd.klok()
	teken(false)
	_bewaar()
	return {"u": int(_s["u"]), "m": int(_s["m"])}

func goed() -> bool:
	return Sommen.Wekker.in_min(int(_s.get("u", 12)), int(_s.get("m", 0))) \
		== Sommen.Wekker.in_min(int(_s.get("doelU", 12)), int(_s.get("doelM", 0)))

## ✅ Klaar.  Fout is nooit straffend: een zacht geluid en een hulpje, de
## wijzers blijven staan zodat je verder kunt draaien (F5).
##
## Een tik op ✅ telt alleen als poging wanneer er sinds de vorige keuring aan
## de wijzers is gedraaid.  Anders was twee keer tikken zonder ook maar iets te
## doen genoeg om de spookwijzers op de wektijd te zetten: het antwoord voor
## niets (R3).  Zonder draai komt er dus geen misser bij, alleen een zacht
## geluid en de regel die zegt wat er wél te doen is.
func klaar_tik() -> Variant:
	if not actief or _af_nu() or str(_s.get("stap", "")) == "duur":
		return null
	if not goed():
		if int(_s.get("draaien", 0)) == int(_s.get("gekeurd", 0)):
			_s["hulp"] = T_HULP0
			ctx.snd.zacht()
			teken(false, T_SLAAPT_NOG if bool(_s.get("slaapt", false)) else T_NOG_NIET)
			_bewaar()
			return false
		_s["gekeurd"] = int(_s.get("draaien", 0))
		_s["missers"] = int(_s.get("missers", 0)) + 1
		_s["stap"] = "mis"
		# K3: de ladder is drie treden. Bij de eerste misser blijft de kaart
		# staan en zegt de wolk dat de gast nog slaapt; bij de TWEEDE misser
		# vertelt de telladder hoeveel er nog moeten draaien; pas bij de DERDE
		# verschijnen de spookwijzers (games-b.md §2.4, K3).
		if int(_s["missers"]) == 1:
			_s["hulp"] = T_HULP1
		elif int(_s["missers"]) == 2:
			var lad := tel_ladder()
			_s["hulp"] = lad if lad != "" else T_HULP1
		else:
			_s["hulp"] = T_HULP2
		ctx.snd.zacht()
		teken(false, T_SLAAPT_NOG if bool(_s.get("slaapt", false)) else T_NOG_NIET)
		_bewaar()
		return false
	_wakker_worden()
	return true

## Een tijd kiezen bij de tijdsduurvraag (band 5).
func kies_tijd(u: int) -> Variant:
	if not actief or _af_nu() or str(_s.get("stap", "")) != "duur":
		return null
	if Sommen.Wekker.u12(u) != Sommen.Wekker.u12(int(_s.get("doelU", 12))):
		_s["missers"] = int(_s.get("missers", 0)) + 1
		var lad := tel_ladder()
		_s["hulp"] = lad if lad != "" else T_HULP1
		ctx.snd.zacht()
		teken(false, T_SLAAPT_NOG if bool(_s.get("slaapt", false)) else T_NOG_NIET)
		_bewaar()
		return false
	_s["stap"] = "zet"
	_s["hulp"] = T_HULP_BEGIN
	ctx.snd.ja()
	teken(true)                   # andere knoppen: de kaart opnieuw
	_bewaar()
	return true

## Samen tellen: van nu naar de wektijd, uur voor uur.
## In de `zet`-stap geeft de bevroren kern duur = 0 (die tel is daar nog
## niet gevraagd); val dan terug op het uurverschil zelf, anders staat er
## één getal op de ladder.  Meer dan vijf uur voorlezen is geen telwerk meer
## en past bovendien niet op één regel van de smalle kaart; dan zegt de
## regel hoeveel er nog over zijn.  Staat de wijzer al op het goede uur
## (alleen de minuten missen), dan is er niets bij te tellen en is de
## ladder leeg; de aanroeper valt dan terug op de gewone hulpregel.
func tel_ladder() -> String:
	var uren: int = int(_s.get("duur", 0))
	if uren <= 0:
		uren = posmod(int(_s.get("doelU", 12)) - int(_s.get("u", 12)), 12)
	if uren <= 0:
		return ""
	if uren > 5:
		return T_HULP_LAD % uren
	var l: Array[String] = []
	for i in range(0, uren + 1):
		l.append(str(Sommen.Wekker.u12(int(_s.get("u", 12)) + i)))
	return "💛 " + " … ".join(l)

# ------------------------------------------------------------- wakker worden

func _wakker_worden() -> void:
	_s["stap"] = "wakker"
	_s["hulp"] = ""
	ctx.state.tel(int(_s.get("missers", 0)) == 0, Time.get_ticks_msec() - _t0)
	_gong()                       # de slag bij het goede uur: nooit afgeremd
	if _kaart != null:
		# De hint hoort bij het zoeken, niet bij het feest: laat hij staan, dan
		# wordt de kaart hoger en dekt hij de klok af.  Eén regel, om dezelfde
		# reden (games-b.md §2.9).
		_kaart.hulp("")
		_kaart.regel("%s is wakker" % naam_van(str(_s.get("gast", ""))))
		_kaart.regel2("")
		_kaart.klaar()
	ctx.ui.wolk_weg("wk_gast")
	# Het wakker worden gebeurt in de KAMER van de gast en het kind staat in de
	# gang: zonder deze camerasprong ziet het alleen de kaart, nooit het dier.
	var g := gast_van(str(_s.get("gast", "")))
	var kam := str(g.get("waar", g.get("kamer", "")))
	if not kam.is_empty() and kam != ctx.wereld.kamer_nu():
		ctx.wereld.naar(kam)
	ctx.wereld.pose(str(_s.get("gast", "")), "blij", 60)
	ctx.ui.wolk({"id": "wk_zon", "volg": _volg_dier(str(_s.get("gast", ""))),
		"hoog": 54.0, "icoon": "☀", "tekst": T_GOEDEMORGEN})
	if int(_s.get("ster", 0)) == 0:
		_s["ster"] = 1
		ctx.taak_klaar("wekker", {"sterren": 1})
		Hotel.render()            # de ster meteen in de balk
	_zet_klok()
	_bewaar()
	_meld()
	_ja_straks()
	if not await na(VOLGENDE_S):
		return
	if _s.is_empty() or str(_s.get("stap", "")) != "wakker":
		return
	volgende()

## De slag bij het goede uur, nooit afgeremd (games-b.md §2.9): `Snd.klok(true)`.
func _gong() -> void:
	ctx.snd.klok(true)

func _ja_straks() -> void:
	if not await na(JA_S):
		return
	ctx.snd.ja()

## De volgende slaper, of klaar.
func volgende() -> bool:
	if not actief or _s.is_empty():
		return false
	var l := ronde_rij()
	var idx := int(_s.get("idx", 0)) + 1
	ctx.ui.wolk_weg("wk_zon")
	# Het feestje in de slaapkamer is voorbij: terug naar de klok in de gang,
	# want daar hangen de kaart en de knoppen van dit spel.
	if ctx.wereld.kamer_nu() != KAMER:
		ctx.wereld.naar(KAMER)
	if idx >= l.size():
		_s["af"] = 1
		_s["stap"] = "af"
		_bewaar()
		_ronde_af()
		return true
	var ster := int(_s.get("ster", 0))
	var g := gast_van(str(l[idx]))
	_s = _nieuwe_beurt(int(_s["N"]), int(_s["band"]), int(_s["dag"]), idx,
		str(g["id"]), slaapt_gast(g))
	_s["rij"] = l
	_s["ster"] = ster             # er valt hooguit één ster per ronde
	ctx.speelt(str(g["id"]))
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	teken(true)
	_bewaar()
	return true

func _ronde_af() -> void:
	var plek: Dictionary = ctx.wereld.mik(DECOR, KAMER)
	ctx.ui.wolk({"id": "wk_af", "kamer": KAMER,
		"x": float(plek.get("x", KX)), "z": float(plek.get("z", KZ)),
		"hoog": 26.0, "icoon": T_ICOON, "tekst": T_AF})
	if not await na(VOLGENDE_S):
		return
	ctx.ui.wolk_weg("wk_af")
	ctx.sluit()
