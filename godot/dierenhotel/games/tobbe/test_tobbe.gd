extends Proef
## Tobbe-tijd (games-a.md §6) — headless suite, written by the lead after the
## worker was stopped before its tests: registration, the recipe per band from
## `Sommen.Tobbe`, one whole turn, a miss that never punishes, the reload from
## `ctx.data()`, a clean `stop()`, the §6.6 strings, and coverage on four
## frames.

const ID := "tobbe"
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

var _laag: Control = null

func _op(kader := Vector2(1000, 648)) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	State.nieuw_spel()
	State.start_gekozen()
	Econ.rekening_stop()
	State.s["taken"] = []
	Hotel.bord_dicht()
	World.naar("tuin")
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	if Games.actief() != "":
		Games.stop()
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

## `n` guests in real beds, on day `dag`, with `kunnen` bands unlocked.
func _gasten(n: int, dag := 1, kunnen := 3) -> Array:
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in n:
		var g: Dictionary = pool[i % pool.size()]
		if i < bedden.size():
			g["kamer"] = str(bedden[i]["kamer"])
			g["bed"] = str(bedden[i]["slot"])
			g["waar"] = str(g["kamer"])
		else:
			g["kamer"] = ""
			g["bed"] = ""
			g["waar"] = "receptie"
		g["nachten"] = 100
		uit.append(g)
	State.s["gasten"] = uit
	State.s["dag"] = dag
	State.s["kunnen"] = kunnen
	State.herbereken()
	World.zet_dag(dag)
	World.sync(uit)
	return uit

func _spel():
	return Games._knoop

