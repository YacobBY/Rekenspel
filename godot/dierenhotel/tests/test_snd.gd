extends Proef
## W4 — the 18 synthesised sounds against the WAV export of the running HTML
## engine (art-sound-rules.md §15.3/§15.4, architecture.md §8).
##
## The oracle is `tests/gouden/wav/*.wav` — the eighteen sounds as the browser
## renders them offline at 48 kHz, trimmed to their audible length plus 30 ms of
## tail (445 kB instead of 2.6 MB of silence) — with `tests/gouden/snd-oracle.json`
## next to it: per sound the sample count, the peak, the RMS, the audible length,
## an RMS envelope in 16 slices, and the spread of eight independent exports.
## "Audible" is the last sample above amplitude 0.001, exactly as
## `snd-export.js` measures it.  Nothing here depends on /tmp any more.
##
## Tolerance (architecture.md §8): peak within 1 dB, audible length within
## 10 ms.
##
## The four sounds that use `papier()` need a statistical form of the same
## claim, because their peak is a random variable: the noise is fresh per call,
## which is the design (§15.4, finding 1), and the export froze ONE particular
## splash.  A single render sits between -1.9 and +1.6 dB from that frozen one.
## So for those four the test asserts (a) the mean over 48 renders within
## 1.5 dB, (b) the frozen peak lies inside the range this generator produces,
## and (c) the median audible length within 10 ms.  Measured: brief -0.49,
## deur +0.07, kar +0.41, plons -0.75 dB.

const ORAKEL := "res://tests/gouden/snd-oracle.json"
const WAV := "res://tests/gouden/wav"
const TOL_DB := 1.0
const TOL_RUIS_DB := 1.5  ## the mean of a fresh splash against one frozen splash
const TOL_MS := 10
const RONDEN := 48        ## renders per noise sound
const TOL_OMHUL_DB := 2.0        ## per RMS slice, oscillator sounds (measured <= 0.71)
## Per RMS slice for the four noise sounds.  A slice of a FROZEN splash and a
## slice of a FRESH one differ by the noise itself; averaging eight renders
## takes this side's scatter out, but the reference is still one draw.  Measured
## over 24 renders: at most 3.4 dB on a single slice, 1.9 dB on the mean of 8.
const TOL_OMHUL_RUIS_DB := 5.0
const OMHUL_RONDEN := 8          ## renders averaged per noise sound

func _meta() -> Dictionary:
	var uit := {}
	if not FileAccess.file_exists(ORAKEL):
		return uit
	var d = JSON.parse_string(FileAccess.get_file_as_string(ORAKEL))
	if typeof(d) != TYPE_ARRAY:
		return uit
	for m in d:
		uit[m["naam"]] = m
	return uit

## Read one reference WAV.  A `.gdignore` keeps the folder out of the importer
## and out of the export, so this parses the RIFF by hand instead of loading a
## resource — twenty lines, and it proves the file itself is intact.
func _wav(naam: String) -> Dictionary:
	var pad := "%s/%s.wav" % [WAV, naam]
	if not FileAccess.file_exists(pad):
		return {}
	var b := FileAccess.get_file_as_bytes(pad)
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or b.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {}
	var kanalen := 0
	var sr := 0
	var bits := 0
	var i := 12
	while i + 8 <= b.size():
		var soort := b.slice(i, i + 4).get_string_from_ascii()
		var maat := b.decode_u32(i + 4)
		var romp := i + 8
		if soort == "fmt ":
			kanalen = b.decode_u16(romp + 2)
			sr = b.decode_u32(romp + 4)
			bits = b.decode_u16(romp + 14)
		elif soort == "data":
			var n := maat / 2
			var uit := PackedFloat32Array()
			uit.resize(n)
			for k in n:
				uit[k] = float(b.decode_s16(romp + k * 2)) / 32768.0
			return {"sr": sr, "kanalen": kanalen, "bits": bits, "monsters": uit}
		i = romp + maat + (maat & 1)
	return {}

