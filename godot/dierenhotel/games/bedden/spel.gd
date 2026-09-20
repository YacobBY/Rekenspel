extends MiniGame
## bedden — "Bedden op rij" (games-a.md §3, `demos/dierenhotel/games/bedden.js`).
##
## De vloer van een slaapkamer wordt een bedplan.  Uit de dekenkist komen
## bedjes; die leg je in NETTE RIJEN — elke rij is even breed, en het kind zoekt
## uit hoeveel rijen er nodig zijn.  Elk bedje wordt straks een ECHT bed
## (`ctx.wereld.voeg_bed`), en bedden zijn de harde gastenlimiet: dit is het
## spel dat het hotel laat groeien (HOTEL.md §2).
##
## Wat de Godot-poort anders doet dan de HTML, en waarom (architecture.md §1.2):
##
##  * De drie meetronden waarmee de HTML de sommenkaart van rij 0 af duwde
##    (`somLift`, `somNaast`, 90 ms per ronde) zijn weg.  Het bandenraster van
##    §4.3 zet elk element in één pass op een vrije plek; een vaste kaart tilt
##    zichzelf in hele banden op (`Hits._wijk_omhoog`).
##  * `max_stroken()` telt geen css-pixels meer maar de banden die het kader
##    echt heeft (`Hits.RIJ`), en de rij-afstand is één band in plaats van de
##    empirische 50 px.
##  * De breedte van een strookje komt uit `get_combined_minimum_size()` —
##    synchroon, vóór de eerste tekenbeurt — in plaats van uit `offsetWidth`
##    na een DOM-meting.
##  * De `setTimeout`-ketens zijn `await na(...)`: `stop()` zet ze allemaal af.
##
## Wat bindend is en letterlijk zo blijft: de generator
## (`Sommen.Bedden.opdracht`), elke kindertekst van §3.7, de hulpladder
## (kamerhulp Wolkje pas na twee missers), en de regel dat een misser nooit
## straft — één zacht wolkje met een pictogram en een getal, precies bij het
## plekje waar het over gaat.

## Kinderteksten (HOTEL.md §9), letterlijk uit PLAN.md N9.
const VRAAG_REGEL := "Hoeveel bedden heb je nodig?"    ## 5 woorden / 28 tekens
const HULP_BEDJE := "nog een bedje erbij"              ## 4 woorden / 19 tekens

const KAMER := "kamer1"          ## waar het icoontje hangt
const MAX_RIJEN := 3
const MAX_PER_RIJ := 10
const MAX_CAP := 6
const LOS := 18.0                ## een bed haalt de vakjes binnen 18 voxels weg

const GOLF := 0.26               ## één bed per stap in de dekengolf
const NAGENIET := 2.6            ## de kamer bekijken voor de kaartjes weggaan
const SLUIT := 3.4               ## en daarna sluit het spel zichzelf
const HULP_NA := 0.9             ## Wolkje komt vanzelf na de tweede misser
const WOLK_WEG := 1.8            ## een "rij is vol"-wolkje blijft zo lang staan
const WACHT_TEKEN := 2.0         ## na het wachtende dier nog een tekenbeurt
const VOL_UIT := 2.6             ## "vol ✓" en dan zichzelf dicht doen
const KADER_NA := 0.26           ## kader veranderd -> opnieuw indelen
const START_NA := 0.25           ## en één narekenbeurt na de start
const GAST_EERST := 0.3          ## de eerste gast loopt na 300 ms naar zijn bed
const GAST_TUSSEN := 0.48        ## en elke volgende 480 ms later
const HAND := 1                  ## de schepgrootte van `Snd.plop`

## De hotel-knoppen die precies op de rijen vallen; die zeggen tijdens dit spel
## niets nuttigs.  `Games.stop()` roept `Hotel.render()` en zet ze terug.
const STIL := ["bed_%s_bed1", "bed_%s_bed2", "mand_%s", "bak_%s_bak"]

var _kamer := KAMER
var _kaart = null                ## Ui.Kaart
var _kaart_vraag := false        ## ... is nu de openingsvraagkaart
var _bezig := false              ## de dekengolf loopt; niets aanraken
var _t0 := 0
var _goot := 132.0               ## hoe ver een kaartje naast een strookje staat
var _maat_af := Callable()
var _meldt := false              ## er loopt een knoprapport
var _meld_nodig := false         ## ... en er is sindsdien weer getekend

# ---------------------------------------------------------------- aanmelden

func definitie() -> Dictionary:
	return {
		"naam": "Bedden op rij",
		"kamer": KAMER,
		# de dekenkist: de speelmand in de hoek, ver van de bedden en van de
		# deur af, zodat geen enkele knop een andere afdekt
		"hotspot": {"obj": "mand", "icoon": "🛏", "label": "Bedden",
			"hoog": 14, "dx": -4, "dz": -4},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"stub": false,
		"taak": {"id": "bedden", "icoon": "🛏", "tekst": "Zet de bedden op rij",
			"wanneer": func(s: Dictionary) -> bool: return (s["gasten"] as Array).size() >= 2,
			"kamer": KAMER, "prio": 5},
	}

# ------------------------------------------------------------------- laatje

## Alles wat een herlaad moet overleven staat in `ctx.data()`; awaits en timers
## overleven er geen (architecture.md §6.2, regel 3).  Elke lezing gaat door
## `int()`/`str()`, want JSON geeft een geheel getal als float terug.
func _d() -> Dictionary:
	return ctx.data()

func _rijen() -> int:
	return maxi(1, int(_d().get("rijen", 1)))

func _per_rij() -> int:
	return maxi(1, int(_d().get("perRij", 1)))

func _doel() -> int:
	return int(_d().get("doel", 0))

func _missers() -> int:
	return int(_d().get("missers", 0))

func _klaar() -> bool:
	return bool(_d().get("klaar", false))

func _fase() -> String:
	return str(_d().get("fase", "leg"))

func _wand() -> int:
	return int(_d().get("wand", 0))

func _rij_lijst() -> Array:
	var r = _d().get("rij", null)
	if typeof(r) != TYPE_ARRAY:
		r = []
		_d()["rij"] = r
	return r

func _rij_tel(r: int) -> int:
	var lijst := _rij_lijst()
	return 0 if r < 0 or r >= lijst.size() else int(lijst[r])

func _zet_rij(r: int, n: int) -> void:
	var lijst := _rij_lijst()
	while lijst.size() <= r:
		lijst.append(0)
	lijst[r] = n

