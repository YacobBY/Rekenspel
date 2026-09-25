extends Node
## Snd — the 18 sounds, synthesised.  Autoload #5.
## Port of `demos/dierenhotel/snd.js` (art-sound-rules.md §15).
##
## DECISION (architecture.md §8): the sounds are generated into an
## `AudioStreamWAV` at first use from the same two generators as the browser
## (`noot` and `papier`), not shipped as samples.  That keeps `plop(hand)`
## pitched per scoop, keeps every splash fresh, and costs nothing to download.
## Master gain stays at 0.16 -> "altijd zacht, nooit hard"; there are no angry
## sounds, `zacht` means "not yet" and is the most-used sound in the game.
##
## Two generators and nothing else:
##   `noot(f, naar, duur, vorm, top, wacht)` — one oscillator, an exponential
##     attack of min(35 ms, 30 % of the duration) and an exponential decay to
##     −80 dB at `duur`, with an optional exponential glide from f to `naar`.
##   `papier(duur, freq, top, wacht)` — white noise with a linear fade-out
##     through a bandpass (Q = 0.7), the RBJ biquad WebAudio uses.
##
## Oscillator-only sounds are cached per name; noise sounds are rebuilt per
## call, so every splash is a new one, exactly as in the browser (§15.4).
##
## Peaks and audible lengths are asserted against the WAV export of the running
## HTML engine in `tests/test_snd.gd` (±1 dB, ±10 ms).

const MEESTER := 0.16      ## master gain of snd.js
const SR := 22050          ## sample rate; enough for these tones, small buffers
const REF_SR := 48000.0    ## sample rate of the reference export (§15.4)
const STEMMEN := 6
const STIL := 0.0001       ## the floor of both exponential ramps in WebAudio
const KLOK_MS := 120       ## the hall clock never strikes twice within this

## How long a buffer has to be, per sound: max(wacht + duur) plus a little air.
const LENGTE := {
	"tik": 0.10, "plop": 0.20, "terug": 0.15, "zacht": 0.40, "ja": 0.30,
	"tover": 0.80, "dag": 0.40, "brief": 0.35, "hoera": 1.15, "bel": 0.40,
	"deur": 0.20, "kar": 0.30, "munt": 0.20, "ster": 0.40, "plons": 0.30,
	"au": 0.30, "klok": 0.60, "hup": 0.12,
	"ding": 1.70,
	"trap_op": 0.62, "trap_af": 0.62,
}
## Seconds between two footfalls on the stairs (`trap`).
const TRAP_STAP := 0.14
## The four that use `papier()`: fresh noise per call, never cached (§15.4).
const RUIS := ["brief", "deur", "kar", "plons"]

var _uit := false
var _wakker := false
var _spelers: Array[AudioStreamPlayer] = []
var _sfeer: AudioStreamPlayer = null
var _sfeer_naam := ""
var _sfeer_cache: Dictionary = {}
var _volgende := 0
var _cache: Dictionary = {}
var _laatst: Dictionary = {}
var _schaal_cache: Dictionary = {}

func _ready() -> void:
	for i in STEMMEN:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_spelers.append(p)
	_sfeer = AudioStreamPlayer.new()
	_sfeer.bus = "Master"
	add_child(_sfeer)
	World.kamer_veranderd.connect(sfeer)

## No audio before the first real touch (browser autoplay policy).  After this
## every sound is a normal AudioStreamPlayer; there is no per-sound unlock trick.
func ontgrendel() -> void:
	_wakker = true
	sfeer(World.kamer_nu())

func ontgrendeld() -> bool:
	return _wakker

func dempt() -> bool:
	return _uit

## Push the SAVED setting into the mixer.  `schakel()` is the child's own toggle
## and WRITES the save; this one only reads it, because after a reload the save
## is the truth and the shell has to hand it over — the mute used to be decided
## on the first tap, which is the "Verder spelen ▸" tap that happens BEFORE the
## saved state is swapped in, so a saved `geluid=false` came back on (V1-2).
## It never unlocks the audio: that stays tied to the first real touch (§8).
func stem_af(aan: bool) -> void:
	_uit = not aan
	sfeer(World.kamer_nu())

func schakel() -> bool:
	_uit = not _uit
	State.zet_geluid(not _uit)
	if not _uit:
		ontgrendel()
		tik()
	sfeer(World.kamer_nu())
	return _uit

## Everything stops when the app goes to the background — the browser suspends
## the audio band there too (§15.1).
func _notification(wat: int) -> void:
	if wat == NOTIFICATION_APPLICATION_PAUSED or wat == NOTIFICATION_WM_CLOSE_REQUEST \
			or wat == NOTIFICATION_APPLICATION_FOCUS_OUT:
		for p in _spelers:
			p.stop()
		_sfeer_stop()
	elif wat == NOTIFICATION_APPLICATION_RESUMED or wat == NOTIFICATION_APPLICATION_FOCUS_IN:
		sfeer(World.kamer_nu())

