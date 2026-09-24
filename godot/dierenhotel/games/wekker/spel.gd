extends MiniGame
## G2 — DE WEKKERDIENST (games-b.md §2, architecture.md §6.5).
##
## Alles gebeurt in de gang, er komt geen rekenblad naast de kamer:
##   * aan de achterwand hangt de grote halklok — los decor van een eigen
##     voxelmodel (`wekker_klok`) met een wijzerplaat, twaalf uurstreepjes en
##     TWEE wijzers die echt met de parameters meedraaien; elke tik zet nieuwe
##     params, dus de motor bakt precies één plaatje opnieuw;
##   * zolang er gespeeld wordt komt die klok van de muur naar VOREN: groot en
##     recht van voren (`WekkerKlok`, klok_groot.gd), met cijfers en wijzers die
##     echt draaien (eigenaar 2026-09-24: "de klok naar voren laten komen zodat
##     de speler de klok duidelijk van voren kan zien tot ze wegklikken");
##   * NERGENS staat in woorden hoe laat de klok is — geen cijfer boven de klok,
##     geen "nu: …" op de kaart (eigenaar 2026-09-24: "geen hint geven hoe laat
##     het is"): het kind leest de wijzers;
##   * onder de klok hangt één sommenkaart met de wekkerwens van de gast en één
##     knoppenstrook met pictogram én woord: een uur erbij, een uur eraf, …;
##   * bij het slapende dier hangt zijn eigen wekkerkaartje (💤);
##   * goed gezet: de klok slaat, het dier wordt wakker (houding blij +
##     ☀-wolkje) en er valt een ster;
##   * verkeerd gezet: het dier slaapt door en de wijzers blijven staan zodat je
##     verder kunt draaien — vooruit, of met "uur eraf" een uur terug (eigenaar
##     2026-09-24).  Nooit rood, geen timer (F5).
##
## GEEN HULP NA EEN FOUT (eigenaar 2026-09-24: "Nee geef geen hulp na fouten.
## Kinderen moeten zelf leren rekenen").  De hulpladder van K3 — de gewone
## hulpregel, dan de telladder, dan de spookwijzers — is weg.  Een verkeerde
## ✅ (of een verkeerd uur bij de tijdsduurvraag): een zacht geluid, de
## strook even op slot met `🔄 Nog een keer` aan de klok (de slaper ligt in
## zijn eigen kamer en slaapt gewoon door), en de kaart blijft precies zoals
## hij was.  De vaste regel `T_HULP_BEGIN` staat er vanaf de eerste tik en
## verandert niet.
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
## De vaste regel op de kaart, vanaf de eerste tik (K3) en na een misser
## ongewijzigd (eigenaar 2026-09-24).
const T_HULP_BEGIN := "💛 draai tot de klok klopt"
const T_SLAAPT_NOG := "slaapt nog"
const T_NOG_NIET := "nog niet"
const T_GOEDEMORGEN := "goedemorgen"
const T_AF := "allemaal gewekt"
const T_UUR := "uur erbij"
const T_UUR_K := "uur"
## Een uur terug (eigenaar 2026-09-24: 'Doe ook een "uur eraf" optie').  ⏪
## zoals op elke afspeelknop: terugspoelen.  Kort `eraf`, want twee knoppen
## met alleen "uur" erop zijn alleen aan hun plaatje uit elkaar te houden.
const T_UUR_AF := "uur eraf"
const T_UUR_AF_K := "eraf"
const ICO_UUR_AF := "⏪"
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
var _stap := 0                    ## wat er net gedraaid is (min): zo draaien de wijzers mee

## De grote klok van voren (`WekkerKlok`), zolang er gespeeld wordt.
const GROOT := "wk_groot"
## Nooit groter dan dit (eenheden): op een groot scherm blijft het een klok aan
## de muur van de gang en geen wijzerplaat van de hele kamer.
const GROOT_MAX := 420.0
const GROOT_MIN := 96.0

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
	# de grote klok meet zichzelf elke plaatsing opnieuw (`_groot_maat`)
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
	# klaar met wat het kind moet doen — en een misser verandert hem niet.
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
	# K3: de vaste regel, behalve bij een reeds ontwaakte gast — daar hoort
	# geen hulpregel bij.  Wat een oude opslag nog aan hulpladder bewaarde
	# ("draai nog wat verder", een telladder, de spoken) komt niet terug
	# (eigenaar 2026-09-24).
	uit["hulp"] = "" if uit["stap"] == "wakker" else T_HULP_BEGIN
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
## van straal r0 tot r1; `dik` is de halve breedte in schermpunten en `stap`
## de afstand tussen twee punten langs de wijzer.
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
	_streep(v, 0.0, R_UUR, _hoek_uur(uur, mn), 1.0, KL_UUR, 2, 0.5)
	_streep(v, 0.0, R_MIN, _hoek_min(mn), 0.5, KL_MIN, 2, 0.5)
	ArtVorm.bx(v, -1, CY - 1, 2, 2, 2, 1, KL_HART)
	return v