func _aantal_stroken() -> int:
	return mini(MAX_RIJEN + 1, _rijen() + 1)

func _totaal() -> int:
	var n := 0
	for r in _aantal_stroken():
		n += _rij_tel(r)
	return n

func _volle_rijen() -> int:
	var n := 0
	for r in _aantal_stroken():
		if _rij_tel(r) == _per_rij():
			n += 1
	return n

func _eerste_lege_rij() -> int:
	for r in _aantal_stroken():
		if _rij_tel(r) < _per_rij():
			return r
	return -1

func _kist_over() -> int:
	return maxi(0, _doel() - _totaal())

# ------------------------------------------------------- kamer en capaciteit

## De vrije vakjes van het vloerraster (world.md §1.5, `Kamer.vrij`).
##
## CONTRACTGAT: de HTML leest ze als `wereld.slots(kamer, 'vrij')`
## (`rooms.js:854` geeft dan `r.vrij` terug); `Rooms.slots()` in de poort
## filtert alleen de meubelslots, dus dit spel leest `Kamer.vrij` zelf.
func _vrije_vakken(kamer_id: String) -> Array:
	var r := Rooms.get_kamer(kamer_id)
	if r == null:
		return []
	var uit: Array = []
	for cel in r.vrij:
		uit.append(Vector2(float(cel["x"]), float(cel["z"])))
	return uit

func _bed_punten(kamer_id: String) -> Array:
	var uit: Array = []
	for b in ctx.wereld.slots(kamer_id, "bed"):
		uit.append(Vector2(float(b.get("x", 0.0)), float(b.get("z", 0.0))))
	return uit

## Het vrije vakje dat het verst van ALLE bedden af ligt: zo staan de nieuwe
## bedden mooi verdeeld door de kamer in plaats van tegen elkaar aan.
func _verste_vak(vrij: Array, bedden: Array) -> int:
	var beste := -1
	var best := -1.0
	for i in vrij.size():
		var dm := INF
		for b in bedden:
			var d: float = absf(b.x - vrij[i].x) + absf(b.y - vrij[i].y)
			if d < dm:
				dm = d
		if dm > best:
			best = dm
			beste = i
	return beste

## De opdracht mag nooit meer bedden beloven dan de vloer kan dragen, want elk
## bedje wordt straks een ECHT bed.  Een neergezet bed haalt de vakjes binnen
## 18 voxels van zich af uit het raster, dus het aantal vrije vakjes is niet
## het aantal bedden: we spelen de greedy plaatsing droog na en tellen.
func _ruwe_capaciteit(kamer_id: String) -> int:
	var vrij := _vrije_vakken(kamer_id)
	var bedden := _bed_punten(kamer_id)
	var n := 0
	while not vrij.is_empty():
		var beste := _verste_vak(vrij, bedden)
		if beste < 0:
			break
		var p: Vector2 = vrij[beste]
		bedden.append(p)
		n += 1
		var over: Array = []
		for v in vrij:
			if absf(v.x - p.x) + absf(v.y - p.y) >= LOS:
				over.append(v)
		vrij = over
	return n

func capaciteit(kamer_id: String) -> int:
	return mini(MAX_CAP, _ruwe_capaciteit(kamer_id))

## Het liefst de kamer van het icoontje; is die vol, dan lopen we door naar de
## volgende slaapkamer die nog plek heeft.  Zo blijft de groeilus doorlopen.
func kies_kamer() -> Dictionary:
	var beste := {"kamer": KAMER, "cap": capaciteit(KAMER)}
	if int(beste["cap"]) >= 2:
		return beste
	for id in ctx.wereld.kamers():
		if id == KAMER or ctx.wereld.slots(id, "bed").is_empty():
			continue
		var c := capaciteit(id)
		if c > int(beste["cap"]):
			beste = {"kamer": id, "cap": c}
	return beste

func _beste_vak() -> Dictionary:
	var vrij := _vrije_vakken(_kamer)
	var i := _verste_vak(vrij, _bed_punten(_kamer))
	if i < 0:
		return {}
	return {"x": vrij[i].x, "z": vrij[i].y}

# ---------------------------------------------------------------- de maten

## Hoeveel strookjes past dit kader?  De HTML telde css-pixels
## (`floor((frameHoogte − 200) / 50) + 1`); hier tellen we de banden die het
## kader echt heeft en houden er vier vrij voor de sommenkaart, de dekenkist en
## de knoppenrij.  De uitkomst blijft 3 of 4, dus `rijen` blijft begrensd op 2
## of 3 — precies zoals §3.3 het bedoelt.
func max_stroken() -> int:
	var h := World.kader_rect().size.y
	if h <= 0.0:
		h = 480.0
	var banden := int((h - 2.0 * Hits.RAND) / Hits.RIJ)
	return clampi(banden - 4, 3, 4)

## Eén band tussen twee rijen, nooit minder dan 24 voxels.
func _rij_stap() -> float:
	var py: float = maxf(float(World.schaal().get("pxPerVoxelY", 1.5)), 0.01)
	return maxf(float(Hits.RIJ) / (2.0 * py), 24.0)

## De rijen liggen op de diagonaal x = z van de kamervloer, netjes onder elkaar.
func rij_plek(r: int) -> Dictionary:
	var kmr := Rooms.get_kamer(_kamer)
	var breed := float(kmr.w) if kmr != null else 114.0
	var stap := _rij_stap()
	var begin := maxf(2.0, (breed - (_aantal_stroken() - 1) * stap) / 2.0)
	var p := begin + r * stap
	return {"x": p, "z": p, "y": 6.0}

## `rij_plek(r)` verschoven `dx` px opzij en `dy` px omhoog.  Dit is de
## projectie-identiteit van world.md §0, geen DOM-meting: (+d, −d) op de vloer
## is zuiver zijwaarts op het scherm.
func plek_px(r: int, dx: float, dy: float) -> Dictionary:
	var s := World.schaal()
	var px: float = maxf(float(s.get("pxPerVoxelX", 3.0)), 0.01)
	var ph: float = maxf(float(s.get("pxPerHoogte", 3.0)), 0.01)
	var p := rij_plek(r)
	var d := dx / (2.0 * px)
	return {"x": float(p["x"]) + d, "z": float(p["z"]) - d, "y": 6.0 + dy / ph}