# ------------------------------------------------------------- sfeer (kamergeluid)
#
# Room ambience (review plan 2026-09-14, pillar 1): one looping buffer per kind
# of room, generated like the sounds themselves and played on its own player
# far under the master gain — the garden breathes, the hall clock ticks, the
# pool laps, the kitchen and the laundry hum.  Not one of the 18 (`namen()` is
# frozen by test_snd), never louder than a third of a sound, silent when the
# game is muted, asleep or in the background.

const SFEER := {"tuin": "wind", "receptie": "tiktak", "zwembad": "water",
	"keuken": "warm", "wasserij": "warm", "speelzaal": "speeldoos",
	# R3: the glass house hums warm like the kitchen — a reused loop, no new one
	"kas": "warm",
	# the shopping arcade plays the playroom's music box: a shop with music
	"winkels": "speeldoos"}
const SFEER_DUUR := 4.0        ## seconds per loop; every modulation divides it
const SFEER_TOP := 0.30        ## of MEESTER: the ceiling of any ambience sample

## Which ambience a room has; "" for a quiet room (the corridor, the bedrooms).
func sfeer_naam(kamer: String) -> String:
	return str(SFEER.get(kamer, ""))

## Play the ambience of `kamer`, or stop when it has none / the sound is off.
func sfeer(kamer: String = "") -> void:
	if _sfeer == null:
		return
	var naam := sfeer_naam(kamer if not kamer.is_empty() else World.kamer_nu())
	if naam.is_empty() or _uit or not _wakker:
		_sfeer_stop()
		return
	if naam == _sfeer_naam and _sfeer.playing:
		return
	_sfeer_naam = naam
	if not _sfeer_cache.has(naam):
		_sfeer_cache[naam] = sfeer_stream(naam)
	_sfeer.stream = _sfeer_cache[naam]
	_sfeer.play()

func _sfeer_stop() -> void:
	_sfeer_naam = ""
	if _sfeer != null and _sfeer.playing:
		_sfeer.stop()

func sfeer_speelt() -> String:
	return _sfeer_naam if _sfeer != null and _sfeer.playing else ""

## The looping stream of one ambience, without playing it.
func sfeer_stream(naam: String) -> AudioStreamWAV:
	var buf := sfeer_monster(naam)
	var wav := _stream(buf)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = buf.size()
	return wav

## The raw loop of one ambience, `SFEER_DUUR` seconds, seamless at the seam:
## every low-frequency modulation has a whole number of periods in the loop.
func sfeer_monster(naam: String) -> PackedFloat32Array:
	var n := int(SFEER_DUUR * SR)
	var b := PackedFloat32Array()
	b.resize(n)
	b.fill(0.0)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash(naam)
	match naam:
		"wind":
			# a summer breeze: low-passed noise that swells twice per loop, and
			# two short bird chirps
			_ruisband(b, rnd, 0.06, 0.05, 0.5)
			_noot(b, 2300, 2900, 0.07, "sine", 0.06, 1.15)
			_noot(b, 2700, 2200, 0.06, "sine", 0.05, 1.27)
			_noot(b, 2500, 3100, 0.07, "sine", 0.06, 3.05)
		"tiktak":
			# the hall clock: tick at 0 s, tock at 1 s, and again — 60 a minute
			for i in int(SFEER_DUUR):
				_noot(b, 1500 if i % 2 == 0 else 1150, 0, 0.022, "sine", 0.11, float(i))
		"water":
			# the pool lapping: darker noise, one slow swell per loop
			_ruisband(b, rnd, 0.03, 0.06, 0.25)
		"warm":
			# a cosy room: a very low hum with a breath of noise over it
			var f := 110.0            # 440 whole periods in a 4 s loop
			for i in n:
				b[i] += sin(TAU * f * float(i) / SR) * 0.10 * MEESTER
			_ruisband(b, rnd, 0.015, 0.025, 0.5)
		"speeldoos":
			# R2: the playroom music box — C E G E, one note per second, a
			# whole number of periods each so the loop seam is silent, over a
			# soft breath of noise
			var tonen := [880.0, 1109.0, 1319.0, 1109.0]
			for i in int(SFEER_DUUR):
				_noot(b, tonen[i], 0, 0.55, "sine", 0.05, float(i))
			_ruisband(b, rnd, 0.012, 0.02, 0.5)
	return b

## Low-passed white noise that swells with a slow sine: `alfa` is the one-pole
## coefficient (smaller is darker), `top` the peak as a fraction of MEESTER,
## `hz` the swell rate — a whole number of swells per loop keeps the seam clean.
func _ruisband(b: PackedFloat32Array, rnd: RandomNumberGenerator, alfa: float, top: float, hz: float) -> void:
	var y := 0.0
	var n := b.size()
	for i in n:
		y += alfa * (rnd.randf_range(-1.0, 1.0) - y)
		var zwel := 0.6 + 0.4 * sin(TAU * hz * float(i) / SR)
		b[i] += y * zwel * top * MEESTER / maxf(0.05, sqrt(alfa))