## The RMS of 16 equal time slices of a signal, trimmed like the reference:
## everything up to the last sample above 0.001 plus 30 ms of tail.
func _plakken(buf: PackedFloat32Array, sr: int) -> Array[float]:
	var laatst := 0
	for i in buf.size():
		if absf(buf[i]) > 0.001:
			laatst = i
	var eind := mini(buf.size(), laatst + int(0.03 * sr))
	var uit: Array[float] = []
	for k in 16:
		var a := int(float(k) * eind / 16.0)
		var b := int(float(k + 1) * eind / 16.0)
		var som := 0.0
		var n := maxi(1, b - a)
		for i in range(a, b):
			som += buf[i] * buf[i]
		uit.append(sqrt(som / n))
	return uit

func _db(x: float) -> float:
	return 20.0 * log(maxf(x, 1e-9)) / log(10.0)

## {piek, ms} of one render.
func _meet(buf: PackedFloat32Array) -> Dictionary:
	var piek := 0.0
	var laatst := 0
	for i in buf.size():
		var a := absf(buf[i])
		if a > piek:
			piek = a
		if a > 0.001:
			laatst = i
	return {"piek": piek, "ms": int(round(1000.0 * float(laatst) / float(Snd.SR)))}

# ------------------------------------------------------------------ de tabel

func test_alle_achttien_bestaan() -> void:
	var namen := Snd.namen()
	gelijk(namen.size(), 18, "18 geluiden (art-sound-rules.md §15.3)")
	for naam in namen:
		waar(Snd.has_method(naam), "Snd.%s() bestaat" % naam)
		waar(not Snd.monster(naam).is_empty(), "Snd.%s levert monsters" % naam)
	# the table of the spec, name for name
	gelijk(",".join(namen),
		"tik,plop,terug,zacht,ja,tover,dag,brief,hoera,bel,deur,kar,munt,ster,plons,au,klok,hup",
		"dezelfde namen als §15.3")

func test_monsteraantal_klopt_met_de_lengte() -> void:
	for naam in Snd.namen():
		var verwacht := int(float(Snd.LENGTE[naam]) * Snd.SR) + 64
		var buf := Snd.monster(naam)
		gelijk(buf.size(), verwacht, "%s monsteraantal" % naam)
		var wav := Snd.stream(naam)
		gelijk(wav.data.size(), verwacht * 2, "%s 16-bits bytes" % naam)
		gelijk(wav.mix_rate, Snd.SR, "%s mix_rate" % naam)
		waar(not wav.stereo, "%s is mono" % naam)
		gelijk(wav.format, AudioStreamWAV.FORMAT_16_BITS, "%s 16 bits" % naam)
		# the whole sound has to fit inside its buffer
		var m := _meet(buf)
		waar(m["ms"] < int(1000.0 * float(Snd.LENGTE[naam])),
			"%s past in zijn buffer (%d ms van %d)" % [naam, m["ms"], int(1000.0 * float(Snd.LENGTE[naam]))])