## Past de sommenkaart nog BOVEN rij 0?  De HTML mat dat in drie ronden van
## 90 ms en zette de kaart daarna ernaast (§3.4, ronde 1).  Hier is het één
## som: de kaart is hooguit drie banden hoog, de strookjes één elk, en er moet
## nog een band over zijn voor de dekenkist.  Is het kader korter, dan gaat de
## kaart links van rij 0 staan in plaats van erboven — anders duwt het
## bandenraster kaart en strookje over elkaar heen (`krap`).
func som_naast() -> bool:
	var h := World.kader_rect().size.y
	if h <= 0.0:
		return false
	var banden := int((h - 2.0 * Hits.RAND) / Hits.RIJ)
	return banden < _aantal_stroken() + 4

## De breedte die `Ui` een sommenkaart geeft (world.md §6.5): 170 eenheden op
## een smal kader, anders het gewone kaartje.
func _kaart_breed() -> float:
	return float(UiSomkaart.BREED_KLEIN if Ui.smal() else UiSomkaart.BREED)

## Waar de sommenkaart hangt: boven rij 0, of ernaast op een kort kader.
func som_plek() -> Dictionary:
	if not som_naast():
		return plek_px(0, 0.0, float(marges()["boven"]))
	var breed := 160.0
	var s0 := Hits.spot("bd_rij0")
	if s0 != null and is_instance_valid(s0.knoop):
		breed = maxf(48.0, s0.knoop.get_combined_minimum_size().x)
	return plek_px(0, -(breed / 2.0 + 8.0 + _kaart_breed() / 2.0), 0.0)

func marges() -> Dictionary:
	var h := World.kader_rect().size.y
	if h <= 0.0:
		h = 480.0
	var rij_h := (_aantal_stroken() - 1) * float(Hits.RIJ) + 48.0
	var over := maxf(0.0, h - rij_h - 4.0)
	var extra := maxf(0.0, over - 96.0)
	return {"boven": minf(80.0, 74.0 + extra * 0.6),
		"onder": minf(66.0, 52.0 + extra * 0.4)}

# --------------------------------------------------------------- taalhulpje

## `mv(1, "bed", "bedden")` geeft "1 bed", `mv(3, ...)` geeft "3 bedden".
## Zonder dit staat er "van 1 bedden" zodra een rij één bedje breed is.
static func mv(n: int, enk: String, meerv: String) -> String:
	return "%d %s" % [n, enk if n == 1 else meerv]

# ------------------------------------------------------------------- start

func start(_c: SpelCtx) -> void:
	_bezig = false
	_t0 = Time.get_ticks_msec()
	var keus := kies_kamer()
	_kamer = str(keus["kamer"])
	if World.kamer_nu() != _kamer:
		ctx.wereld.naar(_kamer)
	# Is er nergens meer plek voor een bed?  Dan beloven we ook niets: één
	# vriendelijk kaartje, geen opdracht, geen ster.
	if int(keus["cap"]) < 2:
		_vol()
		return
	var o := Sommen.Bedden.opdracht(ctx.state.band(), int(State.s["dag"]),
		ctx.state.n_gasten(), int(keus["cap"]), max_stroken())
	var sig := _signatuur(o)
	if str(_d().get("sig", "")) != sig or typeof(_d().get("rij", null)) != TYPE_ARRAY:
		_nieuwe_opdracht(o, sig)
	_normaliseer()
	if _klaar():
		if _fase() != "af":
			_d()["fase"] = "af"
		_som_af()
	# N9: de deur wordt niet meer geleend.  🐾 `bd_klaar` is de enige
	# klaar-controle; weglopen is weglopen en de beurt staat in `ctx.data()`.
	if _maat_af.is_valid():
		_maat_af.call()
	_maat_af = ctx.ui.op_kader(_op_kader)
	_teken()
	print("[probe] spel=start id=bedden kamer=", _kamer, " band=", ctx.state.band(),
		" rijen=", _rijen(), " perRij=", _per_rij(), " doel=", _doel())
	_na_start()

## Het hotel tekent zichzelf nog één keer wanneer een spel van kamer wisselt;
## daarna maken we de kamer opnieuw rustig en melden we de knoppen aan de
## browserproef, die pas iets kan aanwijzen als het raster geplaatst heeft.
func _na_start() -> void:
	if not await na(START_NA):
		return
	_rustige_kamer()
	_meld_knoppen()

## Na elke tekenbeurt opnieuw melden, één plaatsingspass later.  Een strookje
## wordt breder zodra er een bedje bij komt, en het bandenraster deelt de
## cellen dan opnieuw uit — het pootje 🐾 staat daarna ergens anders.  Zonder
## deze regels tikt een proef de plek van vóór de eerste tekenbeurt aan
## (dezelfde reden als `scenes/main.gd::_na_plaatsing`).
func _meld_straks() -> void:
	_meld_nodig = true
	if _meldt or not actief:
		return          # er loopt er al een; die neemt deze tekenbeurt mee
	_meldt = true
	while _meld_nodig and actief:
		_meld_nodig = false
		await get_tree().process_frame
		await get_tree().process_frame
		if actief:
			_meld_knoppen()
	_meldt = false

## Elke knop van dit spel, waar hij echt staat.
func _meld_knoppen() -> void:
	for id in Hits.lijst():
		if not id.begins_with("bd_"):
			continue
		var s := Hits.spot(id)
		if s != null and is_instance_valid(s.knoop) and s.knoop.visible:
			print("[probe] ", id, "=", s.knoop.get_global_rect(),
				" dekking=", "%.2f" % Hits.dekking(id))

## Een herlaad komt uit JSON, en JSON kent geen gehele getallen: het laatje
## krijgt zijn tellers terug als int, zodat de save na het hervatten weer
## precies leest zoals hij geschreven is.
func _normaliseer() -> void:
	var lijst := _rij_lijst()
	for i in lijst.size():
		lijst[i] = int(lijst[i])
	var d := _d()
	for sleutel in ["cap", "band", "rijen", "perRij", "doel", "missers", "nieuw",
			"over", "vol", "wand", "laatste"]:
		if d.has(sleutel):
			d[sleutel] = int(d[sleutel])

func _signatuur(o: Dictionary) -> String:
	# alles door `int()`: na een herlaad komt `dag` als 3.0 uit de JSON terug en
	# "3.0|..." is een andere signatuur dan "3|...", waardoor de beurt opnieuw
	# zou beginnen in plaats van te hervatten
	return "|".join(PackedStringArray([str(int(o["band"])), str(int(State.s["dag"])),
		str(ctx.state.n_gasten()), _kamer, str(int(o["cap"])), str(int(o["rijen"])),
		str(int(o["perRij"]))]))