# ------------------------------------------------------------- generatoren

## `noot(f, to, duur, vorm, top, wacht)` — one oscillator with an exponential
## attack of min(35 ms, 30 % of the duration) and an exponential decay.
func _noot(uit: PackedFloat32Array, f: float, naar: float, duur: float,
		vorm: String, top: float, wacht: float) -> void:
	var n := int(duur * SR)
	var start := int(wacht * SR)
	var aanzet := maxf(0.001, minf(0.035, duur * 0.3))
	var glij := naar > 0.0 and not is_equal_approx(naar, f)
	var doel := maxf(40.0, naar)
	var fase := 0.0
	var stijg := top / STIL
	var daal := STIL / top
	var na_aanzet := maxf(0.001, duur - aanzet)
	for i in n:
		var t := float(i) / SR
		var freq := f
		if glij:
			freq = f * pow(doel / f, t / duur)
		fase += TAU * freq / SR
		var v := sin(fase)
		if vorm == "triangle":
			v = asin(sin(fase)) * (2.0 / PI)
		var g := 0.0
		if t < aanzet:
			g = STIL * pow(stijg, t / aanzet)
		else:
			g = top * pow(daal, (t - aanzet) / na_aanzet)
		var k := start + i
		if k >= 0 and k < uit.size():
			uit[k] += v * g * MEESTER

## A struck partial for `ding`: a 3 ms attack (a hammer, not a bow — `_noot`
## always fades in over up to 35 ms) and an exponential ring that is 60 dB down
## at `duur`.
func _slag(uit: PackedFloat32Array, f: float, duur: float, top: float, wacht: float) -> void:
	var n := int(duur * SR)
	var start := int(wacht * SR)
	var aanzet := 0.003
	var fase := 0.0
	for i in n:
		var t := float(i) / SR
		fase += TAU * f / SR
		var g := top * (t / aanzet if t < aanzet else exp(-6.9 * (t - aanzet) / maxf(0.01, duur - aanzet)))
		var k := start + i
		if k >= 0 and k < uit.size():
			uit[k] += sin(fase) * g * MEESTER

## `papier(duur, freq, top, wacht)` — white noise with a linear fade through a
## bandpass filter.  The filter is the RBJ constant-0-dB-peak biquad, which is
## exactly what a WebAudio `BiquadFilterNode` of type 'bandpass' is.
##
## The noise is scaled so it carries the same power as the browser's 48 kHz
## render: white noise carries its power per SAMPLE, so the same bandpass at a
## lower sample rate passes a louder band.  The factor is the ratio of the two
## filters' impulse-response energies, not a flat sqrt(SR / 48000) — the digital
## bandwidth is frequency-warped, so 1500 Hz needs 0.732 where 300 Hz needs
## 0.689.  Without it the splash is 3.4 dB too loud and the sounds drift up to
## 0.9 dB apart from the export.
func _papier(uit: PackedFloat32Array, duur: float, freq: float, top: float, wacht: float) -> void:
	var n := maxi(16, int(duur * SR))
	var start := int(wacht * SR)
	var w0 := TAU * freq / SR
	var alfa := sin(w0) / (2.0 * 0.7)          # Q = 0.7
	var a0 := 1.0 + alfa
	var b0 := alfa / a0
	var b2 := -alfa / a0
	var a1 := -2.0 * cos(w0) / a0
	var a2 := (1.0 - alfa) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var schaal := top * MEESTER * _ruis_schaal(freq)
	for i in n:
		var x := (randf() * 2.0 - 1.0) * (1.0 - float(i) / float(n))
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		var k := start + i
		if k >= 0 and k < uit.size():
			uit[k] += y * schaal

## sqrt(energy of the reference filter / energy of ours), cached per frequency.
func _ruis_schaal(freq: float) -> float:
	if _schaal_cache.has(freq):
		return _schaal_cache[freq]
	var f := sqrt(_bp_energie(freq, REF_SR) / maxf(1e-12, _bp_energie(freq, float(SR))))
	_schaal_cache[freq] = f
	return f

## The impulse-response energy (sum of h[n]^2) of the RBJ bandpass, i.e. its
## power gain for white noise.  The response of a Q = 0.7 pole pair is down to
## 1e-12 well within 6000 samples.
func _bp_energie(freq: float, sr: float) -> float:
	var w0 := TAU * freq / sr
	var alfa := sin(w0) / (2.0 * 0.7)
	var a0 := 1.0 + alfa
	var b0 := alfa / a0
	var b2 := -alfa / a0
	var a1 := -2.0 * cos(w0) / a0
	var a2 := (1.0 - alfa) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var e := 0.0
	for i in 6000:
		var x := 1.0 if i == 0 else 0.0
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		e += y * y
	return e

