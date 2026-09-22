extends Proef
## De lege kamer bij de vraag — de eigenaarswens van 2026-09-21, gebouwd in
## `scenes/kamer.gd::verberg_bedden` en opgehangen aan `World.bedden_verberg`.
##
## De wens: op het moment dat de gast aankomt en de kaart vraagt "Hoeveel
## bedden heb je nodig?", moet de kamer LEEG zijn.  Daarvoor bleven de bedden
## van eerdere beurten met hun slapers gewoon staan, en kon het kind ze
## aflezen in plaats van te rekenen.
##
## WAT HIER BEWEZEN WORDT is de kamerkant: zolang `bedden_verberg(true)`
## staat zijn de bedden van de kamer weg, én de gast die in een van die bedden
## slaapt; een gast zonder bed blijft gewoon in beeld; `bedden_verberg(false)`
## zet alles terug.  Dat het spel `bedden` zelf op het juiste moment vraagt
## (weg bij de vraag, terug na het goede antwoord, terug bij `stop()`) staat
## in `games/bedden/test_bedden.gd::test_bedden_maken_de_kamer_leeg_rond_de_vraag`.
##
## WAAROM DIT BESTAND HIER STAAT en niet bij de bedden-tests.  Die zijn het
## EERST geladen testbestand van de suite (`res://games/...` sorteert vóór
## `res://tests/...`), en wie vandaaruit `res://scenes/kamer.gd` laadt, zet
## de hele preloadketen van die scene vast.  Gemeten op de volle suite met
## deze test in `games/bedden/test_bedden.gd`: 29 ObjectDB-instanties en
## 7 hulpbronnen "still in use at exit" — `core/sommen.gd`, `core/jsgetal.gd`,
## `art/vorm.gd`, `art/effect.gd`, `scenes/wereldobject.gd`, `scenes/dier.gd`
## en `games/was/soorten.gd` — waar `tools/test.sh` (terecht) op afgaat.
## Met die test UITgeschakeld was de suite schoon: 499 goed, 0 fout, geen lek.
## Hetzelfde effect staat in de kop van dat bestand beschreven voor
## `extends Proef`: in de eerste positie lekken de kernscripts, in de laatste
## niet.  Daarom heet dit bestand `test_zzz_*`: het sorteert als allerlaats.

const KAMER := "kamer1"
const KADER := Vector2(1000, 648)

var _laag: Control = null
var _vp: SubViewport = null
var _bewaard: Dictionary = {}
var _bewaard_nr := 0

func _boom() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## Een kamertje met het echte script van `scenes/kamer.gd` en de vier lagen
## die het verwacht.  Niet `scenes/kamer.tscn` zelf: dat vloermodel bouwt
## extra hulpbronnen die hier niets aan toevoegen en het lek alleen groter
## maken.  Elke aanroep op `vloer` in het script is beschermd met
## `has_method("herbouw")`, dus een kale Node2D doet daar geen pijn.
func _kamer_kaal() -> Node2D:
	var k: Node2D = (load("res://scenes/kamer.gd") as GDScript).new()
	for laag in ["Vloer", "Ver", "Objecten", "Voor"]:
		var n := Node2D.new()
		n.name = laag
		k.add_child(n)
	return k

func _op() -> void:
	_bewaard = State.s.duplicate(true)
	_bewaard_nr = Rooms.nr_stand()
	_laag = Control.new()
	_laag.size = KADER
	_boom().root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	_vp = SubViewport.new()
	_vp.size = Vector2i(KADER)
	_boom().root.add_child(_vp)
	var plek := Node2D.new()
	_vp.add_child(plek)
	World.registreer_viewport(_vp, plek)
	World.meet(Rect2(Vector2.ZERO, KADER))
	State.nieuw_spel()
	var pool := State.gasten_pool()
	var gasten: Array = []
	for i in 3:
		var g: Dictionary = (pool[i % pool.size()] as Dictionary).duplicate(true)
		g["id"] = "g%d" % i
		g["waar"] = KAMER
		g["kamer"] = ""
		g["bed"] = ""
		gasten.append(g)
	State.s["gasten"] = gasten
	World.sync(gasten)
	World.naar(KAMER)
	World.meet(Rect2(Vector2.ZERO, KADER))

