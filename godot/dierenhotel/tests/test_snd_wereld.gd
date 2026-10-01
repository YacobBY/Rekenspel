extends Proef
## The owner's wish of 2026-10-01: "Ik wil sound effects voor het spel".  The
## game HAD sounds — measured in the web export they left the speaker at
## −27 dBFS (a tap) to −18 (the loudest bell), which a child on a tablet barely
## hears.  So: every player plays its buffer `Snd.LUID_DB` louder (the buffers
## and their HTML oracle in `test_snd.gd` stay exactly as they were), and the
## world got thirteen sounds of its own (`Snd.wereld_namen()`), each heard where
## it belongs.  The game call sites are asserted in the games' own test files
## (oogst, weeg, sleutels, was, spiegel, tobbe, foto, winkel/paskamer); the
## shared ones — the till, a sheet, the bowl, the evening — here.

const T := "snd_wereld"
## The ones a child or the world tick repeats: never louder than `plop`.
const VAAK := ["knabbel", "zwiep", "pluk", "plof", "sticker", "gewicht", "kleed_uit"]

var _laag: Control = null

# ------------------------------------------------------------------ helpers

func _db(x: float) -> float:
	return 20.0 * log(maxf(x, 1e-9)) / log(10.0)

## {piek, ms, luid}: `luid` is the loudest 50 ms window (RMS), closer to what
## an ear calls loud than one sample is.
func _meet(buf: PackedFloat32Array) -> Dictionary:
	var piek := 0.0
	var laatst := 0
	var w := int(0.05 * Snd.SR)
	var acc := 0.0
	var luid := 0.0
	for i in buf.size():
		var a := absf(buf[i])
		piek = maxf(piek, a)
		if a > 0.001:
			laatst = i
		acc += buf[i] * buf[i]
		if i >= w:
			acc -= buf[i - w] * buf[i - w]
		luid = maxf(luid, sqrt(maxf(0.0, acc) / float(w)))
	return {"piek": piek, "ms": int(round(1000.0 * float(laatst) / float(Snd.SR))), "luid": luid}

## Zero crossings per second between `van` and `tot` seconds: rises with pitch.
func _hoogte(buf: PackedFloat32Array, van: float, tot: float) -> float:
	var a := int(van * Snd.SR)
	var b := mini(buf.size(), int(tot * Snd.SR))
	var n := 0
	for i in range(a + 1, b):
		if (buf[i] > 0.0) != (buf[i - 1] > 0.0):
			n += 1
	return float(n) / maxf(0.001, tot - van)