# ------------------------------------------------- de klok in de wereld zetten

## De stand van de wijzers, en niets anders: er wijzen geen bleke spookwijzers
## mee, ook niet na drie missers (eigenaar 2026-09-24: "geef geen hulp na
## fouten").
func klok_params() -> Dictionary:
	return {"uur": int(_s.get("u", 12)), "min": int(_s.get("m", 0))}

## De klok aan de muur (het voxelmodel) en de grote klok van voren.  Er komt
## geen cijfer meer bij dat zegt hoe laat hij is (eigenaar 2026-09-24: "geen
## hint geven hoe laat het is"): het oude tijdplaatje `wk_tijd` is weg.
func _zet_klok() -> void:
	ctx.wereld.decor(KAMER, {"id": DECOR, "model": MODEL, "x": KX, "z": KZ,
		"ver": true, "params": klok_params()})
	var stap := _stap
	_stap = 0
	_groot_klok(stap)

## De klok van VOREN (eigenaar 2026-09-24).  Zolang de wekkerdienst loopt staat
## hij groot en recht voor de muur van de gang, tot het kind wegtikt: dan ruimt
## `stop()` hem op met de rest.  In een andere kamer (het wakker worden) laat
## `Hits` hem vanzelf weg; terug in de gang komt hij weer naar voren.
##
## Hij neemt ook de taak van het oude lege tagje `wk_plaat` over (games-b.md
## §2.6): wat Hits hier neerlegt reserveert zijn hele rechthoek, dus er valt
## geen knop op de wijzerplaat.  Hij hangt in de VASTE laag, zodat een
## naambordje van een dier dat door de gang loopt voor hem opzij gaat en hij
## niet zelf van zijn plek springt.
func _groot_klok(stap: int = 0) -> void:
	var u := int(_s.get("u", 12))
	var m := int(_s.get("m", 0))
	var s := Hits.spot(GROOT)
	if s != null and is_instance_valid(s.knoop) and s.knoop is WekkerKlok:
		(s.knoop as WekkerKlok).zet(u, m, stap)
		return
	var klok := WekkerKlok.new()
	klok.meet = _groot_maat
	klok.zet(u, m)
	_wand_hart(klok)
	ctx.hotspots.maak({"id": GROOT, "kind": "eigen", "knoop": klok, "kamer": KAMER,
		"x": KX, "z": KZ, "y": float(CY), "op": "midden", "geen_vlak": true,
		"vast": true, "prio": 20, "volg": _volg_groot()})

## Waar de klok aan de muur hangt, voor het naar voren komen.
func _wand_hart(klok: WekkerKlok) -> void:
	klok.van_hart = World.mik_punt(KX, KZ, float(CY))
	klok.van_straal = R_KAST * float(World.schaal().get("k", 1.0))

## Elke plaatsing: het hart van de grote klok staat zo dicht mogelijk bij de
## wandklok — recht ervoor — maar helemaal in de vrije ruimte boven de
## rekenbalk.  `Hits` klemt hem daarna nog in het kader.
func _volg_groot() -> Callable:
	return func() -> Dictionary:
		var s := Hits.spot(GROOT)
		if s == null or not is_instance_valid(s.knoop):
			return {}
		_wand_hart(s.knoop as WekkerKlok)
		var hoog: float = World.px_per_hoogte()
		if hoog <= 0.001:
			return {}
		var vrij := _groot_vrij()
		var maat := _groot_maat()
		var wand: Vector2 = World.mik_punt(KX, KZ, float(CY))
		var y_mid := clampf(wand.y, vrij.position.y + maat.y * 0.5,
			maxf(vrij.position.y + maat.y * 0.5, vrij.end.y - maat.y * 0.5))
		var vloer: float = World.mik_punt(KX, KZ, 0.0).y
		return {"x": KX, "z": KZ, "y": (vloer - y_mid) / hoog, "kamer": KAMER}