func _maak(duur: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(duur * SR) + 64)
	buf.fill(0.0)
	return buf

func _stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = data
	return wav

func _speel(naam: String, bouw: Callable, vers := false) -> void:
	if _uit or not _wakker:
		return
	var stream: AudioStreamWAV
	if vers or not _cache.has(naam):
		stream = _stream(bouw.call())
		if not vers:
			_cache[naam] = stream
	else:
		stream = _cache[naam]
	var p := _spelers[_volgende]
	_volgende = (_volgende + 1) % STEMMEN
	p.stream = stream
	p.play()
	# the animal voices (see "de dieren" below) listen to what just started
	_begonnen(naam, p)

## Not more often than every `ms` milliseconds — the hall clock may be turned
## with a fast finger and must not stutter (architecture.md §6.5, step 8).
func _te_snel(naam: String, ms: int) -> bool:
	var nu := Time.get_ticks_msec()
	if _laatst.has(naam) and nu - int(_laatst[naam]) < ms:
		return true
	_laatst[naam] = nu
	return false

# ------------------------------------------------------------- de geluiden
#
# The Dutch comment above each sound is the one from snd.js, verbatim.

## zacht tikje op een knop
func tik() -> void:
	_speel("tik", _bouw.bind("tik"))

## koekje valt in een bakje: een vollere hand klinkt iets hoger
func plop(hand: int = 0) -> void:
	_speel("plop%d" % hand, _bouw.bind("plop", hand))

## een koekje rolt terug de zak in
func terug() -> void:
	_speel("terug", _bouw.bind("terug"))

## dat is het nog niet - zacht meedenken, nooit een nee-geluid
func zacht() -> void:
	# an animal of the turn just said its own sad "aww" (`dier_sip`, 2026-09-24):
	# that IS the "not yet" of this moment, so this one stays quiet under it
	if _net_sip():
		return
	_speel("zacht", _bouw.bind("zacht"))

## dat klopt! twee vrolijke toontjes
func ja() -> void:
	_speel("ja", _bouw.bind("ja"))

## eerlijk verdeeld of een vriend die jou uitkiest: kleine magie
func tover() -> void:
	_speel("tover", _bouw.bind("tover"))

## goedemorgen, een nieuwe dag in de steeg
func dag() -> void:
	_speel("dag", _bouw.bind("dag"))

## een brief door de brievenbus
func brief() -> void:
	_speel("brief", _bouw.bind("brief"), true)

## hoera! adoptiedag en het grote einde
func hoera() -> void:
	_speel("hoera", _bouw.bind("hoera"))

## de bel op de balie: helder, kort, nooit hard
func bel() -> void:
	_speel("bel", _bouw.bind("bel"))

## DING — de receptiebel waar het kind op drukt (eigenaar, 2026-09-23: "geef
## de bel een ding geluid").  Geen noot uit de tabel van de HTML (die `bel` blijft
## zoals hij is, met zijn referentie-export): een aangeslagen belletje, met de
## boventonen van een klein metalen belletje en een lange, zachte naklank.
func ding() -> void:
	_speel("ding", _bouw.bind("ding"))

## TIK-TIK-TIK-TIK — voetstappen op de trap naar een andere verdieping
## (eigenaar, 2026-09-25: "Ik wil graag de lift vervangen voor een trap").  Vier
## houten treden, elke stap een doffe tik met een klikje erop: naar boven klimt
## de toon, naar beneden zakt hij.  Niet uit de tabel van de HTML, net als
## `ding`, en zonder ruis, dus elke keer hetzelfde.
func trap(op: bool) -> void:
	var naam := "trap_op" if op else "trap_af"
	_speel(naam, _bouw.bind(naam))

## een deur die opengaat en weer dichtvalt
func deur() -> void:
	_speel("deur", _bouw.bind("deur"), true)

## de voerkar rolt over de gang
func kar() -> void:
	_speel("kar", _bouw.bind("kar"), true)

## een munt op de toonbank
func munt() -> void:
	_speel("munt", _bouw.bind("munt"))

## een sterretje erbij
func ster() -> void:
	_speel("ster", _bouw.bind("ster"))

## een dier glijdt het zwembad in: een plons met wat spetters
func plons() -> void:
	_speel("plons", _bouw.bind("plons"), true)

## zachte bots tegen de wand: een klein "au", nooit een schrikgeluid.  Hier
## wordt niemand gestraft, dus blijft het laag, kort en rond.
func au() -> void:
	_speel("au", _bouw.bind("au"))

## de halklok slaat een keer: een zachte gong die nog even naklinkt
func klok(force := false) -> void:
	# `force`: the strike at the right hour is never throttled (games-b §2.9)
	if not force and _te_snel("klok", KLOK_MS):
		return
	_speel("klok", _bouw.bind("klok"))

## hup, een sprongetje naar de volgende steen
func hup() -> void:
	_speel("hup", _bouw.bind("hup"))