func test_piek_en_lengte_tegen_de_export() -> void:
	var meta := _meta()
	if meta.is_empty():
		fout("tests/gouden/snd-oracle.json ontbreekt")
		return
	var regels: Array[String] = []
	for naam in Snd.namen():
		var ref: Dictionary = meta[naam]
		var ref_db: float = float(ref["dBFS"])
		if bool(ref.get("ruis", false)):
			ref_db = float(ref["runs"]["dB_gem"])   # eight exports, not one draw
		var db := 0.0
		var ms := 0
		var grens := TOL_DB
		var extra := ""
		if Snd.is_ruis(naam):
			var som := 0.0
			var laagste := INF
			var hoogste := -INF
			var lengtes: Array[int] = []
			for i in RONDEN:
				var m := _meet(Snd.monster(naam))
				som += m["piek"]
				laagste = minf(laagste, m["piek"])
				hoogste = maxf(hoogste, m["piek"])
				lengtes.append(m["ms"])
			lengtes.sort()
			db = _db(som / float(RONDEN))
			ms = lengtes[RONDEN / 2]
			grens = TOL_RUIS_DB
			extra = "   ruis %.2f..%.2f dB (bron %.2f..%.2f over 8 export-runs)" \
				% [_db(laagste) - ref_db, _db(hoogste) - ref_db,
				float(ref["runs"]["dB_min"]), float(ref["runs"]["dB_max"])]
			# the browser's own spread must lie inside the spread of this
			# generator: the same sound, drawn from the same kind of noise
			waar(float(ref["runs"]["dB_gem"]) >= _db(laagste) - 0.5
				and float(ref["runs"]["dB_gem"]) <= _db(hoogste) + 0.5,
				"%s: het browsergemiddelde (%.2f dB) ligt in het bereik %.2f..%.2f"
				% [naam, float(ref["runs"]["dB_gem"]), _db(laagste), _db(hoogste)])
		else:
			var m := _meet(Snd.monster(naam))
			db = _db(m["piek"])
			ms = m["ms"]
		var ddb: float = db - ref_db
		var dms: int = ms - int(ref["duurMs"])
		regels.append("%-6s %7.2f dB (ref %5.1f, %+5.2f)  %4d ms (ref %4d, %+3d)%s"
			% [naam, db, ref_db, ddb, ms, int(ref["duurMs"]), dms, extra])
		waar(absf(ddb) <= grens, "%s piek %.2f dB van de export (max %.1f)" % [naam, ddb, grens])
		waar(absi(dms) <= TOL_MS, "%s hoorbare lengte %d ms van de export (max %d)"
			% [naam, dms, TOL_MS])
	var f := FileAccess.open("user://snd-rapport.txt", FileAccess.WRITE)
	if f != null:
		f.store_line("W4 — de 18 geluiden tegen de WAV-export van de HTML-motor")
		for r in regels:
			f.store_line(r)
		f.close()

## §15.4, finding 1: two renders of an oscillator-only sound are bit-identical;
## every sound that uses `papier()` is a new one.
func test_bepaaldheid() -> void:
	for naam in Snd.namen():
		var a := Snd.stream(naam).data
		var b := Snd.stream(naam).data
		if Snd.is_ruis(naam):
			waar(a != b, "%s is elke keer nieuw (verse ruis)" % naam)
		else:
			waar(a == b, "%s is bit-identiek bij herhaling" % naam)

## `plop(hand)` keeps its parameter: 480 + 40*hand Hz.  Samples could not do
## that (§19 Q-X4-6).
func test_plop_houdt_zijn_hand() -> void:
	var a := Snd.stream("plop", 0).data
	var b := Snd.stream("plop", 3).data
	waar(a != b, "een vollere hand klinkt anders")
	var n0 := _nuldoorgangen(Snd.monster("plop", 0))
	var n3 := _nuldoorgangen(Snd.monster("plop", 3))
	waar(n3 > n0, "hand 3 klinkt hoger: %d nuldoorgangen tegen %d" % [n3, n0])

func _nuldoorgangen(buf: PackedFloat32Array) -> int:
	var n := 0
	var vorig := 0.0
	for v in buf:
		if absf(v) < 0.0005:
			continue
		if (v > 0.0) != (vorig > 0.0):
			n += 1
		vorig = v
	return n

# ------------------------------------------------------------- de gedragsregels

## No sound before the first real input (browser autoplay policy, §8).
func test_niets_voor_de_eerste_tik() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var snd = boom.root.get_node_or_null(NodePath("Snd"))
	waar(snd != null, "Snd bestaat")
	# a fresh Snd node behaves as at boot: nothing plays before ontgrendel()
	var vers = load("res://autoload/snd.gd").new()
	boom.root.add_child(vers)
	waar(not vers.ontgrendeld(), "band staat uit tot de eerste aanraking")
	vers.tik()
	var speelt := false
	for kind in vers.get_children():
		if kind is AudioStreamPlayer and kind.playing:
			speelt = true
	waar(not speelt, "geen geluid voor ontgrendel()")
	vers.ontgrendel()
	waar(vers.ontgrendeld(), "na ontgrendel() is de band wakker")
	vers.queue_free()

## The master gain stays 0.16 — "altijd zacht, nooit hard".
func test_meester_blijft_zacht() -> void:
	gelijk(Snd.MEESTER, 0.16, "meestervolume")
	var meta := _meta()
	for naam in Snd.namen():
		if meta.has(naam):
			waar(float(meta[naam]["dBFS"]) < -20.0, "%s blijft onder -20 dBFS" % naam)