func _wacht(seconden: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(seconden * 1000.0)
	while Time.get_ticks_msec() < eind:
		await boom.process_frame

func _speelt() -> bool:
	for p in Snd._spelers:
		if p.playing:
			return true
	return false

## The band awake and on, nothing heard, no throttle left over.
func _wek() -> Dictionary:
	var oud := {"wakker": Snd._wakker, "uit": Snd._uit}
	Snd._wakker = true
	Snd._uit = false
	for naam in Snd.WERELD_MS:
		Snd._laatst.erase(naam)
	Snd._begin.clear()
	Snd._gehoord.clear()
	return oud

func _slaap(oud: Dictionary) -> void:
	for p in Snd._spelers:
		p.stop()
		p.stream = null           # an open playback at exit is a leaked object
	Snd._sfeer_stop()
	Snd._wakker = bool(oud["wakker"])
	Snd._uit = bool(oud["uit"])
	Snd._begin.clear()
	Snd._gehoord.clear()
	await _uitklinken()

## A stopped voice is let go by the audio server on one of its next mixes, on
## the driver's own thread: give it a tenth of a second, or the playback may
## still be held when the suite exits ("ObjectDB instances were leaked").
func _uitklinken() -> void:
	await _wacht(0.1)

# --------------------------------------------------------------- de buffers

func test_dertien_geluiden_van_de_wereld() -> void:
	var namen := Snd.wereld_namen()
	gelijk(namen.size(), 13, "dertien geluiden van de wereld")
	gelijk(Snd.namen().size(), 18, "de tabel van de HTML blijft achttien")
	for naam in namen:
		waar(not Snd.namen().has(naam) and not Snd.dier_namen().has(naam),
			"%s is nieuw, geen naam uit de tabel of van een dier" % naam)
		waar(not Snd.monster(naam).is_empty(), "%s levert monsters" % naam)
		waar(not Snd.is_ruis(naam), "%s: één vaste buffer, geen verse ruis per keer" % naam)
	for f in ["klik", "kassa", "zwiep", "knabbel", "pluk", "gewicht", "sleutel", "plof",
			"sticker", "bubbel", "kleed", "avond", "luister"]:
		waar(Snd.has_method(f), "Snd.%s() bestaat" % f)

## Short, soft and round: no world sound is louder than `ja`, none has a moment
## as loud as `hoera`, the ones that repeat stay under `plop`, and each starts
## and ends in silence inside its own buffer.
func test_kort_zacht_en_rond() -> void:
	var ja := _meet(Snd.monster("ja"))
	var plop := _meet(Snd.monster("plop"))
	var hoera := _meet(Snd.monster("hoera"))
	for naam in Snd.wereld_namen():
		var lengte := float(Snd.WERELD_LENGTE[naam])
		var buf := Snd.monster(naam)
		gelijk(buf.size(), int(lengte * Snd.SR) + 64, "%s: zo lang als WERELD_LENGTE zegt" % naam)
		var m := _meet(buf)
		var max_ms := 1000 if naam == "avond" else 600
		waar(m["ms"] >= 60 and m["ms"] <= max_ms,
			"%s klinkt %d ms (60..%d)" % [naam, m["ms"], max_ms])
		waar(m["ms"] < int(1000.0 * lengte), "%s past in zijn buffer" % naam)
		waar(m["piek"] <= ja["piek"] * 1.001,
			"%s is nooit luider dan ja (%.1f tegen %.1f dBFS)" % [naam, _db(m["piek"]), _db(ja["piek"])])
		waar(m["luid"] <= hoera["luid"],
			"%s heeft geen moment zo luid als hoera (%.1f dBFS)" % [naam, _db(m["luid"])])
		if VAAK.has(naam):
			waar(m["piek"] <= plop["piek"],
				"%s komt vaak: niet luider dan plop (%.1f dBFS)" % [naam, _db(m["piek"])])
		waar(absf(buf[0]) < 0.0001, "%s begint in stilte" % naam)
		waar(absf(buf[buf.size() - 1]) < 0.0005, "%s eindigt in stilte" % naam)

## Seeded noise, so every call is the same buffer: on the web one sample,
## registered once, instead of a new one per crunch.
func test_elke_keer_hetzelfde() -> void:
	for naam in Snd.wereld_namen():
		waar(Snd.stream(naam).data == Snd.stream(naam).data, "%s is bit-identiek" % naam)

## The swish of a sheet and of clothes going on rises; taking them off falls;
## the evening tune goes down, the mirror of `dag`.
func test_omhoog_en_omlaag() -> void:
	var op := Snd.monster("zwiep")
	waar(_hoogte(op, 0.10, 0.16) > _hoogte(op, 0.0, 0.06) * 1.3,
		"zwiep gaat omhoog (%d -> %d)" % [_hoogte(op, 0.0, 0.06), _hoogte(op, 0.10, 0.16)])
	var uit := Snd.monster("kleed_uit")
	waar(_hoogte(uit, 0.08, 0.13) * 1.3 < _hoogte(uit, 0.0, 0.05),
		"kleed_uit gaat omlaag (%d -> %d)" % [_hoogte(uit, 0.0, 0.05), _hoogte(uit, 0.08, 0.13)])
	var av := Snd.monster("avond")
	waar(_hoogte(av, 0.55, 0.70) < _hoogte(av, 0.02, 0.17),
		"de avond zakt (%d -> %d)" % [_hoogte(av, 0.02, 0.17), _hoogte(av, 0.55, 0.70)])

# ------------------------------------------------------------- hoe luid

## The players carry the loudness, not the buffers: every voice and the room
## ambience play `LUID_DB` louder, the same for all, so the balance between the
## sounds stays the HTML's.  The loudest of all still peaks under −5 dBFS, and a
## plain tap reaches the speaker above −16 dBFS.
func test_luid_genoeg_en_nooit_hard() -> void:
	gelijk(Snd.MEESTER, 0.16, "de buffers houden het niveau van de HTML")
	waar(Snd.LUID_DB >= 9.0 and Snd.LUID_DB <= 14.0, "LUID_DB is %.1f dB" % Snd.LUID_DB)
	gelijk(Snd._spelers.size(), Snd.STEMMEN, "zes stemmen")
	for p in Snd._spelers:
		gelijk(p.volume_db, Snd.LUID_DB, "elke stem speelt LUID_DB luider")
	gelijk(Snd._sfeer.volume_db, Snd.LUID_DB, "de kamersfeer ook: de verhouding blijft")
	var winst := db_to_linear(Snd.LUID_DB)
	var luidst := 0.0
	var wie := ""
	var alles: Array = Snd.namen() + Snd.dier_namen() + ["ding", "trap_op", "trap_af"] \
		+ Snd.wereld_namen()
	for naam in alles:
		var p: float = _meet(Snd.monster(str(naam)))["piek"]
		if p > luidst:
			luidst = p
			wie = str(naam)
	waar(_db(luidst * winst) <= -5.0,
		"nooit hard: de luidste (%s) komt op %.1f dBFS" % [wie, _db(luidst * winst)])
	var tik: float = _meet(Snd.monster("tik"))["piek"]
	waar(_db(tik * winst) >= -16.0, "een tik is te horen: %.1f dBFS" % _db(tik * winst))
	for kamer in Snd.SFEER:
		var naam := Snd.sfeer_naam(str(kamer))
		var s: float = _meet(Snd.sfeer_monster(naam))["piek"]
		waar(_db(s * winst) <= -20.0,
			"de sfeer van %s blijft onder −20 dBFS (%.1f)" % [kamer, _db(s * winst)])

## Mute is mute at once: a bell that still rings stops with it, nothing new
## starts, the room ambience stops, and the child's own speaker button does
## the same.
func test_uit_is_meteen_stil() -> void:
	var oud := _wek()
	var geluid = State.s.get("geluid", true)
	Snd.ding()
	waar(_speelt(), "de bel klinkt")
	Snd.stem_af(false)
	waar(not _speelt(), "uit: de bel zwijgt meteen")
	waar(not Snd._sfeer.playing, "uit: geen kamersfeer")
	Snd._gehoord.clear()
	Snd.kassa()
	Snd.zwiep()
	Snd.knabbel()
	Snd.klik()
	Snd.kleed(true)
	Snd.avond()
	gelijk(Snd.gehoord(), [], "uit: geen enkel nieuw geluid")
	gelijk(Snd.luister(func() -> void: Snd.stem_af(false)), [], "en uitzetten zelf klinkt niet")
	# the speaker button of the child
	Snd.stem_af(true)
	Snd.hoera()
	waar(_speelt(), "aan: hoera klinkt")
	waar(Snd.schakel(), "de knop zet het geluid uit")
	waar(not _speelt(), "de knop zet ook een lopend geluid stil")
	waar(not Snd.schakel(), "en weer aan")
	gelijk(Snd.gehoord().back(), "tik", "met een tik")
	State.s["geluid"] = geluid
	await _slaap(oud)

## What a fast finger or the world tick repeats is one sound per window.
func test_geknepen() -> void:
	var oud := _wek()
	Snd.knabbel()
	Snd.knabbel()
	Snd.zwiep()
	Snd.zwiep()
	gelijk(Snd.gehoord(), ["knabbel", "zwiep"], "twee keer vlak na elkaar is één keer")
	Snd._laatst["knabbel"] = int(Snd._laatst["knabbel"]) - int(Snd.WERELD_MS["knabbel"]) - 10
	Snd.knabbel()
	gelijk(Snd.gehoord().back(), "knabbel", "na het venster weer wel")
	await _slaap(oud)

# -------------------------------------------------------------- in het hotel

## Earned money rings in the till; spending it (the furniture book) does not.
func test_verdiend_geld_rinkelt_in_de_kassa() -> void:
	var munten := int(State.s["munten"])
	var h := Snd.luister(func() -> void: Econ.geef_munt(3))
	waar(h.has("kassa"), "munten erbij: kassa (%s)" % str(h))
	h = Snd.luister(func() -> void: Econ.geef_munt(-3))
	waar(not h.has("kassa"), "munten eraf: geen kassa (%s)" % str(h))
	State.s["munten"] = munten
	Hotel.hud()
	await _uitklinken()

## At the bill the coins and the star come in one frame: the coins ring
## first, the star a moment later — and a star on its own is there at once.
func test_de_ster_wacht_op_de_munten() -> void:
	var munten := int(State.s["munten"])
	var sterren := int(State.s["sterren"])
	var oud := _wek()
	Econ.geef_munt(2)
	Econ.sterren(1)
	gelijk(Snd.gehoord(), ["kassa"], "eerst de munten")
	await _wacht(Snd.KASSA_S + 0.15)
	gelijk(Snd.gehoord(), ["kassa", "ster"], "dan de ster")
	Snd._gehoord.clear()
	Snd._begin.clear()
	Econ.sterren(1)
	gelijk(Snd.gehoord(), ["ster"], "zonder munten: de ster meteen")
	State.s["munten"] = munten
	State.s["sterren"] = sterren
	Hotel.hud()
	await _slaap(oud)

## A sheet slides open with a swish; the board rebuilt in place (`stil`) does
## not swish again.
func test_een_blad_schuift_open() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = Vector2(1000, 648)
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	var o := {"titel": "Proef", "inhoud": [], "knoppen": [{"id": "sluit", "tekst": UiTekst.SLUITEN}]}
	var h := Snd.luister(func() -> void: Ui.blad_open(o))
	waar(Ui.blad_open_nu(), "het blad staat open")
	gelijk(h, ["zwiep"], "een blad schuift open: zwiep")
	o["stil"] = true
	h = Snd.luister(func() -> void: Ui.blad_open(o))
	waar(not h.has("zwiep"), "opnieuw opgebouwd, stil: geen zwiep (%s)" % str(h))
	Ui.blad_dicht()
	await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	_laag.queue_free()
	_laag = null

## Guests at the bowl in view munch: one crunch per bite out of the bowl.  A
## bowl in another room is chewed in silence.
func test_aan_het_bakje_wordt_geknabbeld() -> void:
	var kamer_was := World.kamer_nu()
	World.naar("kamer1")
	World.zet_bak("kamer1", "bak", 4)
	var bak: Dictionary = Rooms.get_kamer("kamer1").slots["bak"]
	World.zet(T, "kamer1", bak["sx"], bak["sz"], {"kind": "hond"})
	World.feest([T])
	gelijk(World.dier(T).staat, "eet", "de hond eet")
	var h := Snd.luister(func() -> void:
		for _i in World.KAUW_PER_NIVEAU:
			World._tik())
	gelijk(World.bak_stand("kamer1", "bak"), 3, "één hapje uit de bak")
	gelijk(h.count("knabbel"), 1, "en één keer krr-krr (%s)" % str(h))
	# out of sight: the world chews on, without a sound
	World.zet_bak("kamer1", "bak", 4)
	World.naar("receptie")
	h = Snd.luister(func() -> void:
		for _i in 2 * World.KAUW_PER_NIVEAU:
			World._tik())
	waar(not h.has("knabbel"), "een bakje buiten beeld zwijgt (%s)" % str(h))
	World.weg(T)
	World.zet_bak("kamer1", "bak", 0)
	World.naar(kamer_was)
	await _uitklinken()

## The evening falls with its little lullaby.
func test_het_wordt_avond() -> void:
	alleen_spellen([])
	Rooms.herstel()
	State.nieuw_spel()
	State.start_gekozen()
	Econ.rekening_stop()
	State.s["taken"] = []
	var h := Snd.luister(func() -> void: Hotel.avondronde())
	gelijk(State.s["ronde"], "avond", "de avondronde loopt")
	waar(h.has("avond"), "met het slaapliedje (%s)" % str(h))
	State.nieuw_spel()
	await _uitklinken()