# --------------------------------------------------------------- de recepten

## Every sound as a buffer, from the parameter table of art-sound-rules.md
## §15.3.  Public, because `tests/test_snd.gd` measures peak and audible length
## on it without waking the audio band.
func _bouw(naam: String, hand := 0) -> PackedFloat32Array:
	if DIER_LENGTE.has(naam):
		return _bouw_dier(naam)       # the eight animal voices, below
	var b := _maak(LENGTE.get(naam, 0.5))
	match naam:
		"tik":
			_noot(b, 720, 620, 0.07, "sine", 0.30, 0.0)
		"plop":
			# a fuller hand sounds a little higher; a sample could not do that
			_noot(b, 480 + 40 * hand, 190, 0.13, "sine", 0.5, 0.0)
		"terug":
			_noot(b, 300, 460, 0.09, "sine", 0.28, 0.0)
		"zacht":
			_noot(b, 430, 0, 0.15, "sine", 0.30, 0.0)
			_noot(b, 340, 0, 0.22, "sine", 0.26, 0.13)
		"ja":
			_noot(b, 660, 0, 0.10, "triangle", 0.42, 0.0)
			_noot(b, 880, 0, 0.16, "triangle", 0.42, 0.09)
		"tover":
			var n := [523, 659, 784, 1047]
			for i in 4:
				_noot(b, n[i], 0, 0.5 if i == 3 else 0.11, "triangle", 0.34, i * 0.08)
		"dag":
			_noot(b, 587, 0, 0.12, "sine", 0.26, 0.0)
			_noot(b, 784, 0, 0.22, "sine", 0.24, 0.11)
		"brief":
			_papier(b, 0.16, 1100, 0.5, 0.0)
			_papier(b, 0.10, 700, 0.4, 0.10)
			_noot(b, 660, 0, 0.12, "sine", 0.22, 0.16)
		"hoera":
			var n := [523, 659, 784, 1047]
			for i in 4:
				_noot(b, n[i], 0, 0.14, "triangle", 0.40, i * 0.13)
			_noot(b, 1047, 0, 0.55, "triangle", 0.34, 0.52)
			_noot(b, 1319, 0, 0.55, "sine", 0.22, 0.52)
		"bel":
			_noot(b, 1046, 0, 0.34, "sine", 0.42, 0.0)
			_noot(b, 1568, 0, 0.28, "sine", 0.20, 0.04)
		"ding":
			# a small struck bell: the ring, a second one 3.5 Hz above it that
			# makes it shimmer, the inharmonic overtones of a metal cup (2.76x,
			# 5.40x) that die first, and a click of the hammer
			_slag(b, 1318.5, 1.60, 0.46, 0.0)
			_slag(b, 1322.0, 1.30, 0.16, 0.0)
			_slag(b, 3639.1, 0.50, 0.13, 0.0)
			_slag(b, 7119.9, 0.16, 0.05, 0.0)
			_slag(b, 2637.0, 0.05, 0.06, 0.0)
		"trap_op", "trap_af":
			# four footfalls on wooden treads, TRAP_STAP apart: a dull thump
			# that drops a fifth and a short click of the heel on the nosing;
			# each step a whole tone higher going up, lower going down
			for i in 4:
				var toon := pow(2.0, (float(i) if naam == "trap_op" else float(3 - i)) / 6.0)
				var t := TRAP_STAP * float(i)
				_noot(b, 190.0 * toon, 125.0 * toon, 0.08, "sine", 0.34, t)
				_noot(b, 880.0 * toon, 620.0 * toon, 0.025, "triangle", 0.09, t)
		"deur":
			_noot(b, 250, 190, 0.11, "sine", 0.26, 0.0)
			_papier(b, 0.09, 520, 0.22, 0.06)
		"kar":
			_papier(b, 0.24, 300, 0.26, 0.0)
			_noot(b, 170, 210, 0.22, "sine", 0.16, 0.0)
		"munt":
			_noot(b, 1180, 0, 0.07, "triangle", 0.34, 0.0)
			_noot(b, 1560, 0, 0.10, "sine", 0.20, 0.05)
		"ster":
			_noot(b, 784, 0, 0.09, "triangle", 0.30, 0.0)
			_noot(b, 988, 0, 0.09, "triangle", 0.28, 0.07)
			_noot(b, 1319, 0, 0.20, "sine", 0.24, 0.14)
		"plons":
			_noot(b, 560, 150, 0.14, "sine", 0.40, 0.0)
			_papier(b, 0.20, 1500, 0.28, 0.03)
			_papier(b, 0.13, 800, 0.16, 0.10)
		"au":
			_noot(b, 240, 180, 0.09, "sine", 0.26, 0.0)
			_noot(b, 430, 350, 0.16, "sine", 0.20, 0.06)
		"klok":
			_noot(b, 659, 0, 0.55, "sine", 0.36, 0.0)
			_noot(b, 988, 0, 0.40, "sine", 0.16, 0.02)
		"hup":
			_noot(b, 430, 720, 0.08, "sine", 0.30, 0.0)
		_:
			return PackedFloat32Array()
	return b