func _nieuwe_opdracht(o: Dictionary, sig: String) -> void:
	var d := _d()
	d["sig"] = sig
	d["kamer"] = _kamer
	d["cap"] = int(o["cap"])
	d["band"] = int(o["band"])
	d["rijen"] = int(o["rijen"])
	d["perRij"] = int(o["perRij"])
	d["doel"] = int(o["doel"])
	d["rij"] = []
	d["missers"] = 0
	d["klaar"] = false
	d["nieuw"] = 0
	d["over"] = 0
	d["spook"] = false
	d["fase"] = "vraag"
	d["vol"] = 0
	d["laatste"] = -1
	# de schuifwand hoort bij groep 5 (de verdeelstrategie van HOTEL.md §5)
	d["wand"] = Sommen.Bedden.wand(int(o["band"]), int(o["rijen"]))

## De kamers zitten helemaal vol met bedden.  Dat is geen fout maar een
## compliment: één kaartje, en het spel doet zichzelf weer dicht.
func _vol() -> void:
	var d := _d()
	d["vol"] = 1
	d["klaar"] = false
	d["fase"] = "vol"
	var sluit := func() -> void: ctx.sluit()
	var mp := World.mik("mand", _kamer)
	_wolk("bd_vol", {"x": mp.get("x", 0.0), "z": mp.get("z", 0.0)},
		{"icoon": "🛏", "tekst": "vol ✓", "hoog": 20.0, "klas": "goed", "prio": 14,
			"tik": sluit})
	ctx.snd.zacht()
	print("[probe] spel=start id=bedden kamer=", _kamer, " vol=1")
	if not await na(VOL_UIT):
		return
	ctx.sluit()

# ------------------------------------------------------------- bedje leggen

func leg_in(r: int) -> void:
	if ctx == null or _bezig or _klaar():
		return
	if _rij_tel(r) >= _per_rij():                  # deze rij is al vol
		ctx.snd.zacht()
		_wolk("bd_op", plek_px(r, -_goot, 0.0),
			{"icoon": "🛏", "getal": _per_rij(), "klas": "hulp"})
		_wolk_straks("bd_op")
		return
	if _kist_over() <= 0:                          # de kist is leeg
		ctx.snd.zacht()
		_wolk("bd_op", plek_px(_aantal_stroken() - 1, 0.0, -float(marges()["onder"])),
			{"icoon": "🧺", "getal": 0, "klas": "hulp"})
		_wolk_straks("bd_op")
		return
	_zet_rij(r, _rij_tel(r) + 1)
	_d()["laatste"] = r
	ctx.ui.wolk_weg("bd_op")
	ctx.ui.wolk_weg("bd_fout")
	ctx.snd.plop(HAND)
	State.bewaar()
	_teken()

func terug() -> void:
	if ctx == null or _bezig or _klaar():
		return
	var r := int(_d().get("laatste", -1))
	if r < 0 or _rij_tel(r) <= 0:
		r = -1
		for i in range(_aantal_stroken() - 1, -1, -1):
			if _rij_tel(i) > 0:
				r = i
				break
	if r < 0:
		ctx.snd.zacht()
		return
	_zet_rij(r, _rij_tel(r) - 1)
	_d()["laatste"] = r
	ctx.ui.wolk_weg("bd_fout")
	ctx.snd.terug()
	State.bewaar()
	_teken()

## De schuifwand: tikken verlaagt hem met 1 en wikkelt om.
func schuif() -> void:
	if ctx == null or _wand() == 0:
		return
	_d()["wand"] = Sommen.Bedden.volgende_wand(_wand(), _rijen())
	ctx.snd.tik()
	State.bewaar()
	_teken()

func _wolk_straks(id: String) -> void:
	if not await na(WOLK_WEG):
		return
	ctx.ui.wolk_weg(id)

# ------------------------------------------------------------------ tekenen

func _wolk(id: String, plek: Dictionary, o: Dictionary) -> void:
	var kopie := o.duplicate()
	kopie["id"] = id
	kopie["kamer"] = _kamer
	kopie["x"] = plek.get("x", 0.0)
	kopie["z"] = plek.get("z", 0.0)
	if not kopie.has("hoog"):
		kopie["hoog"] = plek.get("y", 6.0)
	ctx.ui.wolk(kopie)

## De kamer even rustig maken: de knoppen van het hotel die precies op onze
## rijen vallen zeggen tijdens dit spel niets nuttigs en zouden de rijen uit
## elkaar duwen.  `Games.stop()` roept `Hotel.render()` en zet ze terug.
func _rustige_kamer() -> void:
	for vorm in STIL:
		ctx.hotspots.weg(vorm % _kamer)
	for m in ctx.wereld.kamer_meubels(_kamer):
		if str(m.get("soort", "")) == "bed":
			ctx.hotspots.weg("bed_%s_%s" % [_kamer, str(m.get("id", ""))])

func _teken() -> void:
	if ctx == null or Ui.knoplaag == null:
		return
	_rustige_kamer()
	# Na het feest halen we de strookjes weg: dan zie je de kamer zoals hij nu
	# is — vol met echte bedden.  Dat is de beloning.
	if _fase() == "af":
		_alleen_som()
		return
	if _fase() == "vol":
		return
	if _fase() == "vraag":
		_vraag_teken()
		return
	var laatste := _aantal_stroken() - 1
	var vol := _volle_rijen()
	var spook_rij := -1
	if bool(_d().get("spook", false)) and not _klaar():
		spook_rij = _eerste_lege_rij()
	for r in _aantal_stroken():
		_strook(r, spook_rij)
	for r in range(_aantal_stroken(), MAX_RIJEN + 2):
		ctx.hotspots.weg("bd_rij%d" % r)
	# Hoe breed is een strookje echt?  Daarnaast passen de andere kaartjes.
	# `get_combined_minimum_size()` is exact vóór de eerste tekenbeurt — dat is
	# precies wat de meet-en-duw-machinerie van de HTML overbodig maakt.
	var breed := 160.0
	var s0 := Hits.spot("bd_rij0")
	if s0 != null and is_instance_valid(s0.knoop):
		breed = maxf(48.0, s0.knoop.get_combined_minimum_size().x)
	_goot = maxf(88.0, breed / 2.0 + 52.0)
	_kist(laatste)
	_undo(laatste)
	if not _klaar():
		_som_bij(vol)
	_gastwolk()
	_schuifwand()
	_klaarknop()
	_hulpknop(laatste)
	World.vuil()
	_meld_straks()

