extends Proef
## Every guest kind says it itself (owner, 2026-09-24: "Kan je ook een passend
## droevig teleurgesteld geluidje en een enthousiast bij success geluidje bij
## elk dier maken?"): a sad and a happy little voice per kind, synthesised like
## the eighteen (`Snd.dier_sip` / `Snd.dier_blij`), heard in `Ui.misser` and
## after every `Snd.ja()` of the animal of the turn.
##
## The eighteen of the HTML table and their oracle are `test_snd.gd`; this file
## only adds, and checks that the table did not move.

const GAST := "snd_dier"
const DIEREN := ["hond", "poes", "konijn", "gans"]

var _laag: Control = null
var _was_wakker := false
var _was_uit := false

# ------------------------------------------------------------------ helpers

func _op() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = Vector2(1000, 648)
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, _laag.size))

func _af() -> void:
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null
	if World.dier(GAST) != null:
		World.weg(GAST)

## The audio band awake and on, with a clean memory: no throttle left over
## from an earlier test, nothing heard yet.
func _wek(uit := false) -> void:
	_was_wakker = Snd._wakker
	_was_uit = Snd._uit
	Snd._wakker = true
	Snd._uit = uit
	_vergeet()

func _vergeet() -> void:
	Snd._laatst.erase("dier_sip")
	Snd._laatst.erase("dier_blij")
	Snd._begin.clear()
	Snd._sip_ms = -100000
	Snd._gehoord.clear()

func _slaap() -> void:
	for p in Snd._spelers:
		p.stop()
	Snd._wakker = _was_wakker
	Snd._uit = _was_uit
	_vergeet()