## Every name in the order of the table of art-sound-rules.md §15.3.
func namen() -> Array:
	return ["tik", "plop", "terug", "zacht", "ja", "tover", "dag", "brief", "hoera",
		"bel", "deur", "kar", "munt", "ster", "plons", "au", "klok", "hup"]

## The raw buffer of one sound, for tests and for a future offline export.
func monster(naam: String, hand := 0) -> PackedFloat32Array:
	return _bouw(naam, hand)

## The finished stream of one sound, without playing it.
func stream(naam: String, hand := 0) -> AudioStreamWAV:
	return _stream(_bouw(naam, hand))

## Whether a sound uses `papier()` and therefore sounds different every time.
func is_ruis(naam: String) -> bool:
	return RUIS.has(naam)

# ------------------------------------------------------------------ de dieren
#
# Every guest kind has two little voices of its own (owner, 2026-09-24: "Kan je
# ook een passend droevig teleurgesteld geluidje en een enthousiast bij success
# geluidje bij elk dier maken?"): `<kind>_sip` when the animal of the turn is
# disappointed after a wrong answer, `<kind>_blij` when its answer was right.
# They are not in the HTML table — `namen()` stays the eighteen, with their
# oracle — but they are made the same way: oscillators only, cached per name,
# bit-identical on every call (no noise, so nothing to seed).
#
# The house rules hold for them too: short (at most half a second), under the
# master gain, no buzzer and no harsh fall — the sad one is an "aww", never a
# "nee".
#
# Where they sound (art-sound-rules.md §15.5, architecture.md §8):
#   sad    `Ui.misser`: the animal in view goes `sip` and says so; a wrong
#          payment in a shop sends it out with the same sound.  The animal's
#          "aww" REPLACES the neutral `zacht()` of the same moment, in either
#          order within `SLIK_MS`, so a miss is one sound and not two.
#   happy  every `ja()` ("dat klopt!"): `Ui` hears it through `gespeeld`, and
#          the animal of the turn, when it stands in view, cheers `BLIJ_NA`
#          seconds later — first the two notes, then the animal, never on top.

## Buffer length per animal voice: max(wacht + duur) plus a little air.
const DIER_LENGTE := {
	"hond_sip": 0.58, "hond_blij": 0.30,
	"poes_sip": 0.58, "poes_blij": 0.40,
	"konijn_sip": 0.38, "konijn_blij": 0.38,
	"gans_sip": 0.50, "gans_blij": 0.40,
}
const DIEREN := ["hond", "poes", "konijn", "gans"]   ## = ArtGasten.SOORTEN
const DIER_MS := 400      ## one animal voice per mood within this many ms
const SLIK_MS := 150      ## a `zacht` this close to an animal's "aww" is swallowed
const BLIJ_NA := 0.20     ## s after `ja()` before the animal of the turn cheers
const GEHOORD_MAX := 32

## A sound was handed to a voice (after `play()`): `Ui` listens for "ja" to let
## the animal of the turn cheer.
signal gespeeld(naam: String)

var laatste := ""                    ## the last sound that really started
var _gehoord: Array[String] = []      ## the last GEHOORD_MAX starts; "stil:x" = x cut short
var _begin: Dictionary = {}           ## name -> [ticks_msec, player] of its last start
var _sip_ms := -100000                ## ticks_msec of the last animal "aww"

func _begonnen(naam: String, p: AudioStreamPlayer) -> void:
	laatste = naam
	_begin[naam] = [Time.get_ticks_msec(), p]
	_onthoud(naam)
	gespeeld.emit(naam)

func _onthoud(wat: String) -> void:
	_gehoord.append(wat)
	if _gehoord.size() > GEHOORD_MAX:
		_gehoord.remove_at(0)

## What started lately, oldest first — for the tests and the probe.
func gehoord() -> Array[String]:
	return _gehoord.duplicate()

## Did `naam` start within the last `ms` milliseconds?
func _net(naam: String, ms: int) -> bool:
	return _begin.has(naam) and Time.get_ticks_msec() - int(_begin[naam][0]) <= ms

func _net_sip() -> bool:
	return Time.get_ticks_msec() - _sip_ms <= SLIK_MS

## Cut `naam` short when it started within `ms` and its voice still has it.
func _smoor(naam: String, ms: int) -> void:
	if not _net(naam, ms):
		return
	var p = _begin[naam][1]
	_begin.erase(naam)
	if p is AudioStreamPlayer and is_instance_valid(p) and p.stream == _cache.get(naam):
		p.stop()
		_onthoud("stil:" + naam)

## The eight voices, kind by kind, the sad one first.
func dier_namen() -> Array:
	var uit := []
	for kind in DIEREN:
		uit.append("%s_sip" % kind)
		uit.append("%s_blij" % kind)
	return uit