## De dekenkist: sleepbron met de teller erop, aan het voeteneind.
##
## CONTRACTGAT: `ctx.hotspots.bron(obj, o)` geeft `op` niet door aan
## `Hits.maak`, en een bron met een mikpunt ónder de vloer (`hoog <= 0`) valt
## daardoor op `midden` terug.  `midden` schuift alleen VERTICAAL, in dezelfde
## kolom als de strookjes, en op een telefoonkader (326 x 558, tien banden van
## vijf kolommen) is die kolom vol: de kist kwam op de sommenkaart terecht
## (`krap`).  Daarom bouwen we de bron hier zelf met `kind: "bron"` en
## `op: "onder"` — dan mag hij ook opzij, en staat hij gewoon onder de laatste
## rij.  Zodra `Ui.bron` een `op` doorgeeft, kan dit terug naar `hotspots.bron`.
func _kist(laatste: int) -> void:
	var kp := rij_plek(laatste)
	var tik := func() -> void:
		if not _klaar():
			ctx.snd.tik()
	ctx.hotspots.maak({
		"id": "bd_kist", "kind": "bron", "kamer": _kamer,
		"x": kp["x"], "z": kp["z"], "y": kp["y"], "op": "onder",
		"icoon": "🧺", "aantal": _kist_over(), "hand": 0, "prio": 12,
		"klas": "hotbron " + ("leeg" if _klaar() else ""),
		"titel": "dekenkist met " + mv(_kist_over(), "bedje", "bedjes"),
		"sleep": "bedrij", "data": {"bron": "bd_kist"}, "aan": tik,
	})

## Eentje terug in de kist.  Het pictogram krijgt zijn woord (HOTEL.md §9);
## CONTRACTGAT: de ↩ van de HTML (U+21A9) zit niet in `fonts/tekens.txt`.
func _undo(laatste: int) -> void:
	if _klaar() or _totaal() <= 0:
		ctx.hotspots.weg("bd_undo")
		return
	var up := plek_px(laatste, -_goot, 0.0)
	var aan := func() -> void: terug()
	ctx.hotspots.maak({
		"id": "bd_undo", "kamer": _kamer, "x": up["x"], "z": up["z"], "y": up["y"],
		"icoon": "🔄", "label": "terug", "klas": "hotwolk", "prio": 11,
		"titel": "eentje terug in de kist", "aan": aan,
	})

## De opdracht hangt boven de gast die op een bed wacht: het pictogram staat in
## hetzelfde wolkje als zijn woorden (HOTEL.md §9).
func _gastwolk() -> void:
	var wacht := _gasten_zonder_bed()
	var gid := str(wacht[0].get("id", "")) if not wacht.is_empty() else ""
	var wd = World.dier(gid) if gid != "" else null
	# Op een kader dat zelfs de sommenkaart niet meer bóven de rijen kwijt kan
	# (een telefoon in landschap: vijf banden) blijft het wolkje weg.  Dat is
	# dezelfde soort beslissing als `som_naast()`: één keer, uit de kadermaat,
	# vóór de eerste tekenbeurt — geen ontwijkrondes achteraf.  Het getal is
	# niet weg: het staat op de kaart én op het pootje (`4 gasten mogen erin`).
	if wd == null or wd.kamer != _kamer or _klaar() or som_naast():
		ctx.ui.wolk_weg("bd_wolk")
		return
	# Onder het telefoonbreekpunt (kader < 520, world.md §6.5) draagt het wolkje
	# alleen zijn pictogram en zijn getal: "🛏 6 bedden maken" is 164 eenheden
	# breed, drie kolommen van het raster, en die zijn op een telefoonkader niet
	# vrij naast een wandelende gast — het wolkje kwam dan `krap` op een
	# strookje terecht.  Pictogram mét getal blijft (HOTEL.md §9), en het woord
	# staat nog op de kaart en op het pootje.
	var breed := World.kader_rect().size.x >= 520.0
	ctx.ui.wolk({"id": "bd_wolk", "kamer": _kamer, "x": wd.x, "z": wd.z,
		"hoog": 52.0, "prio": 12, "icoon": "🛏", "getal": _doel(),
		"tekst": ("bed maken" if _doel() == 1 else "bedden maken") if breed else "",
		"titel": "%s maken" % mv(_doel(), "bed", "bedden"),
		"volg": _volg_gast(gid)})

## De schuifwand van groep 5: de rijen in twee stukken rekenen.
func _schuifwand() -> void:
	if _wand() <= 0 or _klaar():
		ctx.hotspots.weg("bd_wand")
		return
	var a := _wand()
	var b := _rijen() - a
	var per := _per_rij()
	var wp := plek_px(a, _goot, float(Hits.RIJ) / 2.0)
	var aan := func() -> void: schuif()
	ctx.hotspots.maak({
		"id": "bd_wand", "kamer": _kamer, "x": wp["x"], "z": wp["z"], "y": wp["y"],
		"icoon": "🚧", "label": "%d + %d" % [a * per, b * per],
		"klas": "hotwolk hulp", "prio": 11,
		"titel": "%d × %d + %d × %d" % [a, per, b, per], "aan": aan,
	})

## Klaar?  Tik op de deur van de kamer, of op dit pootje.
func _klaarknop() -> void:
	if _klaar():
		ctx.hotspots.weg("bd_klaar")
		return
	var kl := plek_px(0, _goot, 56.0)
	var aan := func() -> void: _check()
	ctx.hotspots.maak({
		"id": "bd_klaar", "kamer": _kamer, "x": kl["x"], "z": kl["z"], "y": kl["y"],
		"icoon": "🐾", "label": str(_doel()), "klas": "hotwolk goed", "prio": 14,
		"titel": "1 gast mag erin" if _doel() == 1 else "%d gasten mogen erin" % _doel(),
		"aan": aan,
	})

## Kamerhulp Wolkje, pas vanaf twee missers (de hulpladder van §1.8).
func _hulpknop(laatste: int) -> void:
	if _missers() < 2 or _klaar():
		ctx.hotspots.weg("bd_hulp")
		return
	var hp := plek_px(laatste, -_goot, -float(Hits.RIJ))
	var aan := func() -> void: hulp()
	ctx.hotspots.maak({
		"id": "bd_hulp", "kamer": _kamer, "x": hp["x"], "z": hp["z"], "y": hp["y"],
		"icoon": "🐑", "label": "Wolkje", "klas": "hotwolk hulp", "prio": 11,
		"titel": "kamerhulp Wolkje", "aan": aan,
	})