func _af() -> void:
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	World.sync([])
	Rooms.herstel()
	Rooms.zet_nr(_bewaard_nr)
	Ui.registreer_lagen(null, null, null)
	World.registreer_viewport(null, null)
	if _vp != null:
		_vp.queue_free()
		_vp = null
	if _laag != null:
		_laag.queue_free()
		_laag = null
	State.s = _bewaard
	# één beeld verder, zodat de viewport en zijn textuur echt weg zijn
	await _boom().process_frame

## Staat dit node in het zicht?
func _in_zicht(noden, id: String) -> bool:
	if typeof(noden) != TYPE_DICTIONARY:
		return false
	var nd = noden.get(id)
	return nd != null and is_instance_valid(nd) and (nd as CanvasItem).visible

## Het bed en zijn slaper verdwijnen; de gast zonder bed blijft.
func test_de_kamer_wordt_leeg_gemaakt() -> void:
	_op()
	var zet := Rooms.meubel_zet(KAMER, "bed", 30.0, 40.0, 0)
	var sid := String(zet.get("id", ""))
	waar(sid != "", "er staat een bed in " + KAMER)
	var slaper: Dictionary = State.s["gasten"][0]
	slaper["bed"] = sid
	slaper["kamer"] = KAMER
	World.sync(State.s["gasten"])
	var kamer := _kamer_kaal()
	_vp.add_child(kamer)
	await _boom().process_frame
	gelijk(World.kamer_nu(), KAMER, "kamer 1 is in beeld")
	var bedden = kamer.get("_bed_nodes")
	var dieren = kamer.get("_dieren")
	waar(typeof(bedden) == TYPE_DICTIONARY,
		"de kamer onthoudt welke nodes een bed zijn")
	waar(typeof(dieren) == TYPE_DICTIONARY, "de kamer onthoudt zijn gasten")
	waar(_in_zicht(bedden, sid), "het bed staat in het zicht")
	waar(_in_zicht(dieren, "g0"), "de slaper ligt erin")
	waar(_in_zicht(dieren, "g1"), "gast g1 zonder bed staat los in de kamer")
	World.bedden_verberg(true)
	waar(not _in_zicht(bedden, sid), "bij de vraag is het bed weg")
	waar(not _in_zicht(dieren, "g0"), "de slaper die erin ligt is ook weg")
	waar(_in_zicht(dieren, "g1"), "gast g1 blijft gewoon zichtbaar")
	World.bedden_verberg(false)
	waar(_in_zicht(bedden, sid), "na het antwoord staat het bed er weer")
	waar(_in_zicht(dieren, "g0"), "en de slaper ook")
	kamer.free()
	await _af()

## Zonder de vlag is er niets te verbergen: `_slapende_gasten()` is dan leeg,
## dus geen enkele gast wordt aangeraakt.  Dit is wat elke andere kamer en elk
## ander spel de hele dag door zien.
func test_zonder_de_vraag_blijft_alles_zichtbaar() -> void:
	_op()
	var zet := Rooms.meubel_zet(KAMER, "bed", 30.0, 40.0, 0)
	var sid := String(zet.get("id", ""))
	var slaper: Dictionary = State.s["gasten"][0]
	slaper["bed"] = sid
	slaper["kamer"] = KAMER
	World.sync(State.s["gasten"])
	var kamer := _kamer_kaal()
	_vp.add_child(kamer)
	await _boom().process_frame
	var dieren = kamer.get("_dieren")
	waar(_in_zicht(dieren, "g0"), "de slaper ligt in het zicht")
	waar(_in_zicht(dieren, "g1"), "gast g1 ligt in het zicht")
	waar(_in_zicht(dieren, "g2"), "gast g2 ligt in het zicht")
	kamer.free()
	await _af()