func _wacht(seconden: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(seconden * 1000.0)
	while Time.get_ticks_msec() < eind:
		await boom.process_frame

func _db(x: float) -> float:
	return 20.0 * log(maxf(x, 1e-9)) / log(10.0)

## {piek, ms, eerste, laatst, luid}: `luid` is the loudest 50 ms window (RMS),
## which is closer to what an ear calls loud than one sample is.
func _meet(buf: PackedFloat32Array) -> Dictionary:
	var piek := 0.0
	var eerste := -1
	var laatst := 0
	var w := int(0.05 * Snd.SR)
	var acc := 0.0
	var luid := 0.0
	for i in buf.size():
		var a := absf(buf[i])
		piek = maxf(piek, a)
		if a > 0.001:
			laatst = i
			if eerste < 0:
				eerste = i
		acc += buf[i] * buf[i]
		if i >= w:
			acc -= buf[i - w] * buf[i - w]
		luid = maxf(luid, sqrt(maxf(0.0, acc) / float(w)))
	return {"piek": piek, "ms": int(round(1000.0 * float(laatst) / float(Snd.SR))),
		"eerste": eerste, "laatst": laatst, "luid": luid}

## Zero crossings per second in [a, b): a plain pitch meter for one voice.
func _toon(buf: PackedFloat32Array, a: int, b: int) -> float:
	var n := 0
	var vorig := 0.0
	for i in range(maxi(0, a), mini(buf.size(), b)):
		var v := buf[i]
		if absf(v) < 0.0005:
			continue
		if (v > 0.0) != (vorig > 0.0):
			n += 1
		vorig = v
	return float(n) * float(Snd.SR) / maxf(1.0, float(b - a)) / 2.0

func _kies(id: String, knop: String) -> bool:
	var s := Hits.spot(id + "_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return false
	var k := s.knoop.get_node_or_null("Rij/K" + knop) as BaseButton
	if k == null:
		return false
	k.emit_signal("pressed")
	return true

func _verkeerd(id: String, goed: int) -> String:
	var s := Hits.spot(id + "_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return ""
	for k in s.knoop.get_node("Rij").get_children():
		var laatste := str((k as Button).text).split(" ")[-1]
		if laatste.is_valid_int() and laatste.to_int() != goed:
			return "n" + laatste
	return ""

## A number card whose game does what every game does: `zacht()` on a slip
## (S5 step 3) and `ja()` + a tick when it is right.
func _kaart(id: String, goed: int, dier: String):
	var kaart = Ui.somkaart({"x": 20.0, "z": 20.0}, "3 + 2 =", {
		"id": id, "door": "test", "kamer": World.kamer_nu(), "goed": goed, "max": 2,
		"icoon": "🥄", "regel": "Hoeveel scheppen samen?", "dier": dier,
		"on_ok": func(n, k) -> void:
			if int(n) != goed:
				Snd.zacht()
				return
			k.klaar()
			Snd.ja()})
	Hits.plaats()
	return kaart

# ------------------------------------------------------------- de geluidjes

func test_elk_dier_heeft_een_sip_en_een_blij_geluidje() -> void:
	var namen: Array = Snd.dier_namen()
	gelijk(namen.size(), 8, "vier soorten, twee stemmingen")
	gelijk(DIEREN, ArtGasten.SOORTEN, "precies de vier soorten gasten")
	for kind in DIEREN:
		waar(namen.has("%s_sip" % kind), "%s heeft een sip geluidje" % kind)
		waar(namen.has("%s_blij" % kind), "%s heeft een blij geluidje" % kind)
	for naam in namen:
		var buf: PackedFloat32Array = Snd.monster(naam)
		waar(not buf.is_empty(), "%s levert monsters" % naam)
		gelijk(buf.size(), int(float(Snd.DIER_LENGTE[naam]) * Snd.SR) + 64, "%s: zo lang als DIER_LENGTE" % naam)
		waar(float(Snd.DIER_LENGTE[naam]) <= 0.7, "%s: de buffer is hooguit 0,7 s" % naam)
		var m := _meet(buf)
		waar(m["piek"] > 0.01, "%s is hoorbaar (%.1f dBFS)" % [naam, _db(m["piek"])])
		waar(m["ms"] <= 600, "%s is kort: %d ms" % [naam, m["ms"]])
		waar(m["ms"] < int(1000.0 * float(Snd.DIER_LENGTE[naam])), "%s past in zijn buffer" % naam)
		var wav: AudioStreamWAV = Snd.stream(naam)
		gelijk(wav.mix_rate, Snd.SR, "%s mix_rate" % naam)
		gelijk(wav.format, AudioStreamWAV.FORMAT_16_BITS, "%s 16 bits" % naam)
		waar(not wav.stereo, "%s mono" % naam)

## The eighteen of the HTML table stay the eighteen, and not one of their
## buffers moved (their oracle is `test_snd.gd`).
func test_de_tabel_van_achttien_blijft() -> void:
	gelijk(Snd.namen().size(), 18, "nog steeds 18")
	for naam in Snd.dier_namen():
		waar(not Snd.namen().has(naam), "%s staat niet in de tabel van de HTML" % naam)
		waar(not Snd.LENGTE.has(naam), "%s heeft zijn eigen lengte, niet in LENGTE" % naam)
	for naam in Snd.namen():
		if not Snd.is_ruis(naam):
			waar(Snd.monster(naam) == Snd.monster(naam), "%s blijft bit-identiek" % naam)

func test_bit_identiek_bij_herhaling() -> void:
	for naam in Snd.dier_namen():
		waar(not Snd.is_ruis(naam), "%s gebruikt geen ruis" % naam)
		waar(Snd.stream(naam).data == Snd.stream(naam).data, "%s: twee keer dezelfde bytes" % naam)

## "Altijd zacht, nooit hard": never a louder sample than the "dat klopt!" of
## `ja`, never a louder moment than the fanfare of `hoera`, and no click at
## either end of a voice.
func test_zacht_en_zonder_klik() -> void:
	var ja := _meet(Snd.monster("ja"))
	var hoera := _meet(Snd.monster("hoera"))
	var zacht := _meet(Snd.monster("zacht"))
	for naam in Snd.dier_namen():
		var buf: PackedFloat32Array = Snd.monster(naam)
		var m := _meet(buf)
		waar(m["piek"] < ja["piek"], "%s: piek %.1f dBFS onder die van ja (%.1f)"
			% [naam, _db(m["piek"]), _db(ja["piek"])])
		waar(_db(m["piek"]) < -24.0, "%s blijft onder -24 dBFS" % naam)
		waar(m["luid"] < hoera["luid"], "%s: nooit zo luid als hoera (%.1f tegen %.1f dB)"
			% [naam, _db(m["luid"]), _db(hoera["luid"])])
		if naam.ends_with("_sip"):
			# the sad one is an "aww", as soft as the "not yet" it stands in for
			waar(_db(m["luid"]) <= _db(zacht["luid"]) + 3.5, "%s: niet harder dan zacht (%.1f tegen %.1f dB)"
				% [naam, _db(m["luid"]), _db(zacht["luid"])])
		waar(absf(buf[0]) < 0.0005 and absf(buf[buf.size() - 1]) < 0.0005, "%s begint en eindigt stil" % naam)
		var sprong := 0.0
		for i in range(1, buf.size()):
			sprong = maxf(sprong, absf(buf[i] - buf[i - 1]))
		waar(sprong < 0.03, "%s klikt nergens (grootste stap %.4f)" % [naam, sprong])

## A sad voice goes down: it ends lower than it began.
func test_sip_zakt() -> void:
	for kind in DIEREN:
		var buf: PackedFloat32Array = Snd.monster("%s_sip" % kind)
		var m := _meet(buf)
		var stuk := int(0.1 * Snd.SR)
		var begin := _toon(buf, m["eerste"], m["eerste"] + stuk)
		var eind := _toon(buf, m["laatst"] - stuk, m["laatst"])
		waar(eind < begin, "%s_sip zakt: %.0f Hz naar %.0f Hz" % [kind, begin, eind])

# ------------------------------------------------------------------ de API

func test_soort_en_terugval() -> void:
	_op()
	for kind in DIEREN:
		gelijk(Snd.soort_van(kind), kind, "een soort is zichzelf")
		gelijk(Snd.dier_geluid(kind, false), "%s_sip" % kind, "sip van de %s" % kind)
		gelijk(Snd.dier_geluid(kind, true), "%s_blij" % kind, "blij van de %s" % kind)
	World.zet(GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "gans"})
	gelijk(Snd.soort_van(GAST), "gans", "een gast-id wordt zijn soort")
	gelijk(Snd.dier_geluid(GAST, true), "gans_blij", "en klinkt als die soort")
	# an unknown animal gets the neutral pair every game already knows
	gelijk(Snd.dier_geluid("draak", false), "zacht", "onbekend en sip: zacht")
	gelijk(Snd.dier_geluid("", true), "ja", "niemand en blij: ja")
	_af()

## Muted, or before the first touch: not one animal sound.
func test_stil_als_het_geluid_uit_staat() -> void:
	_wek(true)
	Snd.dier_sip("hond")
	Snd.dier_blij("poes")
	Snd.dier_blij("gans", 0.05)
	await _wacht(0.15)
	gelijk(Snd.gehoord(), [], "geluid uit: niets gehoord")
	_slaap()
	# before the first touch (the browser's autoplay rule): not a sound either
	_wek()
	Snd._wakker = false
	Snd.dier_sip("konijn")
	Snd.dier_blij("konijn")
	gelijk(Snd.gehoord(), [], "voor de eerste aanraking: niets")
	_slaap()

## The animal's "aww" takes the place of the neutral `zacht` of the same
## moment, whichever of the two came first — a miss is one sound, not two.
func test_het_dier_neemt_de_plek_van_zacht_in() -> void:
	_wek()
	Snd.zacht()
	Snd.dier_sip("hond")
	gelijk(Snd.gehoord(), ["zacht", "stil:zacht", "hond_sip"],
		"zacht eerst: het dier legt het stil en zegt het zelf")
	_vergeet()
	Snd.dier_sip("poes")
	Snd.zacht()
	gelijk(Snd.gehoord(), ["poes_sip"], "het dier eerst: zacht zwijgt")
	# long after the "aww", `zacht` is the plain "not yet" again
	Snd._sip_ms -= Snd.SLIK_MS + 50
	Snd.zacht()
	gelijk(Snd.gehoord().back(), "zacht", "later is zacht gewoon weer zacht")
	# an unknown animal is `zacht` itself, and never twice at once
	_vergeet()
	Snd.zacht()
	Snd.dier_sip("draak")
	gelijk(Snd.gehoord(), ["zacht"], "onbekend dier: één keer zacht")
	_slaap()

## A burst of taps is one voice per mood, not a stutter.
func test_geknepen() -> void:
	_wek()
	Snd.dier_sip("hond")
	Snd.dier_sip("hond")
	Snd.dier_sip("gans")
	Snd.dier_blij("konijn")
	Snd.dier_blij("konijn")
	gelijk(Snd.gehoord(), ["hond_sip", "konijn_blij"],
		"binnen %d ms één sip en één blij" % Snd.DIER_MS)
	_slaap()

## `dier_blij(kind, wacht)` waits for the notes of `ja` and then cheers — and
## a mute in that moment is honoured.
func test_blij_wacht_op_ja() -> void:
	_wek()
	Snd.ja()
	Snd.dier_blij("hond", 0.1)
	gelijk(Snd.gehoord(), ["ja"], "eerst alleen ja")
	await _wacht(0.25)
	gelijk(Snd.gehoord(), ["ja", "hond_blij"], "en dan de hond")
	_vergeet()
	Snd.dier_blij("poes", 0.1)
	Snd._uit = true
	await _wacht(0.25)
	gelijk(Snd.gehoord(), [], "tussendoor uitgezet: stil")
	_slaap()

# ------------------------------------------------------------ in het spel

## `Ui.misser` with a dog in view: the dog goes `sip` and whimpers, and the
## game's own `zacht()` right after it stays quiet.
func test_een_misser_met_een_hond_klinkt_als_een_hond() -> void:
	_op()
	_wek()
	World.zet(GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "hond"})
	var kaart = _kaart("sd1", 5, GAST)
	waar(_kies("sd1", _verkeerd("sd1", 5)), "een verkeerd getal getikt")
	waar(is_sip(GAST), "de hond is sip")
	# the strip's own `tik`, then the dog — and no `zacht` after it
	gelijk(Snd.gehoord(), ["tik", "hond_sip"], "en zegt het zelf, zonder zacht erbij")
	kaart.weg()
	World.weg(GAST)
	# a rabbit without a card (a stroke that fell short)
	_vergeet()
	World.zet(GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "konijn"})
	Snd.zacht()
	Ui.misser(null, GAST, "test")
	gelijk(Snd.gehoord(), ["zacht", "stil:zacht", "konijn_sip"],
		"het konijn neemt de plek van zacht in")
	await _wacht(Ui.MIS_PAUZE + 0.2)
	_slaap()
	_af()