func _volg_gast(id: String) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "kamer": d.kamer, "vlak": World.vlak_van_dier(id)}

## Het strookje van één rij: de bedjes die er liggen, spookbedjes voor de
## plekjes die nog leeg zijn, en het aantal als cijfer op de rij.
##
## De bedjes zijn Labels in de knop zelf: de HTML zette ze op `opacity .22`
## (`.62` als het spookvoorbeeld op déze rij staat) en dat is in Godot
## `modulate`.  De knop meet zich daarna aan zijn eigen inhoud, synchroon.
func _strook(r: int, spook_rij: int) -> void:
	var n := _rij_tel(r)
	var per := _per_rij()
	var p := rij_plek(r)
	var id := "bd_rij%d" % r
	var rr := r
	var aan := func() -> void: leg_in(rr)
	var val := func(_lading: Dictionary, data: Dictionary) -> void:
		leg_in(int(data.get("rij", rr)))
	ctx.hotspots.maak({
		"id": id, "kamer": _kamer, "x": p["x"], "z": p["z"], "y": p["y"],
		"kind": "drop", "drop": "bedrij", "data": {"rij": rr}, "val": val,
		# PRIO 14, hoger dan de sommenkaart (13).  De HTML mat in drie ronden of
		# de kaart rij 0 raakte en tilde HEM dan op (`somLift`, §3.4); in het
		# bandenraster is "de kaart wijkt, de rijen niet" precies hetzelfde,
		# maar dan in één pass.  Andersom (kaart 14, strookjes 13) duwt de kaart
		# rij 0 vier banden omlaag, tot ónder de laatste rij — gemeten in de
		# browser op band 4: rij0 y=621 tegen rij1 y=353.
		"klas": "hotbron", "prio": 14,
		# vast = dit strookje wijkt nooit uit; de andere knoppen (ook die van
		# het hotel) schuiven eromheen.  Zo blijft een rij een rij, op elk
		# scherm en bij elke voxelmaat.
		"vast": true, "op": "midden", "icoon": "", "label": "",
		"titel": "rij %d: %d van %d" % [rr + 1, n, per], "aan": aan,
	})
	var spot := Hits.spot(id)
	if spot == null or not is_instance_valid(spot.knoop):
		return
	var knop := spot.knoop as Button
	if knop == null:
		return
	knop.text = ""
	var basis := Ui.basis_maat()
	# bij tien bedjes in een rij wordt het strookje anders te breed voor een
	# telefoon in portret; dan tekenen we de bedjes een tikje kleiner
	var glyph := maxi(UiThema.VLOER,
		int(round((0.8 if per >= MAX_PER_RIJ else 0.95) * basis)))
	var rij := HBoxContainer.new()
	rij.name = "Bedjes"
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_theme_constant_override("separation", 1)
	for i in per:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", glyph)
		l.text = ("🛌" if _klaar() else "🛏") if i < n else "🛏"
		if i >= n:
			l.modulate = Color(1.0, 1.0, 1.0, 0.62 if spook_rij == rr else 0.22)
		rij.add_child(l)
	var getal := Label.new()
	getal.name = "Getal"
	getal.text = str(n)
	getal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	getal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	getal.add_theme_font_size_override("font_size",
		maxi(UiThema.VLOER, int(Ui.maten.get("getal", basis))))
	getal.add_theme_color_override("font_color", UiThema.INKT)
	rij.add_child(getal)
	knop.add_child(rij)
	rij.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	var nodig := rij.get_combined_minimum_size()
	knop.custom_minimum_size = Vector2(maxf(48.0, nodig.x + 16.0),
		maxf(48.0, nodig.y + 12.0))

## De openingsvraag (N9): alleen de kaart met vier knoppen.  De strookjes,
## de kist, 🔄 en 🐾 bestaan nog niet, en het gastwolkje blijft weg — zijn
## getal zou het antwoord van de vraag verklappen.
func _vraag_teken() -> void:
	for r in range(0, MAX_RIJEN + 2):
		ctx.hotspots.weg("bd_rij%d" % r)
	for id in ["bd_kist", "bd_undo", "bd_wand", "bd_klaar", "bd_hulp"]:
		ctx.hotspots.weg(id)
	ctx.ui.wolk_weg("bd_wolk")
	var som := "%d × %d =" % [_rijen(), _per_rij()]
	if _kaart != null and _kaart_vraag and Hits.spot("bd_som") != null:
		_kaart.som(som)
		World.vuil()
		_meld_straks()
		return
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	var sp := som_plek()
	var wacht := _gasten_zonder_bed()
	var o := {
		"id": "bd_som", "kamer": _kamer, "hoog": sp["y"], "pad": false,
		# prio 13: de kaart wijkt voor de rijen, nooit andersom (zie `_strook`)
		"prio": 13, "icoon": "🛏",
		"regel": VRAAG_REGEL,
		# de vier knopjes dragen hetzelfde pictogram als de vraag (HOTEL.md §9)
		"goed": _doel(), "min": 1,
		"on_ok": func(n: int, _k) -> void: _op_vraag(n),
	}
	if not wacht.is_empty():
		o["dier"] = str(wacht[0].get("id", ""))
	_kaart = ctx.ui.somkaart({"x": sp["x"], "z": sp["z"]}, som, o)
	_kaart_vraag = true
	World.vuil()
	_meld_straks()

## De vraag beantwoord.  Goed: de kaart wordt groen en het leggen begint.
## Fout: nooit een kruis en nooit een stap terug — één zacht geluidje en de
## telladder als hulpregel onder de som; dezelfde vier knoppen blijven staan.
func _op_vraag(n: int) -> void:
	if n == _doel():
		if _kaart != null:
			_kaart.klaar()
		_d()["fase"] = "leggen"
		State.bewaar()
		_teken()
		return
	ctx.snd.zacht()
	if _kaart != null:
		_kaart.hulp("tel mee: " + Econ.tel_mee(_per_rij(), _rijen()))
	State.bewaar()