## `zacht` is the "not yet" sound and must never be a buzzer (F5): one soft
## sine falling from 430 to 340 Hz, no noise, no dissonance.
func test_zacht_is_geen_zoemer() -> void:
	var buf := Snd.monster("zacht")
	var m := _meet(buf)
	waar(m["piek"] < 0.06, "zacht blijft zacht (%.4f)" % m["piek"])
	waar(not Snd.is_ruis("zacht"), "zacht gebruikt geen ruis")

## The hall clock never strikes twice within 120 ms (architecture.md §6.5).
func test_klok_wordt_geknepen() -> void:
	var vers = load("res://autoload/snd.gd").new()
	var boom := Engine.get_main_loop() as SceneTree
	boom.root.add_child(vers)
	vers.ontgrendel()
	waar(not vers._te_snel("klok", vers.KLOK_MS), "de eerste slag mag")
	waar(vers._te_snel("klok", vers.KLOK_MS), "de tweede binnen 120 ms niet")
	vers.queue_free()

## The reference WAVs themselves are the oracle: this reads all eighteen back,
## checks that the file is intact and that `snd-oracle.json` really describes
## it, so a corrupted or half-copied fixture can never pass silently.
func test_referentiewavs_zijn_heel() -> void:
	var meta := _meta()
	if meta.is_empty():
		fout("snd-oracle.json ontbreekt")
		return
	for naam in Snd.namen():
		var w := _wav(naam)
		if w.is_empty():
			fout("%s: geen referentie-wav in tests/gouden/wav/" % naam)
			continue
		var ref: Dictionary = meta[naam]
		gelijk(w["sr"], int(ref["sr"]), "%s referentie-sr" % naam)
		gelijk(w["kanalen"], 1, "%s referentie is mono" % naam)
		gelijk(w["bits"], 16, "%s referentie is 16 bits" % naam)
		var buf: PackedFloat32Array = w["monsters"]
		gelijk(buf.size(), int(ref["monsters"]), "%s referentie-monsters" % naam)
		var m := _meet(buf)
		waar(absf(_db(m["piek"]) - float(ref["dBFS"])) < 0.05,
			"%s: de wav draagt de piek uit het orakel" % naam)

## The waveform, not only its loudest sample: the RMS envelope of sixteen equal
## time slices of this synthesis against the same sixteen slices of the
## browser's render.  That catches a wrong envelope, a wrong glide and a wrong
## filter, which a peak measurement happily sleeps through.
func test_omhullende_volgt_de_browser() -> void:
	var meta := _meta()
	if meta.is_empty():
		fout("snd-oracle.json ontbreekt")
		return
	var regels: Array[String] = []
	for naam in Snd.namen():
		var ref: Dictionary = meta[naam]
		var bron: Array = ref["plakken"]
		var mijn := _plakken(Snd.monster(naam), Snd.SR)
		if Snd.is_ruis(naam):
			# average the envelope: one fresh splash scatters, eight do not
			for r in OMHUL_RONDEN - 1:
				var nog := _plakken(Snd.monster(naam), Snd.SR)
				for k in 16:
					mijn[k] += nog[k]
			for k in 16:
				mijn[k] /= float(OMHUL_RONDEN)
		var ergst := 0.0
		var waar_ergst := -1
		for k in 16:
			var a: float = float(bron[k])
			var b: float = mijn[k]
			# a slice below -60 dBFS is silence; do not divide by it
			if a < 0.001 and b < 0.001:
				continue
			var d: float = absf(_db(b) - _db(a))
			if d > ergst:
				ergst = d
				waar_ergst = k
		regels.append("%-6s omhullende max %5.2f dB (plak %d)" % [naam, ergst, waar_ergst])
		var grens := TOL_OMHUL_RUIS_DB if Snd.is_ruis(naam) else TOL_OMHUL_DB
		waar(ergst <= grens, "%s: plak %d wijkt %.2f dB af (max %.1f)"
			% [naam, waar_ergst, ergst, grens])
	var f := FileAccess.open("user://snd-omhullende.txt", FileAccess.WRITE)
	if f != null:
		f.store_line("W4 — RMS-omhullende in 16 plakken, tegen de browser-render")
		for r in regels:
			f.store_line(r)
		f.close()
