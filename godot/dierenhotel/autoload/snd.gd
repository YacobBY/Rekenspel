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
}
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
	"keuken": "warm", "wasserij": "warm"}
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