## De ruimte waarin de grote klok mag staan: het kader boven de rekenbalk.
## Staat er geen balk (een kader dat daar te krap voor is), dan houdt hij
## onderin plaats vrij voor de kaart en haar strook, die dan onder hem hangen.
func _groot_vrij() -> Rect2:
	var kader := World.kader_rect().size
	var boven := float(Hits.RAND)
	var onder := kader.y - float(Hits.RAND)
	if Ui.balk_aan():
		onder = kader.y - Ui.balk_kost() - float(Hits.GAT)
	else:
		onder -= _kaart_ruimte()
	return Rect2(Vector2(float(Hits.RAND), boven),
		Vector2(maxf(0.0, kader.x - 2.0 * float(Hits.RAND)), maxf(0.0, onder - boven)))

## Hoe hoog de zwevende kaart met haar strook eronder is, plus de lucht ertussen.
func _kaart_ruimte() -> float:
	var h := 0.0
	var k := Hits.spot("wk_som")
	if k != null and is_instance_valid(k.knoop) and k.knoop is UiSomkaart:
		h += Ui.kaart_mat(k.knoop as UiSomkaart).y + float(Hits.GAT)
	var st := Hits.spot("wk_som_keuzes")
	if st != null and is_instance_valid(st.knoop):
		h += (st.knoop as Control).get_combined_minimum_size().y + float(Hits.KLEEF)
	return h

## Zo groot als de vrije ruimte toelaat: in de hoogte helemaal, in de breedte
## hooguit vier vijfde (er moet ruimte blijven voor een wolkje ernaast).
func _groot_maat() -> Vector2:
	var vrij := _groot_vrij()
	var breed := minf(vrij.size.x * 0.8, vrij.size.y / WekkerKlok.VORM)
	breed = clampf(breed, GROOT_MIN, GROOT_MAX)
	return WekkerKlok.maat_bij(floorf(breed))

## De rechthoek waar de grote klok nu staat (of komt te staan).
func groot_rect() -> Rect2:
	var l: Dictionary = Hits.debug().get(GROOT, {})
	if l.has("rect"):
		return l["rect"]
	var maat := _groot_maat()
	var vrij := _groot_vrij()
	var x: float = World.mik_punt(KX, KZ, float(CY)).x
	return Rect2(Vector2(x - maat.x * 0.5, vrij.get_center().y - maat.y * 0.5), maat)

# ------------------------------------------------------------------ de kaart

func tijd_woord(u: int, m: int) -> String:
	return Sommen.Wekker.tijd_woord(u, m)

## De zin blijft binnen het budget van F4: hooguit 8 woorden EN 40 tekens, en
## op één regel past ongeveer 34 tekens.  Met de langste naam en de langste
## tijd loopt "... wil om ... op" daar net over; dan zegt de kaart het korter.
## K3: na een misser zegt de kaart dezelfde wens nog eens.  Hoe laat de klok
## NU is staat nergens in woorden (eigenaar 2026-09-24): dat leest het kind
## van de wijzers.
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

## De sombalk is leeg.  Tot 2026-09-24 stond hier de klokstand in woorden
## ("nu: 10 uur"), en daarmee hoefde het kind de klok niet te lezen: het tikte
## tot de woorden klopten (eigenaar: "geen hint geven hoe laat het is").
func som_balk() -> String:
	return ""

## Een uur erbij en een uur eraf in elke band; band 4 draait daarnaast per
## kwartier, band 5 per vijf minuten.  De strook houdt hooguit vier knoppen
## (HOTEL.md §9), dus band 5 heeft geen kwartierknop meer: een kwartier is drie
## keer vijf minuten, en per vijf minuten rond tellen is precies wat groep 5
## op de klok leert.  (Het alternatief — ✅ Klaar uit de strook halen — laat
## de knop waar het kind op eindigt los van de andere staan.)
func knoppen() -> Array:
	var band := int(_s.get("band", 3))
	var l: Array = [
		{"id": "uur", "icoon": "🕐", "tekst": T_UUR, "kort": T_UUR_K,
			"kies": func(_k: String) -> void: draai(60)},
		{"id": "uur_af", "icoon": ICO_UUR_AF, "tekst": T_UUR_AF, "kort": T_UUR_AF_K,
			"kies": func(_k: String) -> void: draai(-60)},
	]
	if band == 4:
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
			# klok lezen is rekenen: de kamerknoppen wachten (Ui.is_som)
			"reken": true,
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