## The guest kind of `wie` — a kind itself ("hond") or a guest id ("boef") —
## or "" when it is neither.
func soort_van(wie: String) -> String:
	if wie.is_empty():
		return ""
	if DIEREN.has(wie):
		return wie
	var d = World.dier(wie)
	if d != null and DIEREN.has(str(d.kind)):
		return str(d.kind)
	if State.s is Dictionary and State.s.has("gasten"):
		var kind := str(State.gast_van(wie).get("kind", ""))
		if DIEREN.has(kind):
			return kind
	return ""

## The sound `dier_sip`/`dier_blij` plays for `wie`.  An unknown kind gets the
## neutral pair every game already knows: `zacht` when sad, `ja` when happy.
func dier_geluid(wie: String, blij: bool) -> String:
	var kind := soort_van(wie)
	if kind.is_empty():
		return "ja" if blij else "zacht"
	return "%s_%s" % [kind, "blij" if blij else "sip"]

## The animal of the turn is disappointed: its own soft, sad little sound, in
## the place of a `zacht()` that started just before it.
func dier_sip(wie: String) -> void:
	if _uit or not _wakker:
		return
	var naam := dier_geluid(wie, false)
	if naam == "zacht":
		if not _net("zacht", SLIK_MS):
			zacht()
		return
	if _te_snel("dier_sip", DIER_MS):
		return
	_smoor("zacht", SLIK_MS)
	_speel(naam, _bouw.bind(naam))
	_sip_ms = Time.get_ticks_msec()

## The animal of the turn got it right: its own short, happy sound — at once,
## or `wacht` seconds later (`Ui` waits `BLIJ_NA` for the notes of `ja()`).
func dier_blij(wie: String, wacht := 0.0) -> void:
	if _uit or not _wakker:
		return
	var naam := dier_geluid(wie, true)
	if naam == "ja" and _net("ja", DIER_MS):
		return                      # the neutral "dat klopt!" has just sounded
	if _te_snel("dier_blij", DIER_MS):
		return
	if wacht <= 0.0 or not is_inside_tree():
		_speel(naam, _bouw.bind(naam))
		return
	# `_speel` looks at the mute again when the timer fires
	get_tree().create_timer(wacht).timeout.connect(_speel.bind(naam, _bouw.bind(naam)))

## `stem(f, piek, naar, duur, top, wacht, o)` — an animal's voice.  One pitch
## contour in two exponential glides (f to `piek` over the first `knik` of the
## note, `piek` to `naar` over the rest; `piek` 0 is one glide f to `naar`), a
## few harmonics whose balance moves from `boven` to `boven_naar` (a vowel that
## closes: the bright "mi" of "miauw" into its round "auw"), an optional
## vibrato (`tril`, a fraction of the pitch, at `tril_hz`), an optional purr of
## the loudness (`rol` Hz, the cat's trill) and an optional decay (`verval`).
## The envelope rises as sin² over `aan` seconds and falls as cos² over the
## last `los` of the note to exactly zero, so a voice never clicks; the
## harmonics are normalised, so `top` is a ceiling as it is for `_noot`.
func _stem(uit: PackedFloat32Array, f: float, piek: float, naar: float, duur: float,
		top: float, wacht: float, o: Dictionary = {}) -> void:
	var boven: Array = o.get("boven", [1.0, 0.3, 0.1])
	var boven_naar: Array = o.get("boven_naar", boven)
	var knik: float = clampf(float(o.get("knik", 0.3)), 0.05, 0.95)
	var aan: float = maxf(0.002, float(o.get("aan", 0.02)))
	var los: float = clampf(float(o.get("los", 0.35)), 0.05, 1.0)
	var tril: float = float(o.get("tril", 0.0))
	var tril_hz: float = float(o.get("tril_hz", 6.0))
	var rol: float = float(o.get("rol", 0.0))
	var verval: float = float(o.get("verval", 0.0))
	var n := int(duur * SR)
	var start := int(wacht * SR)
	var h := maxi(boven.size(), boven_naar.size())
	var los_van := duur * (1.0 - los)
	var fase := 0.0
	for i in n:
		var t := float(i) / SR
		var u := t / duur
		var freq := f
		if piek <= 0.0:
			freq = f * pow(naar / f, u)
		elif u < knik:
			freq = f * pow(piek / f, u / knik)
		else:
			freq = piek * pow(naar / piek, (u - knik) / (1.0 - knik))
		if tril > 0.0:
			freq *= 1.0 + tril * sin(TAU * tril_hz * t)
		fase += TAU * freq / SR
		var v := 0.0
		var som := 0.0
		for k in h:
			var a0: float = float(boven[k]) if k < boven.size() else 0.0
			var a1: float = float(boven_naar[k]) if k < boven_naar.size() else 0.0
			var a := lerpf(a0, a1, u)
			v += a * sin(fase * float(k + 1))
			som += a
		v /= maxf(1.0, som)
		var g := 1.0
		if t < aan:
			g = pow(sin(0.5 * PI * t / aan), 2.0)
		if t > los_van:
			g *= pow(cos(0.5 * PI * (t - los_van) / maxf(0.001, duur - los_van)), 2.0)
		if rol > 0.0:
			g *= 0.6 + 0.4 * cos(TAU * rol * t)
		if verval > 0.0:
			g *= exp(-verval * u)
		var j := start + i
		if j >= 0 and j < uit.size():
			uit[j] += v * g * top * MEESTER