## Muted: the animal still sulks where the child can see it, but silently.
func test_een_misser_zonder_geluid_is_alleen_sip() -> void:
	_op()
	_wek(true)
	World.zet(GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "poes"})
	Ui.misser(null, GAST, "test")
	waar(is_sip(GAST), "de poes is sip")
	gelijk(Snd.gehoord(), [], "zonder geluid")
	await _wacht(Ui.MIS_PAUZE + 0.2)
	_slaap()
	_af()

## An animal out of sight makes no sound: its sulk shows in its own room.
func test_een_dier_buiten_beeld_zwijgt() -> void:
	_op()
	_wek()
	var ander := "kamer2" if World.kamer_nu() != "kamer2" else "kamer1"
	World.zet(GAST, ander, 20.0, 20.0, {"kind": "gans"})
	Ui.misser(null, GAST, "test")
	waar(is_sip(GAST), "de gans is sip in haar eigen kamer")
	gelijk(Snd.gehoord(), [], "maar wie niet in beeld is, zwijgt")
	await _wacht(Ui.MIS_PAUZE + 0.2)
	_slaap()
	_af()

## The right answer: the game plays `ja()`, and the animal of the turn answers
## it with its own happy sound, after the two notes.  With no game running the
## animal is the card's (the desk); with a game running it is the game's.
func test_een_goed_antwoord_maakt_het_dier_blij() -> void:
	_op()
	_wek()
	World.zet(GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "poes"})
	var kaart = _kaart("sd2", 5, GAST)
	gelijk(Ui.dier_van_de_beurt(), GAST, "zonder spel: het dier van de kaart")
	waar(_kies("sd2", "n5"), "het goede getal getikt")
	gelijk(Snd.gehoord(), ["tik", "ja"], "de tik van de knop, dan de twee toontjes van ja")
	await _wacht(Snd.BLIJ_NA + 0.15)
	gelijk(Snd.gehoord(), ["tik", "ja", "poes_blij"], "en dan de blije poes")
	kaart.weg()
	# a running game names its own animal of the turn
	var oud_actief: String = Games._actief
	var oud_speler: String = Games._speler
	Games._actief = "test"
	Games._speler = GAST
	World.zet(GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "konijn"})
	gelijk(Ui.dier_van_de_beurt(), GAST, "met een spel: het dier van de spelbalk")
	_vergeet()
	Snd.ja()
	await _wacht(Snd.BLIJ_NA + 0.15)
	gelijk(Snd.gehoord(), ["ja", "konijn_blij"], "het konijn van de beurt is blij")
	Games._speler = ""
	gelijk(Ui.dier_van_de_beurt(), "", "een spel zonder dier: niemand")
	_vergeet()
	Snd.ja()
	await _wacht(Snd.BLIJ_NA + 0.15)
	gelijk(Snd.gehoord(), ["ja"], "dan blijft het bij ja")
	Games._actief = oud_actief
	Games._speler = oud_speler
	_slaap()
	_af()