## The four words on the strip under the question card.
func _keuzes() -> Array:
	var uit: Array = []
	var s := Hits.spot("tb_vraag_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return uit
	var rij := s.knoop.get_node_or_null("Rij")
	if rij == null:
		return uit
	for k in rij.get_children():
		uit.append(str((k as Button).text))
	return uit

## Tap the number `n` on that strip, exactly as a finger does (there is no
## keypad: one tap on one of at most four buttons, HOTEL.md §9).
func _tik_keuze(n: int) -> bool:
	var s := Hits.spot("tb_vraag_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return false
	var rij := s.knoop.get_node_or_null("Rij")
	if rij == null:
		return false
	var k := rij.get_node_or_null("Kn%d" % n) as BaseButton
	if k == null:
		return false
	k.emit_signal("pressed")
	return true

## The right answer of the opening question: the whole double, one tub-full
## otherwise.
func _juist(s: Dictionary) -> int:
	return int(s["T"]) if str(s["soort"]) == "dubbel" else int(s["per"])

## How many guests really own a bed — the recipe counts those (`_gasten()` of
## the game), while `State.band()` counts every guest in the hotel.
func _met_bed() -> int:
	var n := 0
	for g in State.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			n += 1
	return n

## The first day on which the frozen core serves this `soort`.
func _dag_met(soort: String, n: int, band: int) -> int:
	for dag in range(1, 20):
		if str(Sommen.Tobbe.recept(n, band, dag)["soort"]) == soort:
			return dag
	return 0

## Which guest count and which `kunnen` put `State.band()` on 3, 4 and 5.
const OPZET := [
	{"band": 3, "kunnen": 2, "gasten": 3},
	{"band": 4, "kunnen": 3, "gasten": 5},
	{"band": 5, "kunnen": 4, "gasten": 7},
]

## Lay the table for one band and one soort, and start the game.
func _begin(opzet: Dictionary, soort: String):
	_op()
	_gasten(int(opzet["gasten"]), 1, int(opzet["kunnen"]))
	var band := State.band()
	gelijk(band, int(opzet["band"]), "band %d bij %d gasten" % [int(opzet["band"]), int(opzet["gasten"])])
	var dag := _dag_met(soort, _met_bed(), band)
	waar(dag > 0, "band %d kent de soort %s" % [band, soort])
	if dag <= 0:
		return null
	State.s["dag"] = dag
	World.zet_dag(dag)
	if not Games.start(ID):
		fout("het spel start niet (band %d, %s)" % [band, soort])
		return null
	var spel = _spel()
	if spel == null:
		fout("geen spelknoop (band %d, %s)" % [band, soort])
		return null
	gelijk(str(spel._s["soort"]), soort, "de soort van dag %d op band %d" % [dag, band])
	return spel

# ------------------------------------------------------------ 1. aanmelding

func test_aanmelding_en_definitie() -> void:
	waar(Games.lijst().has(ID), "tobbe staat in het register")
	var d := Games.definitie(ID)
	gelijk(str(d["naam"]), "Tobbe-tijd", "naam")
	gelijk(str(d["kamer"]), "tuin", "kamer")
	gelijk(str(d["wens"]), "bad", "de wens 🛁 hoort bij dit spel")
	gelijk(str(d["hotspot"]["obj"]), "tobbe", "de knop hangt op de tobbe")
	gelijk(str(d["hotspot"]["icoon"]), "🛁", "met het badje als pictogram")
	waar(bool(d["unlock"].call(1, 3)), "vanaf één gast")
	waar(not bool(d["unlock"].call(0, 3)), "zonder gasten niet")

# ------------------------------------------------------- 2. recept per band

## The stand comes straight from the frozen `Sommen.Tobbe.recept`, for every
## band and for two guest counts.
func test_recept_komt_uit_de_bevroren_kern() -> void:
	for kunnen in [2, 3, 4]:
		for n in [1, 3]:
			_op()
			_gasten(n, 2, kunnen)
			waar(Games.start(ID), "het spel start (%d gasten, kunnen %d)" % [n, kunnen])
			var spel = _spel()
			if spel == null:
				_af()
				continue
			var s: Dictionary = spel.stand()
			var r := Sommen.Tobbe.recept(n, State.band(), 2)
			gelijk(int(s["T"]), int(r["T"]), "T uit het recept")
			gelijk(int(s["M"]), int(r["M"]), "M uit het recept")
			gelijk(int(s["per"]), int(r["per"]), "per uit het recept")
			gelijk(int(s["rest"]), int(r["rest"]), "rest uit het recept")
			gelijk(str(s["soort"]), str(r["soort"]), "soort uit het recept")
			gelijk(int(s["per"]) * int(s["M"]) + int(s["rest"]), int(s["T"]),
				"per × M + rest = T")
			waar(int(s["M"]) >= 2, "minstens twee tobbes")
			_af()

# ----------------------------------------------------------- 3. een beurt

## Everything on the rack goes into the tubs, the rest into the can: the check
## passes, the guests may bathe, and the turn is saved as done in progress.
func test_eerlijk_verdelen_slaagt() -> void:
	_op()
	_gasten(3, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel._s
	if str(s["soort"]) != "eerlijk":
		# the recipe of this day is a question card, not the filling step
		_af()
		return
	# N4: elke ronde begint met de som, ook `eerlijk` — daarna pas het sjouwen
	gelijk(str(s["stap"]), "vraag", "eerst de som")
	waar(_tik_keuze(int(s["per"])), "de helft aantikken")
	gelijk(str(spel._s["stap"]), "vullen", "daarna mag er geschept worden")
	for i in int(s["M"]):
		s["tob"][i] = int(s["per"])
	s["rek"] = 0
	s["kan"] = int(s["rest"])
	spel._check()
	gelijk(str(spel._s["stap"]), "baden", "na een goede verdeling mag iedereen in bad")
	gelijk(int(spel._s["missers"]), 0, "zonder misser")
	var d := State.spel_data(ID)
	gelijk(str(d["stand"]["stap"]), "baden", "en dat staat in de savegame")
	_af()

## The bath fills itself since wave 2 (owner, 2026-10-08: "rekenen moet
## minstens 50% van de interactie zijn"): a tap per animal was play, not maths.
## Who stands in the garden goes into the emptiest tub by himself, one after
## another, with bubbles — there is no button per animal any more, and a tap on
## a tub during the bath does nothing.  Tobbe has no animal of the turn, so no
## button on the game bar either.  (Until wave 2 the child tapped every animal
## into the bath — owner 2026-09-23.)
func test_wie_je_aantikt_gaat_in_bad() -> void:
	_op()
	var gasten := _gasten(3, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		_af()
		return
	gelijk(Games.speler(), "", "tobbe heeft geen dier van de beurt")
	gelijk(Games.spelers().size(), 0, "en dus geen dierknop op de spelbalk")
	for i in gasten.size():
		World.zet(str(gasten[i]["id"]), "tuin", 60.0 + 10.0 * i, 110.0)
	# the share is right: the water is ready and the bath step begins
	var st: Dictionary = spel._s
	st["stap"] = "vullen"
	st["rek"] = 0
	for i in int(st["M"]):
		st["tob"][i] = int(st["per"])
	st["kan"] = int(st["rest"])
	spel._check()
	gelijk(str(spel._s["stap"]), "baden", "de badstap")
	for g in gasten:
		waar(Hits.spot("tb_dier" + str(g["id"])) == null, "geen knopje voor %s" % str(g["id"]))
	waar(Hits.spot("tb_klaar") == null, "en geen ✓ om het baden af te ronden")
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	while spel._in_bad_ids().size() < mini(gasten.size(), 2 * int(st["M"])) \
			and Time.get_ticks_msec() - t0 < 6000:
		await boom.process_frame
	var erin: Array = spel._in_bad_ids()
	gelijk(erin.size(), mini(gasten.size(), 2 * int(st["M"])), "iedereen in de tuin ging vanzelf in bad (%s)" % str(erin))
	spel._tik_tobbe(0)
	gelijk(spel._in_bad_ids().size(), erin.size(), "een tik op een tobbe doet in de badstap niets")
	t0 = Time.get_ticks_msec()
	while str(spel._s["stap"]) != "af" and Time.get_ticks_msec() - t0 < 6000:
		await boom.process_frame
	gelijk(str(spel._s["stap"]), "af", "en daarna is het vanzelf klaar")
	_af()

## Eigenaar, 2026-09-23: "Zorg dat de minigame pas begint wanneer het dier er
## is."  Na de som lopen de badgasten van elders naar de tobbes en tot ze er
## staan hangt het hotelwolkje "komt eraan" met `👀 Volg` aan de tuindeur — ook
## tijdens het spel.  Wie meeloopt en met hem terugkomt, vindt de kaart van de
## tobbes weer op haar plek.  Sinds wave 2 gaat hij er dan vanzelf in (geen
## knopje per dier meer).
func test_een_badgast_van_elders_komt_eraan() -> void:
	_op()
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	var gasten := _gasten(3, 1, 3)
	var id := str(gasten[0]["id"])
	gasten[0]["behoefte"] = "bad"
	gasten[0]["blij"] = false
	World.zet(id, str(gasten[0]["kamer"]), 60.0, 60.0)   # in zijn eigen kamer
	World.pauzeer(true)                     # de test tikt de wereld zelf
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		World.pauzeer(false)
		Ui.zet_rust_modus(rust_voor)
		_af()
		return
	# de som is af en het sop eerlijk verdeeld: het water staat klaar
	var st: Dictionary = spel._s
	st["stap"] = "vullen"
	st["rek"] = 0
	for i in int(st["M"]):
		st["tob"][i] = int(st["per"])
	st["kan"] = int(st["rest"])
	spel._check()
	gelijk(str(spel._s["stap"]), "baden", "de badstap")
	waar(Games.verwacht_dier(id), "het spel wacht op de badgast")
	waar(not spel._in_bad_ids().has(id), "hij zit nog niet in bad")
	waar(_komt_eraan_in_beeld(id), "zijn wolkje 'komt eraan' hangt aan de tuindeur")
	var som = Hits.spot("tb_som")
	waar(som != null and som.knoop.visible, "de kaart van de tobbes staat er")
	var wolk = Hits.spot("komt_" + id)
	if wolk != null and is_instance_valid(wolk.knoop):
		(wolk.knoop as BaseButton).pressed.emit()
	gelijk(Hotel.volgt(), id, "👀 Volg: de camera loopt met hem mee")
	waar(World.kamer_nu() != "tuin", "naar de kamer waar hij is")
	Hits.plaats()
	som = Hits.spot("tb_som")
	waar(som != null and not som.knoop.visible, "de kaart van de tobbes blijft in de tuin")
	var t := 0
	while not Hotel.volgt().is_empty() and t < 5000:
		World._tik()
		Hotel._volg_stap()
		t += 1
	gelijk(World.kamer_nu(), "tuin", "de camera eindigt bij de tobbes")
	gelijk(Games.actief(), ID, "en het spel loopt nog")
	Hits.plaats()
	som = Hits.spot("tb_som")
	waar(som != null and som.knoop.visible, "terug in de tuin staat de kaart weer")
	var d: Dictionary = Hits.debug().get("tb_som", {})
	var r: Rect2 = d.get("rect", Rect2())
	waar(r.size.x > 0.0 and r.position.x >= -0.01 and r.end.x <= _laag.size.x + 0.01
		and r.position.y >= -0.01 and r.end.y <= _laag.size.y + 0.01,
		"opnieuw neergelegd, binnen het kader (%s)" % str(r))
	waar(_tik_tot_hij_staat(id, "tuin"), "hij loopt naar de tobbes")
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	while not spel._in_bad_ids().has(id) and Time.get_ticks_msec() - t0 < 3000:
		await boom.process_frame
	waar(spel._in_bad_ids().has(id), "hij staat er: hij gaat vanzelf in bad")
	World.pauzeer(false)
	Ui.zet_rust_modus(rust_voor)
	_af()

## Tick until `id` stands still in `kamer`: arrived, not walking any more.
func _tik_tot_hij_staat(id: String, kamer: String) -> bool:
	var d = World.dier(id)
	var t := 0
	while d != null and t < 5000 and not (d.kamer == kamer and str(d.reis_doel).is_empty()
			and (d.route as Array).is_empty() and (d.punten as Array).is_empty()):
		World._tik()
		t += 1
	return d != null and d.kamer == kamer and (d.punten as Array).is_empty()

## Tick until `id` has stepped into `kamer` (and may still walk on in it).
func _tik_tot_hij_binnen_is(id: String, kamer: String) -> bool:
	var d = World.dier(id)
	var t := 0
	while d != null and d.kamer != kamer and t < 5000:
		World._tik()
		t += 1
	return d != null and d.kamer == kamer

## Real time, frames running, until hotspot `id` exists.
func _staat_er_binnen(id: String, ms: int) -> bool:
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		if Hits.spot(id) != null:
			return true
		await boom.process_frame
	return Hits.spot(id) != null

## The hotel's "komt eraan" bubble of `id` hangs in the room in view, and stands
## on the glass while the game runs.
func _komt_eraan_in_beeld(id: String) -> bool:
	Hotel.komt_eraan()
	Hits.plaats()
	var w := Hits.spot("komt_" + id)
	return w != null and is_instance_valid(w.knoop) and w.knoop.visible

## Wait out the pause `Ui.misser` puts on the strip after a miss (S5).
func _wacht_mispauze() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(Ui.MIS_PAUZE * 1000.0) + 250
	while Time.get_ticks_msec() < eind:
		await boom.process_frame

## A number on the strip that is not the answer.
func _fout_getal(goed: int) -> int:
	var s := Hits.spot("tb_vraag_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return -1
	for k in s.knoop.get_node("Rij").get_children():
		var n := int(str(k.name).trim_prefix("Kn"))
		if n != goed:
			return n
	return -1

## The owner, 2026-09-24: "Nee geef geen hulp na fouten.  Kinderen moeten zelf
## leren rekenen.  Fout antwoord kiezen moet niet beloond worden met hulp maar
## juist een teleurgesteld dier."  One, two and three wrong answers to the soap
## sum: the strip pauses with `🔄 Nog een keer` at the card, and after the pause
## the card and the tubs are exactly what they were — no counting line, no
## "... van 5" on the tubs.  Then ✓ on a wrong filling, three times: nothing
## says what is still on the rack, that the tubs must be even or where the rest
## goes, and buurvrouw Els never comes with her ghost numbers.  A miss costs
## nothing, and a right filling still works.
func test_geen_hulp_na_een_fout() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel._s
	if str(s["soort"]) != "eerlijk":
		_af()
		return
	var sterren := int(State.s["sterren"])
	var toeschouwer := str(State.s["gasten"][0]["id"])
	World.zet(toeschouwer, "tuin", 40.0, 100.0)
	# the sum
	var voor := beeld(ID)
	waar(voor.has("tb_vraag") and voor.has("tb_vraag_keuzes"), "het beeld kent de somkaart")
	for keer in 3:
		var wat := "som, misser %d" % (keer + 1)
		waar(_tik_keuze(_fout_getal(int(s["per"]))), "%s: een fout getal" % wat)
		gelijk(int(spel._s["missers"]), keer + 1, "%s: geteld" % wat)
		gelijk(str(spel._s["stap"]), "vraag", "%s: dezelfde vraag" % wat)
		waar(mis_wolk("tb_vraag"), "%s: 🔄 Nog een keer bij de kaart" % wat)
		waar(is_sip(toeschouwer), "%s: wie in de tuin staat is teleurgesteld" % wat)
		var strook := Hits.spot("tb_vraag_keuzes")
		waar(strook != null and (strook.knoop as UiKeuzes).op_slot, "%s: de strook even op slot" % wat)
		var kaart := Hits.spot("tb_vraag").knoop as UiSomkaart
		waar(not kaart.hulp_label.visible, "%s: geen telregel" % wat)
		for i in int(s["M"]):
			var kuip := Hits.spot("tb_kuip%d" % i)
			waar(kuip == null or not (kuip.knoop as Control).tooltip_text.contains(" van "),
				"%s: tobbe %d verklapt niet hoeveel erin moet" % [wat, i + 1])
		await _wacht_mispauze()
		niets_erbij(voor, beeld(ID), wat)
	waar(_tik_keuze(int(s["per"])), "het goede getal")
	gelijk(str(spel._s["stap"]), "vullen", "daarna mag er geschept worden")
	# ✓ with everything still on the rack, three times
	for keer in 3:
		var wat := "klaar, misser %d" % (keer + 1)
		spel._check()
		gelijk(int(spel._s["missers"]), 4 + keer, "%s: geteld" % wat)
		gelijk(str(spel._s["stap"]), "vullen", "%s: de beurt loopt door" % wat)
		waar((spel._s["zeg"] as Dictionary).is_empty(), "%s: het spel zegt niet wat er mis is" % wat)
		waar(Hits.spot("tb_zeg") == null, "%s: geen wolkje met een tip" % wat)
		waar(mis_wolk("tb_som"), "%s: 🔄 Nog een keer" % wat)
		waar(Hits.spot("tb_els") == null, "%s: geen buurvrouw Els" % wat)
		waar(Hits.spot("tb_s0") == null and Hits.spot("tb_sk") == null, "%s: geen spookcijfers" % wat)
		await _wacht_mispauze()
	gelijk(int(State.s["sterren"]), sterren, "geen ster erbij of eraf")
	# the right filling still works
	for i in int(s["M"]):
		spel._s["tob"][i] = int(s["per"])
	spel._s["rek"] = 0
	spel._s["kan"] = int(s["rest"])
	spel._check()
	gelijk(str(spel._s["stap"]), "baden", "een goede verdeling: iedereen mag in bad")
	_af()

## Too full: the share is checked, it is wrong, and the guests in the garden
## look disappointed (`sip`) — no bubble says "te vol".  Since wave 2 the soap
## then goes back where the turn began (the rack): the same share is asked again.
func test_te_vol_is_een_teleurstelling() -> void:
	_op()
	var gasten := _gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel._s
	if str(s["soort"]) != "eerlijk":
		_af()
		return
	waar(_tik_keuze(int(s["per"])), "eerst de som")
	var id := str(gasten[0]["id"])
	World.zet(id, "tuin", 40.0, 100.0)
	# everything scooped, one tub one too full: the check finds it wrong
	spel._s["rek"] = 0
	spel._s["tob"][0] = int(s["per"]) + 1
	spel._check()
	gelijk(int(spel._s["tob"][0]), 0, "de volle tobbe is leeg")
	gelijk(int(spel._s["rek"]), int(s["T"]), "al het sop is terug op het rek")
	gelijk(int(spel._s["missers"]), 1, "een misser")
	waar(is_sip(id), "de gast in de tuin kijkt teleurgesteld")
	waar(mis_wolk("tb_som"), "🔄 Nog een keer")
	waar(Hits.spot("tb_zeg") == null, "geen wolkje met te vol")
	_af()

# --------------------------------------------------------- 4. herlaad, stop

func test_beurt_overleeft_een_herlaad() -> void:
	_op()
	_gasten(3, 4, 3)
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		_af()
		return
	var voor: Dictionary = spel.stand()
	if str(voor["soort"]) == "eerlijk":
		waar(_tik_keuze(int(voor["per"])), "de openingssom beantwoorden")
		spel._s["tob"][0] = 1
		spel._s["rek"] = int(spel._s["rek"]) - 1
		spel._bewaar()
	Games.stop()
	waar(Games.start(ID), "opnieuw starten")
	var na: Dictionary = _spel().stand()
	gelijk(int(na["T"]), int(voor["T"]), "dezelfde T")
	gelijk(int(na["M"]), int(voor["M"]), "dezelfde M")
	if str(voor["soort"]) == "eerlijk":
		gelijk(int(na["tob"][0]), 1, "het schepje in tobbe 1 is er nog")
		gelijk(str(na["stap"]), "vullen", "en de beantwoorde som komt niet terug")
	_af()

func test_stop_laat_de_wereld_schoon_achter() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	Games.stop()
	gelijk(Games.actief(), "", "geen spel actief")
	var los := 0
	for d in World.decor_lijst("tuin"):
		if str((d as Dictionary).get("eigenaar", "")) == ID:
			los += 1
	gelijk(los, 0, "geen los decor van tobbe meer in de tuin")
	for id in Hits.debug().keys():
		waar(not str(id).begins_with("tb_"), "geen knop van tobbe meer: %s" % str(id))
	_af()

# ------------------------------------------ 4b. de som staat voorop (N4)

## R1/R3: elke soort — ook `eerlijk`, de enige die band 3 ooit ziet — opent met
## een somkaart en een strook van vier, en er is geen ✓ om eromheen te lopen.
func test_elke_soort_begint_met_een_vraag() -> void:
	for opzet in OPZET:
		for soort in Sommen.Tobbe.soorten(int(opzet["band"])):
			var spel = _begin(opzet, str(soort))
			if spel == null:
				_af()
				continue
			var wat := "band %d, %s" % [int(opzet["band"]), str(soort)]
			gelijk(str(spel._s["stap"]), "vraag", "%s: de som staat er het eerst" % wat)
			waar(Hits.spot("tb_vraag") != null, "%s: er hangt een somkaart" % wat)
			gelijk(_keuzes().size(), 4, "%s: vier knoppen op de strook" % wat)
			var goed := _juist(spel._s)
			var staat_er := false
			for woord in _keuzes():
				if str(woord).ends_with(" %d" % goed):
					staat_er = true
			waar(staat_er, "%s: het goede getal %d staat op de strook" % [wat, goed])
			waar(Hits.spot("tb_klaar") == null, "%s: nog geen ✓ om de som over te slaan" % wat)
			waar(Hits.spot("tb_kraan") == null, "%s: nog geen kraantje" % wat)
			_af()

## Het goede antwoord OPENT het verdelen, het doet het niet voor: bij `half`
## staat al het sop nog in tobbe 1, bij `eerlijk` en `dubbel` nog op het rek.
func test_een_goed_antwoord_verdeelt_niet_zelf() -> void:
	for opzet in OPZET:
		for soort in Sommen.Tobbe.soorten(int(opzet["band"])):
			var spel = _begin(opzet, str(soort))
			if spel == null:
				_af()
				continue
			var s: Dictionary = spel._s
			var wat := "band %d, %s" % [int(opzet["band"]), str(soort)]
			var t := int(s["T"])
			var sterren := int(State.s["sterren"])
			var leeg: Array = []
			for i in int(s["M"]):
				leeg.append(0)
			waar(_tik_keuze(_juist(s)), "%s: het goede getal is aan te tikken" % wat)
			gelijk(str(spel._s["stap"]), "vullen", "%s: daarna mag er geschept worden" % wat)
			if str(soort) == "half":
				var vol: Array = leeg.duplicate()
				vol[0] = t
				gelijk(str(spel._s["tob"]), str(vol), "%s: al het sop staat nog in tobbe 1" % wat)
				gelijk(int(spel._s["rek"]), 0, "%s: het rek blijft leeg" % wat)
			else:
				gelijk(str(spel._s["tob"]), str(leeg), "%s: de tobbes staan nog leeg" % wat)
				gelijk(int(spel._s["rek"]), t, "%s: al het sop ligt op het rek" % wat)
			gelijk(int(spel._s["kan"]), 0, "%s: het kannetje is nog leeg" % wat)
			gelijk(int(State.s["sterren"]), sterren, "%s: een antwoord alleen geeft geen ster" % wat)
			_af()

# --------------------------------------------------------------- 5. teksten

## Every §6.6 literal is in the source, verbatim — except the four that hung on
## the ✓ "zo is het goed" / "klaar met badderen" and on the splitskraantje
## ("eerst sop erin", "blijft over"): those three tools are gone since wave 2
## (owner, 2026-10-08: "het moet niet mogelijk zijn om rekenen over te slaan").
func test_alle_teksten_staan_er_woordelijk() -> void:
	var f := FileAccess.open("res://games/tobbe/spel.gd", FileAccess.READ)
	waar(f != null, "de bron is leesbaar")
	if f == null:
		return
	var bron := f.get_as_text()
	for zin in ["nog geen gasten", "geen plek", "Verdeel het eerlijk", "Zo is het goed!",
			"opnieuw beginnen", "morgen dubbel", "Hoeveel samen?", "in twee helften",
			"Hoeveel in elke helft?", "rek is leeg", "even hoog",
			"%d schepjes, %d tobbes", "Hoeveel in elke tobbe?", "de som van het sop",
			"wil in bad", "zit vol", "lekker warm", "mag in de tobbe",
			"mogen in de tobbe", "blinkend schoon"]:
		waar(bron.contains(zin), "letterlijk in de bron: %s" % zin)
	# what came after a miss is gone (owner, 2026-09-24)
	for weg in ["buurvrouw Els doet het voor", "is oneven", "te vol", "nog op het rek",
			"hoort hierin", "erbij", "ieder evenveel", "zoveel hoort erin",
			"zoveel blijft over", "hotspook"]:
		waar(not bron.contains('"%s"' % weg), "geen hulp na een misser meer: %s" % weg)
	# and the tools that did the work or skipped it (wave 2)
	for weg in ["splitskraantje: halveren", "klaar met badderen", "zo is het goed"]:
		waar(not bron.contains('"%s"' % weg), "weg sinds wave 2: %s" % weg)

## De openingszin van `eerlijk` past bij ELK recept dat de bevroren kern kan
## maken (HOTEL.md §9: <= 8 woorden en <= 40 tekens), en elk teken zit in het
## lettertype (PLAN.md R10).
func test_de_sopvraag_past_in_de_regels() -> void:
	var gezien := 0
	for band in [3, 4, 5]:
		for n in range(1, 11):
			for dag in range(1, 8):
				var r := Sommen.Tobbe.recept(n, band, dag)
				if str(r["soort"]) != "eerlijk":
					continue
				gezien += 1
				var zin := "%d schepjes, %d tobbes" % [int(r["T"]), int(r["M"])]
				waar(Ui.keur_regel("tb_vraag", zin), "de regel past: %s" % zin)
				waar(Ui.mist_tekens(zin).is_empty(), "alle tekens bestaan: %s" % zin)
				var som := ("helft van %d =" % int(r["T"])) if int(r["M"]) == 2 \
					else ("%d : %d =" % [int(r["T"]), int(r["M"])])
				waar(Ui.mist_tekens(som).is_empty(), "alle tekens bestaan: %s" % som)
	waar(gezien > 20, "er zijn genoeg eerlijke recepten nagekeken (%d)" % gezien)
	waar(Ui.keur_regel("tb_vraag2", "Hoeveel in elke tobbe?"), "de tweede regel past")
	waar(Ui.mist_tekens("🧴 Hoeveel in elke tobbe?").is_empty(), "pictogram en zin bestaan")

# --------------------------------------------------------------- 6. dekking

func _schil_op(maat: Vector2i) -> Dictionary:
	var boom := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var shell = load("res://scenes/main.tscn").instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	State.nieuw_spel()
	State.start_gekozen()
	Hotel.start()
	for _f in 4:
		await boom.process_frame
	_gasten(3, 1, 3)
	Hotel.naar_kamer("tuin")
	for _f in 3:
		await boom.process_frame
	Games.start(ID)
	for _f in 6:
		await boom.process_frame
	var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
	return {"vp": vp, "kader": kader.size}

func _schil_af(h: Dictionary) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	if Games.actief() != "":
		Games.stop()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	Ui.vergeet_scherm()
	(h["vp"] as SubViewport).queue_free()
	for _f in 2:
		await boom.process_frame

## No button of the game covers an object, and no two elements overlap, on
## four frames — the §12.2 definition of done.
func test_dekking_in_vier_kaders() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _schil_op(maat)
		var kader: Vector2 = h["kader"]
		gelijk(Games.actief(), ID, "het spel draait bij %s" % str(maat))
		var dbg := Hits.debug()
		# N4: de beurt opent met de som, dus kaart EN strook horen op elk kader
		# echt geplaatst te zijn — niet weggevallen omdat er geen ruimte was
		waar(dbg.has("tb_vraag") and dbg.has("tb_vraag_keuzes"),
			"%s: de somkaart en de antwoordstrook staan op het scherm" % str(maat))
		var eigen := 0
		var ids: Array = dbg.keys()
		for id in ids:
			if str(id).begins_with("tb_"):
				eigen += 1
			var a: Dictionary = dbg[id]
			var r: Rect2 = a["rect"]
			waar(r.position.x >= -0.01 and r.position.y >= -0.01
				and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
				"%s: %s binnen het kader (%s)" % [str(maat), id, str(r)])
			if int(a["laag"]) != Hits.Laag.VAST:
				var spot := Hits.spot(str(id))
				var wolk := spot != null and (spot.kind == "wolk" or spot.kind == "tag")
				# a speech cloud or number tag may sit on a tenth of its own thing
				# (Hits.TAG_IN); a button never
				waar(str(a.get("op", "")) == "aan"
					or Hits.dekking(str(id)) <= (Hits.TAG_IN * 100.0 + 0.01 if wolk else 0.0),   # dekking is a percentage
					"%s: %s dekt zijn voorwerp niet (%.2f)" % [str(maat), id, Hits.dekking(str(id))])
		waar(eigen >= 3, "%s: het spel staat op het scherm (%d knoppen)" % [str(maat), eigen])
		await _schil_af(h)
	State.s = bewaard

# ------------------------------------------- 7. rekenen eerst (wave 2, 2026-10-08)

## Wave-2 rule R1 (owner, 2026-10-08: "rekenen moet minstens 50% van de
## interactie zijn"): a whole turn tap by tap, the tap that opened the game not
## counted.  The opening sum is maths (one wrong and one right tap); every
## scoop into a tub or the jug builds the share that is checked by itself, so
## it is maths too (a graded manipulative); there is no ✓, no kraantje and no
## tap per animal any more — so there is no play tap at all on this path.
var _teller := {"reken": 0, "spel": 0}

func _tel(soort: String) -> void:
	_teller[soort] = int(_teller.get(soort, 0)) + 1

## Build the right share the way a child does it with the default handful of
## one: from the rack scoop by scoop into every tub and the rest into the jug,
## or for `half` pour from the first tub into the second and the rest into the
## jug.  Every tap is counted as maths.
func _bouw_goed(spel) -> void:
	var s: Dictionary = spel._s
	var per := int(s["per"])
	var rest := int(s["rest"])
	if str(s["soort"]) == "half":
		for _k in per:
			_tel("reken")
			spel._tik_tobbe(0)
		for _k in rest:
			_tel("reken")
			spel._tik_kan()
		return
	for i in int(s["M"]):
		for _k in per:
			_tel("reken")
			spel._tik_tobbe(i)
	for _k in rest:
		_tel("reken")
		spel._tik_kan()

func _rekenaandeel(opzet: Dictionary, soort: String, n_gasten := -1) -> void:
	_teller = {"reken": 0, "spel": 0}
	var o := opzet.duplicate()
	if n_gasten > 0:
		o["gasten"] = n_gasten
	var spel = _begin(o, soort)
	if spel == null:
		_af()
		return
	var wat := "band %d, %s, %d gasten" % [int(o["band"]), soort, int(o["gasten"])]
	var s: Dictionary = spel._s
	var fout := _fout_getal(_juist(s))
	_tel("reken")
	waar(_tik_keuze(fout), "%s: een fout getal" % wat)
	await _wacht_mispauze()
	_tel("reken")
	waar(_tik_keuze(_juist(s)), "%s: het goede getal" % wat)
	gelijk(str(spel._s["stap"]), "vullen", "%s: nu verdelen" % wat)
	waar(Hits.spot("tb_klaar") == null and Hits.spot("tb_kraan") == null,
		"%s: geen ✓ en geen kraantje" % wat)
	_bouw_goed(spel)
	gelijk(str(spel._s["stap"]), "baden", "%s: de verdeling is vanzelf nagekeken" % wat)
	var r := int(_teller["reken"])
	var sp := int(_teller["spel"])
	waar(r >= sp + 1, "%s: rekenen %d >= spel %d + 1" % [wat, r, sp])
	_af()

func test_rekenaandeel_band_3() -> void:
	for soort in Sommen.Tobbe.soorten(3):
		await _rekenaandeel(OPZET[0], str(soort))
	await _rekenaandeel(OPZET[0], str(Sommen.Tobbe.soorten(3)[0]), 1)

func test_rekenaandeel_band_4() -> void:
	for soort in Sommen.Tobbe.soorten(4):
		await _rekenaandeel(OPZET[1], str(soort))
	await _rekenaandeel(OPZET[1], str(Sommen.Tobbe.soorten(4)[0]), 8)

func test_rekenaandeel_band_5() -> void:
	for soort in Sommen.Tobbe.soorten(5):
		await _rekenaandeel(OPZET[2], str(soort))
	await _rekenaandeel(OPZET[2], str(Sommen.Tobbe.soorten(5)[0]), 8)

## R2 (the splitskraantje): `half` has no tap that halves for the child any
## more — the child pours the halves itself, and the rest into the jug.  More
## in the jug than the rest is a miss without help, and the soap goes back into
## the first tub: the same question.  (Until wave 2 one tap on 🚰 did it.)
func test_halveren_doet_het_kind_zelf() -> void:
	var spel = _begin(OPZET[2], "half")
	if spel == null:
		_af()
		return
	var s: Dictionary = spel._s
	waar(_tik_keuze(_juist(s)), "het goede getal")
	gelijk(str(spel._s["stap"]), "vullen", "nu verdelen")
	await _wacht_mispauze()          # the tools are drawn a moment after the answer
	waar(Hits.spot("tb_kraan") == null, "er is geen kraantje dat het voordoet")
	waar(Hits.spot("tb_kan") != null, "wel het kannetje (groep 5)")
	var t := int(s["T"])
	var per := int(s["per"])
	var rest := int(s["rest"])
	for _k in rest + 1:
		spel._tik_kan()
	gelijk(int(spel._s["missers"]), 1, "te veel in het kannetje: een misser")
	gelijk(int(spel._s["mis"]), 1, "op de open vraag")
	gelijk(int(spel._s["tob"][0]), t, "al het sop staat weer in de eerste tobbe")
	gelijk(int(spel._s["kan"]), 0, "en het kannetje is leeg")
	gelijk(str(spel._s["stap"]), "vullen", "dezelfde opdracht")
	await _wacht_mispauze()
	for _k in per:
		spel._tik_tobbe(0)
	for _k in rest:
		spel._tik_kan()
	gelijk(str(spel._s["stap"]), "baden", "precies de helft overgegoten: goed")
	_af()

## R2 (the ✓): the share is checked by itself the moment it is complete — there
## is no ✓ to press — and a wrong share sends the soap back to the rack.
func test_de_verdeling_wordt_vanzelf_nagekeken() -> void:
	var spel = _begin(OPZET[0], "eerlijk")
	if spel == null:
		_af()
		return
	var s: Dictionary = spel._s
	waar(_tik_keuze(_juist(s)), "het goede getal")
	waar(Hits.spot("tb_klaar") == null, "er is geen ✓ om te bevestigen")
	var t := int(s["T"])
	# everything into the first tub that fits under its rim, the rest into the second
	var rand: int = int(s["per"]) + 2
	var in_een: int = mini(t, rand)
	for _k in in_een:
		spel._tik_tobbe(0)
	for _k in t - in_een:
		spel._tik_tobbe(1)
	gelijk(int(spel._s["missers"]), 1, "een scheve verdeling is een misser")
	gelijk(int(spel._s["rek"]), t, "en al het sop is terug op het rek")
	gelijk(str(spel._s["stap"]), "vullen", "dezelfde opdracht")
	await _wacht_mispauze()
	_bouw_goed(spel)
	gelijk(str(spel._s["stap"]), "baden", "de goede verdeling slaagt vanzelf")
	_af()

## R2: a missed question survives a new day with more guests (until wave 2 a
## stand of another day, N or band became a fresh — maybe easier — recipe).
func test_een_gemiste_vraag_blijft_na_een_nieuwe_dag() -> void:
	_op()
	_gasten(3, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		_af()
		return
	var voor: Dictionary = spel.stand()
	waar(_tik_keuze(_fout_getal(_juist(voor))), "een fout getal")
	Games.stop()
	_gasten(5, 2, 3)
	waar(Games.start(ID), "de volgende dag, met meer gasten")
	var na: Dictionary = _spel().stand()
	gelijk(str(na["soort"]), str(voor["soort"]), "dezelfde soort")
	gelijk(int(na["T"]), int(voor["T"]), "dezelfde T")
	gelijk(int(na["M"]), int(voor["M"]), "dezelfde M")
	gelijk(str(na["stap"]), "vraag", "en dezelfde vraag")
	_af()