## The eight recipes.  Every pitch stays in the band a tablet speaker plays
## well (a thump is a quick fall from ~240 Hz, not a sub-bass), every top stays
## at or under the one of `ja` (0.42).
func _bouw_dier(naam: String) -> PackedFloat32Array:
	var b := _maak(float(DIER_LENGTE[naam]))
	match naam:
		"hond_sip":
			# a soft whimper: a small "hn", then a long trembling "iieuw" that
			# falls away — the ears go down with it
			_stem(b, 760, 840, 690, 0.13, 0.17, 0.0,
				{"boven": [1.0, 0.25, 0.08], "knik": 0.35, "los": 0.5})
			_stem(b, 900, 980, 520, 0.38, 0.21, 0.15,
				{"boven": [1.0, 0.3, 0.1], "boven_naar": [1.0, 0.1, 0.02], "knik": 0.18,
				"tril": 0.03, "tril_hz": 9.0, "los": 0.5, "verval": 0.6})
		"hond_blij":
			# two bright little yips, the second one higher: "wuf-wuf!"
			var yip := {"boven": [1.0, 0.55, 0.3, 0.12], "knik": 0.3, "aan": 0.008, "los": 0.55}
			_stem(b, 520, 860, 600, 0.09, 0.30, 0.0, yip)
			_stem(b, 600, 1000, 700, 0.10, 0.30, 0.14, yip)
		"poes_sip":
			# a small "miauw" that goes down: a bright "mi", a round "auw"
			_stem(b, 640, 780, 440, 0.52, 0.25, 0.0,
				{"boven": [1.0, 0.5, 0.3, 0.12], "boven_naar": [1.0, 0.12, 0.03, 0.0],
				"knik": 0.28, "aan": 0.05, "tril": 0.012, "tril_hz": 6.0, "los": 0.4,
				"verval": 0.4})
		"poes_blij":
			# a purring trill that climbs, and a chirp on top of it: "mrrrp!"
			_stem(b, 430, 0, 660, 0.22, 0.21, 0.0,
				{"boven": [1.0, 0.3, 0.1], "rol": 30.0, "aan": 0.02, "los": 0.25})
			_stem(b, 720, 1120, 960, 0.12, 0.24, 0.21,
				{"boven": [1.0, 0.35, 0.12], "knik": 0.45, "aan": 0.01, "los": 0.5})
		"konijn_sip":
			# a small low squeak, and a soft thump of a hind paw
			_stem(b, 700, 760, 520, 0.16, 0.20, 0.0,
				{"boven": [1.0, 0.15], "knik": 0.25, "aan": 0.012, "los": 0.5})
			_stem(b, 230, 0, 85, 0.09, 0.30, 0.22,
				{"boven": [1.0, 0.4, 0.15], "aan": 0.004, "los": 0.75})
		"konijn_blij":
			# a happy hop: two quick high squeaks, each landing on a soft thump
			var piep := {"boven": [1.0, 0.2], "knik": 0.5, "aan": 0.006, "los": 0.5}
			var bons := {"boven": [1.0, 0.4, 0.15], "aan": 0.004, "los": 0.75}
			_stem(b, 1100, 1400, 1250, 0.06, 0.20, 0.0, piep)
			_stem(b, 240, 0, 90, 0.07, 0.28, 0.07, bons)
			_stem(b, 1250, 1600, 1450, 0.06, 0.20, 0.17, piep)
			_stem(b, 250, 0, 95, 0.07, 0.28, 0.24, bons)
		"gans_sip":
			# one low honk that sinks: a goose that had hoped for more
			_stem(b, 330, 350, 230, 0.44, 0.28, 0.0,
				{"boven": [1.0, 0.55, 0.4, 0.25, 0.12], "boven_naar": [1.0, 0.3, 0.15, 0.06, 0.02],
				"knik": 0.15, "aan": 0.03, "tril": 0.02, "tril_hz": 5.0, "los": 0.45,
				"verval": 0.4})
		"gans_blij":
			# two honks that go up: "hoenk-HOENK!"
			var toet := {"boven": [1.0, 0.5, 0.35, 0.2, 0.1], "aan": 0.015, "los": 0.4}
			_stem(b, 360, 0, 450, 0.15, 0.30, 0.0, toet)
			_stem(b, 430, 0, 560, 0.18, 0.32, 0.17, toet)
	return b