## De sommenkaart wordt één keer gemaakt en daarna bijgewerkt: in Godot staat
## een Control meteen op zijn plek, dus hem elke tekenbeurt opnieuw bouwen zou
## alleen maar flikkeren.
func _som_bij(vol: int) -> void:
	var per := _per_rij()
	var som := "%s × %d =" % [str(vol) if vol > 0 else "?", per]
	if _kaart != null and not _kaart_vraag and Hits.spot("bd_som") != null:
		_kaart.som(som)
		_kaart.zet(str(vol * per) if vol > 0 else "")
		return
	if _kaart != null:
		_kaart.weg()      # de vraagkaart maakt plaats voor de leg-kaart
		_kaart = null
	var sp := som_plek()
	_kaart = ctx.ui.somkaart({"x": sp["x"], "z": sp["z"]}, som, {
		"id": "bd_som", "kamer": _kamer, "hoog": sp["y"], "pad": false,
		# prio 13: de kaart wijkt voor de rijen, nooit andersom (zie `_strook`)
		"prio": 13,
		# één gewone zin boven de som, met het pictogram vooraan op dezelfde
		# regel (HOTEL.md §9): een kale "? × 4 =" leest een kind van zes niet.
		"icoon": "🛏",
		"regel": "Leg %s van %s" % [mv(_rijen(), "rij", "rijen"),
			mv(per, "bed", "bedden")],
		# Deze kaart telt zichzelf mee (`pad: false`): het antwoordvakje laat
		# zien hoeveel bedden er NU liggen, dus beschrijft regel 2 de stand.
		"regel2": "Zo veel bedden staan er nu",
	})
	if _kaart != null:
		_kaart.zet(str(vol * per) if vol > 0 else "")
	_kaart_vraag = false

func _som_af() -> void:
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	_kaart_vraag = false
	var doel := _doel()
	var p := som_plek()
	_kaart = ctx.ui.somkaart({"x": p["x"], "z": p["z"]},
		"%d × %d =" % [_rijen(), _per_rij()], {
			"id": "bd_som", "kamer": _kamer, "hoog": p["y"], "pad": false,
			"prio": 13, "icoon": "🛏",
			"regel": ("Nu staat er " if doel == 1 else "Nu staan er ")
				+ mv(doel, "bed", "bedden"),
		})
	if _kaart != null:
		_kaart.zet(str(doel))
		_kaart.klaar()

## De opgeruimde eindstand: alleen de sommenkaart en één wolkje.
func _alleen_som() -> void:
	for r in range(0, MAX_RIJEN + 2):
		ctx.hotspots.weg("bd_rij%d" % r)
	for id in ["bd_kist", "bd_undo", "bd_wand", "bd_klaar", "bd_hulp"]:
		ctx.hotspots.weg(id)
	ctx.ui.wolk_weg("bd_wolk")
	_eindwolk()
	World.vuil()

func _eindwolk() -> void:
	var nieuw := int(_d().get("nieuw", 0))
	var sluit := func() -> void: ctx.sluit()
	var o := {"icoon": "🛏", "klas": "goed", "prio": 14, "tik": sluit}
	if nieuw > 0:
		o["getal"] = "+%d" % nieuw
	else:
		o["tekst"] = "vol ✓"
	_wolk("bd_goed", plek_px(0, _goot, 0.0), o)

# --------------------------------------------------------------- de gasten

func _gasten_zonder_bed() -> Array:
	var uit: Array = []
	for g in State.s["gasten"]:
		if str(g.get("bed", "")).is_empty():
			uit.append(g)
	return uit

## De deur van deze kamer, alleen uit de gedocumenteerde kamerdata.
func deur_plek() -> Dictionary:
	var r := Rooms.get_kamer(_kamer)
	if r == null or r.deuren.is_empty():
		return {"x": 57.0, "z": 0.0, "ix": 57.0, "iz": 10.0}
	var d: Dictionary = r.deuren[0]
	var m: float = float(d["at"]) + float(d.get("breed", 12)) / 2.0
	if str(d["wand"]) == "z":
		var x := minf(m, float(r.w) - 2.0)
		return {"x": x, "z": 0.0, "ix": x, "iz": 10.0}
	var z := minf(m, float(r.d) - 2.0)
	return {"x": 0.0, "z": z, "ix": 10.0, "iz": z}

## Het laatste dier zonder bed gaat in de deuropening wachten — geduldig, nooit
## boos.  `reis` loopt door de deuren; staat het dier al hier, dan is het een
## gewone wandeling binnen de kamer, want `reis` naar de eigen kamer is geen
## opdracht (world.md §2.5).
func _wacht_in_deuropening() -> bool:
	var zonder := _gasten_zonder_bed()
	if zonder.is_empty():
		return false
	var g: Dictionary = zonder[zonder.size() - 1]
	var id := str(g.get("id", ""))
	var d = World.dier(id)
	if d == null:
		return false
	var p := deur_plek()
	if d.kamer == _kamer:
		World.ga(id, float(p["ix"]), float(p["iz"]), "wacht")
	else:
		World.reis(id, _kamer, {"x": p["ix"], "z": p["iz"], "na": "wacht"})
	return true

## De gasten zonder bed lopen naar hun nieuwe bed.  Een net gelegd bed is nog
## van niemand, dus het dier gaat er BLIJ NAAST staan: op de sta-plek van het
## bed, nooit op de matras.  Slapen doet het pas als de check-in dat bed aan
## die gast geeft.
func _gasten_erin(gelegd: Array) -> void:
	var zonder := _gasten_zonder_bed()
	if zonder.is_empty() or gelegd.is_empty():
		return
	if not await na(GAST_EERST):
		return
	for i in gelegd.size():
		if i >= zonder.size():
			break
		var b: Dictionary = gelegd[i]
		var s: Dictionary = ctx.wereld.slot(_kamer, str(b.get("id", "")))
		if not s.is_empty():
			var gid := str(zonder[i].get("id", ""))
			var dier = World.dier(gid)
			if dier != null:
				if dier.kamer == _kamer:
					World.ga(gid, float(s["sx"]), float(s["sz"]), "blij")
				else:
					World.reis(gid, _kamer, {"x": s["sx"], "z": s["sz"], "na": "blij"})
				ctx.wereld.set_mood(gid, "bouncy")
		if i < gelegd.size() - 1 and not await na(GAST_TUSSEN):
			return

# ------------------------------------------------------------- de controle

