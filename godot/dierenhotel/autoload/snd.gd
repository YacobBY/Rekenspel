extends Node
## Snd — the 18 sounds, synthesised.  Autoload #5.
## Port of `demos/dierenhotel/snd.js` (art-sound-rules.md §15).
##
## DECISION (architecture.md §8): the sounds are generated into an
## `AudioStreamWAV` at first use from the same two generators as the browser
## (`noot` and `papier`), not shipped as samples.  That keeps `plop(hand)`
## pitched per scoop, keeps every splash fresh, and costs nothing to download.
## Master gain stays at 0.16 -> "altijd zacht, nooit hard"; there are no angry
## sounds, `zacht` means "not yet".
##
## W4 fills in the remaining sounds of the §15.3 table; the six below carry the
## skeleton and prove the pipeline.

const MEESTER := 0.16      ## master gain of snd.js
const SR := 22050          ## sample rate; enough for these tones, small buffers
const STEMMEN := 6

var _uit := false
var _wakker := false
var _spelers: Array[AudioStreamPlayer] = []
var _volgende := 0
var _cache: Dictionary = {}

func _ready() -> void:
	for i in STEMMEN:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_spelers.append(p)

## No audio before the first real touch (browser autoplay policy).
func ontgrendel() -> void:
	_wakker = true

func ontgrendeld() -> bool:
	return _wakker

func dempt() -> bool:
	return _uit

func schakel() -> bool:
	_uit = not _uit
	State.zet_geluid(not _uit)
	if not _uit:
		ontgrendel()
		tik()
	return _uit

# ------------------------------------------------------------- generatoren

## `noot(f, to, duur, vorm, top, wacht)` — one oscillator with an exponential
## attack of min(35 ms, 30 % of the duration) and an exponential decay.
func _noot(uit: PackedFloat32Array, f: float, naar: float, duur: float,
		vorm: String, top: float, wacht: float) -> void:
	var n := int(duur * SR)
	var start := int(wacht * SR)
	var aanzet := maxf(0.001, minf(0.035, duur * 0.3))
	var fase := 0.0
	for i in n:
		var t := float(i) / SR
		var freq := f
		if naar > 0.0 and not is_equal_approx(naar, f):
			freq = f * pow(maxf(40.0, naar) / f, t / duur)
		fase += TAU * freq / SR
		var v := sin(fase)
		if vorm == "triangle":
			v = asin(sin(fase)) * (2.0 / PI)
		var g := 0.0
		if t < aanzet:
			g = 0.0001 * pow(top / 0.0001, t / aanzet)
		else:
			g = top * pow(0.0001 / top, (t - aanzet) / maxf(0.001, duur - aanzet))
		var k := start + i
		if k >= 0 and k < uit.size():
			uit[k] += v * g * MEESTER

## `papier(duur, freq, top, wacht)` — band-passed white noise with a linear fade.
func _papier(uit: PackedFloat32Array, duur: float, freq: float, top: float, wacht: float) -> void:
	var n := int(duur * SR)
	var start := int(wacht * SR)
	var band := 0.0
	var f := clampf(2.0 * PI * freq / SR, 0.0, 1.5)
	for i in n:
		var ruis := randf() * 2.0 - 1.0
		var fade := 1.0 - float(i) / float(maxi(1, n))
		band += f * (ruis - band)
		var v := (ruis - band) * fade
		var k := start + i
		if k >= 0 and k < uit.size():
			uit[k] += v * top * MEESTER

func _maak(duur: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(duur * SR) + 64)
	buf.fill(0.0)
	return buf

func _stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
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
		var buf: PackedFloat32Array = bouw.call()
		stream = _stream(buf)
		if not vers:
			_cache[naam] = stream
	else:
		stream = _cache[naam]
	var p := _spelers[_volgende]
	_volgende = (_volgende + 1) % STEMMEN
	p.stream = stream
	p.play()

# ------------------------------------------------------------- de geluiden

func tik() -> void:
	_speel("tik", func():
		var b := _maak(0.10)
		_noot(b, 720, 620, 0.07, "sine", 0.30, 0.0)
		return b)

func ja() -> void:
	_speel("ja", func():
		var b := _maak(0.30)
		_noot(b, 660, 0, 0.10, "triangle", 0.42, 0.0)
		_noot(b, 880, 0, 0.16, "triangle", 0.42, 0.09)
		return b)

## "not yet" — never a buzzer.
func zacht() -> void:
	_speel("zacht", func():
		var b := _maak(0.40)
		_noot(b, 430, 0, 0.15, "sine", 0.30, 0.0)
		_noot(b, 340, 0, 0.22, "sine", 0.26, 0.13)
		return b)

func ster() -> void:
	_speel("ster", func():
		var b := _maak(0.40)
		_noot(b, 784, 0, 0.09, "triangle", 0.30, 0.0)
		_noot(b, 988, 0, 0.09, "triangle", 0.28, 0.07)
		_noot(b, 1319, 0, 0.20, "sine", 0.24, 0.14)
		return b)

## `plop(hand)` — a fuller hand sounds a little higher (480 + 40*hand Hz).
func plop(hand: int = 0) -> void:
	_speel("plop%d" % hand, func():
		var b := _maak(0.20)
		_noot(b, 480 + 40 * hand, 190, 0.13, "sine", 0.5, 0.0)
		return b)

## Noise sounds are rebuilt per call, so every splash is a new one (§15.4).
func plons() -> void:
	var bouw := func():
		var b := _maak(0.30)
		_noot(b, 560, 150, 0.14, "sine", 0.40, 0.0)
		_papier(b, 0.20, 1500, 0.28, 0.03)
		_papier(b, 0.13, 800, 0.16, 0.10)
		return b
	_speel("plons", bouw, true)

# W4: terug, tover, dag, brief, hoera, bel, deur, kar, munt, au, klok, hup
func terug() -> void: pass
func tover() -> void: pass
func dag() -> void: pass
func brief() -> void: pass
func hoera() -> void: pass
func bel() -> void: pass
func deur() -> void: pass
func kar() -> void: pass
func munt() -> void: pass
func au() -> void: pass
func klok() -> void: pass
func hup() -> void: pass