## De kaart hangt precies `GAT` onder de rechthoek van de klok — sinds
## 2026-09-24 de grote klok van voren.  Dan hoeft het bandrooster haar niet van
## de klok af te tillen (`midden` doet dat anders in hele banden van 52) en
## houdt de keuzestrook eronder haar plek, ook op een laag liggend kader.  (In
## de rekenbalk staat de kaart op het papier onderin; dan telt dit niet.)
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
	if Hits.spot(GROOT) != null:
		klok = groot_rect()
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
	# right under the clock: there is no time tag between them any more
	s.y = (vloer - (klok.end.y + float(Hits.GAT) + kh * 0.5)) / hoog

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
		" draaien=", int(_s.get("draaien", 0)), " goed=", goed(),
		" af=", int(_s.get("af", 0)), " sterren=", int(State.s["sterren"]))
	var st := Hits.spot("wk_som_keuzes")
	if st != null and is_instance_valid(st.knoop):
		var rij := st.knoop.get_node_or_null("Rij")
		if rij != null:
			for k in rij.get_children():
				print("[probe] wekkerknop ", k.name, "=",
					(k as Control).get_global_rect(), " tekst=", (k as Button).text)
	for id in ["wk_som", "wk_som_keuzes", GROOT, "wk_gast", "wk_zon"]:
		var q := Hits.spot(id)
		if q != null and is_instance_valid(q.knoop) and q.knoop.visible:
			print("[probe] wekkerplek ", id, "=", q.knoop.get_global_rect(),
				" kamer=", q.kamer, " nu=", World.kamer_nu(),
				" dekking=", "%.2f" % Hits.dekking(id),
				" krap=", Hits.debug().get(id, {}).get("krap", false))

# -------------------------------------------------------------------- tikken

## "uur erbij" / "kwartier erbij" / "5 minuten erbij": de wijzers draaien
## vooruit, na 12 begint het gewoon weer bij 1.  "uur eraf" (`stap_min` -60)
## draait ze een uur terug, vóór 1 komt 12 (eigenaar 2026-09-24).  De grote klok
## laat de wijzers die kant op draaien (`_stap`).
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
	_stap = stap_min
	teken(false)
	_bewaar()
	return {"u": int(_s["u"]), "m": int(_s["m"])}

func goed() -> bool:
	return Sommen.Wekker.in_min(int(_s.get("u", 12)), int(_s.get("m", 0))) \
		== Sommen.Wekker.in_min(int(_s.get("doelU", 12)), int(_s.get("doelM", 0)))

## ✅ Klaar.  Fout is nooit straffend en helpt ook niet (F5; eigenaar
## 2026-09-24): een zacht geluid, de strook even op slot met `🔄 Nog een keer`
## aan de klok, de gast slaapt door, en de wijzers blijven staan zodat je
## verder kunt draaien.  Op de kaart verandert niets.
##
## Een tik op ✅ telt alleen als poging wanneer er sinds de vorige keuring aan
## de wijzers is gedraaid: wie twee keer tikt zonder iets te doen, zit er niet
## twee keer naast (R3, voor het adaptieve signaal).  Het antwoord is dan nog
## steeds niet goed, dus ook dat is een misser om te zien.
func klaar_tik() -> Variant:
	if not actief or _af_nu() or str(_s.get("stap", "")) == "duur":
		return null
	if not goed():
		if int(_s.get("draaien", 0)) != int(_s.get("gekeurd", 0)):
			_s["gekeurd"] = int(_s.get("draaien", 0))
			_s["missers"] = int(_s.get("missers", 0)) + 1
			_s["stap"] = "mis"
		_mis()
		return false
	_wakker_worden()
	return true

## Wat een misser laat zien: een zacht geluid, het wekkerkaartje bij de gast
## zegt dat hij nog slaapt, en `Ui` zet de strook even op slot met
## `🔄 Nog een keer` — bij de klok, want de slaper ligt in zijn eigen kamer en
## wordt niet uit zijn bed gehaald.  Geen hulpregel, geen telladder, geen
## spookwijzers.
func _mis() -> void:
	ctx.snd.zacht()
	teken(false, T_SLAAPT_NOG if bool(_s.get("slaapt", false)) else T_NOG_NIET)
	_bewaar()
	ctx.ui.misser(_kaart, str(_s.get("gast", "")))

## Een tijd kiezen bij de tijdsduurvraag (band 5).
func kies_tijd(u: int) -> Variant:
	if not actief or _af_nu() or str(_s.get("stap", "")) != "duur":
		return null
	if Sommen.Wekker.u12(u) != Sommen.Wekker.u12(int(_s.get("doelU", 12))):
		_s["missers"] = int(_s.get("missers", 0)) + 1
		_mis()
		return false
	_s["stap"] = "zet"
	_s["hulp"] = T_HULP_BEGIN
	ctx.snd.ja()
	teken(true)                   # andere knoppen: de kaart opnieuw
	_bewaar()
	return true

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