## Vriendelijk, en nooit een stap terug.
func _check() -> void:
	if ctx == null or _bezig or _klaar():
		return
	var per := _per_rij()
	var oneven := -1
	var vol := 0
	var leeg := -1
	var over := _kist_over()
	for r in _aantal_stroken():
		var n := _rij_tel(r)
		if n == per:
			vol += 1
		elif n > 0:
			if oneven < 0:
				oneven = r
		elif leeg < 0:
			leeg = r
	if over == 0 and oneven < 0 and vol == _rijen():
		_gelukt()
		return

	# zachte hulp: pictogram + getal, precies bij het plekje dat het is
	_d()["missers"] = _missers() + 1
	var mik: Dictionary
	var ic := "🛏"
	var getal := ""
	if oneven >= 0:                          # een scheve rij: die vullen we aan
		mik = plek_px(oneven, -_goot, 0.0)
		getal = "+%d" % (per - _rij_tel(oneven))
	elif over > 0 and leeg >= 0:             # er kan nog een hele rij bij
		mik = plek_px(leeg, -_goot, 0.0)
		getal = "+%d" % mini(over, per)
	elif over > 0:                           # nog bedjes in de kist
		mik = plek_px(_aantal_stroken() - 1, -_goot, -float(marges()["onder"]))
		getal = "+%d" % over
	else:                                    # een rij te veel: er mag er een terug
		mik = plek_px(maxi(0, vol - 1), -_goot, 0.0)
		ic = "🔄"
		getal = "−%d" % maxi(1, (vol - _rijen()) * per)
	ctx.snd.zacht()
	_teken()
	_wolk("bd_fout", mik, {"icoon": ic, "getal": getal, "klas": "hulp", "prio": 14})
	State.bewaar()
	if _missers() == 2:
		_hulp_straks()
	_na_de_misser()

func _na_de_misser() -> void:
	if not _wacht_in_deuropening():
		return
	if not await na(WACHT_TEKEN):
		return
	_teken()

func _hulp_straks() -> void:
	if not await na(HULP_NA):
		return
	hulp()

# --------------------------------------------- kamerhulp Wolkje doet één rij

func _spook_weg() -> void:
	ctx.ui.getal_tag({"x": 0.0, "z": 0.0}, null, {"id": "bd_spook"})

func hulp() -> void:
	if ctx == null or _klaar():
		return
	var r := _eerste_lege_rij()
	if r < 0:
		return
	_d()["spook"] = true
	_teken()
	var p := plek_px(r, -(_goot - 26.0), 0.0)
	ctx.ui.getal_tag({"x": p["x"], "z": p["z"]}, _per_rij(),
		{"id": "bd_spook", "kamer": _kamer, "y": p["y"], "klas": "hotspook",
			"titel": "zoveel in een rij"})
	var rr := r
	var tik := func() -> void:
		ctx.ui.wolk_weg("bd_wolkje")
		if _klaar():
			return
		leg_in(rr)                     # Wolkje legt ÉÉN bedje bij (N9)
	_wolk("bd_wolkje", plek_px(r, -_goot, float(Hits.RIJ)), {
		"icoon": "🐑", "getal": _per_rij(), "tekst": "in elke rij",
		"titel": HULP_BEDJE, "klas": "hulp", "prio": 14, "tik": tik,
	})
	State.zet_gezien("bedden_wolkje")
	ctx.snd.brief()

# ----------------------------------------------- gelukt: de dekengolf

func _gelukt() -> void:
	var d := _d()
	d["klaar"] = true
	d["fase"] = "feest"
	d["spook"] = false
	_bezig = true
	ctx.state.tel(_missers() == 0, Time.get_ticks_msec() - _t0)
	ctx.snd.tover()
	ctx.ui.wolk_weg("bd_fout")
	_spook_weg()
	_som_af()
	d["nieuw"] = 0
	d["over"] = _doel()
	_teken()
	_wolk("bd_goed", plek_px(0, _goot, 0.0),
		{"icoon": "⭐", "getal": _doel(), "klas": "goed", "prio": 14})
	var gelegd: Array = await _bouw_bedden(_doel())
	if not actief:
		return
	_bezig = false
	d = _d()
	d["nieuw"] = gelegd.size()
	d["over"] = maxi(0, _doel() - gelegd.size())
	# Een ster hoort bij bedden die er echt bij zijn gekomen.  Past er
	# onverwacht toch niets meer, dan zeggen we dat vriendelijk en beloven we
	# niets (F5: de ster is voor het meedoen, nooit voor goed rekenen).
	if not gelegd.is_empty():
		ctx.taak_klaar("bedden", {"sterren": 1})
	ctx.hotspots.laat()                     # de deur is weer gewoon de deur
	_teken()
	_eindwolk()
	State.bewaar()
	var voor := Time.get_ticks_msec()
	await _gasten_erin(gelegd)
	if not actief:
		return
	# even nagenieten, dan de kaartjes weg en de kamer terug aan het hotel
	var rest := maxf(0.4, NAGENIET - float(Time.get_ticks_msec() - voor) / 1000.0)
	if not await na(rest):
		return
	_d()["fase"] = "af"
	_teken()
	State.bewaar()
	print("[probe] spel=klaar id=bedden nieuw=", _d().get("nieuw", 0),
		" sterren=", State.s["sterren"])
	if not await na(SLUIT):
		return
	ctx.sluit()

## Eén bed per stap: dat is de golf die je in de kamer ziet gebeuren.  Past er
## geen bed meer bij, dan stoppen we — nooit een half bed.
func _bouw_bedden(hoeveel: int) -> Array:
	var gelegd: Array = []
	while gelegd.size() < hoeveel:
		var v := _beste_vak()
		if v.is_empty():
			break
		var b: Dictionary = ctx.wereld.voeg_bed(_kamer, {"x": v["x"], "z": v["z"]})
		if b.is_empty():
			break
		gelegd.append(b)
		_rustige_kamer()
		ctx.snd.plop(HAND)
		if not await na(GOLF):
			return gelegd
	return gelegd

# --------------------------------------------------------------- kader, stop

## Draait het scherm, dan verandert de voxelmaat: opnieuw uitleggen.  De
## callback zelf is geen coroutine — een signaal roept hem aan.
func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	_teken_straks()

func _teken_straks() -> void:
	if not await na(KADER_NA):
		return
	_teken()

func stop() -> void:
	if _maat_af.is_valid():
		_maat_af.call()
		_maat_af = Callable()
	if ctx != null:
		if _kaart != null:
			_kaart.weg()
		for id in ["bd_wolk", "bd_fout", "bd_goed", "bd_op", "bd_wolkje", "bd_vol"]:
			ctx.ui.wolk_weg(id)
		_spook_weg()
		print("[probe] spel=stop id=bedden fase=", _fase())
		State.bewaar()
		ctx.hotspots.wis_alles()      # geeft ook de geleende deur terug
	_kaart = null
	_kaart_vraag = false
	_bezig = false
