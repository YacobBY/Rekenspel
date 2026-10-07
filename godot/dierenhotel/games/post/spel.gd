extends MiniGame
## post — De post sorteren, in de postkamer (U4, 2026-10-07; owner: "Verzin
## nog vier kamers met activiteiten").  Op de postkar ligt de post van de dag:
## één brief per gast.  Elke brief draagt een KAMERNUMMER; de vakkenkast langs
## de achterwand is een getallenlijn in vier vakjes met hun getallen op een
## plaatje.  Het kind tikt het vakje waar de brief in hoort (een strook van
## precies vier keuzes = de vier vakjes).  De getallen: `beurt.gd` (groep 3 tot
## 20 in vijven, groep 4 tientallen tot 100, groep 5 een keersom op de brief).
##
## Nog `stub: true`: de beurt loopt headless in de tests, maar de kar als
## rustend voorwerp van de hotspot, de dieren van de beurt en het beeld in de
## echte export zijn nog niet nagekeken — zie
## .fanout/scratch/uitbreiding/U4-postkamer.md (STATE / NEXT STEPS).

const Beurt := preload("res://games/post/beurt.gd")
const Modellen := preload("res://art/decor_post.gd")

const KAMER := "postkamer"
const KAART := "po_som"
const STROOK := "po_som_keuzes"
const KAST := "post_kast"
const KAR := "post_kar"
const TAAK := "post"

## Child-facing strings (HOTEL.md §9: ≤ 8 words, ≤ 40 characters, pictogram first).
const REGEL := "💌 In welk vakje hoort deze brief?"      # 7 woorden, 33 tekens
const KEUZE_TITEL := "kies een vakje"
const TOAST_GOED := "💌 Goed zo, in het vakje!"           # 5 woorden, 24 tekens
const TOAST_KLAAR := "💌 Alle post is gesorteerd!"        # 4 woorden, 27 tekens

var _kaart = null
var _t0 := 0
var _vast := false

func definitie() -> Dictionary:
	return {
		"naam": "De post sorteren",
		"kamer": KAMER,
		"stub": true,
		"hotspot": {"obj": KAR, "icoon": "💌", "label": "Post", "hoog": 16},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"wens": "",
		"taak": {"id": TAAK, "icoon": "💌", "tekst": "Sorteer de post", "prio": 6},
	}

func start(_c: SpelCtx) -> void:
	_t0 = Time.get_ticks_msec()
	Art.registreer_model("post_vakkenkast", Modellen.vakkenkast)
	Art.registreer_model("post_postkar", Modellen.postkar)
	var d := ctx.data()
	var dag := int(State.s.get("dag", 1))
	if int(d.get("dag", -1)) != dag or not d.has("brieven") or not d.has("vakjes"):
		var b := Beurt.maak(ctx.state.band(), ctx.state.n_gasten(), dag)
		d["dag"] = dag
		d["vakjes"] = b["vakjes"]
		d["brieven"] = b["brieven"]
		d["i"] = 0
		d["mis"] = 0
	var platen: Array = []
	for vk in d["vakjes"]:
		platen.append(Beurt.plaat(vk))
	ctx.wereld.decor(KAMER, {"id": KAST, "model": "post_vakkenkast", "x": 40.0, "z": 8.0,
		"params": {"platen": platen}})
	ctx.wereld.decor(KAMER, {"id": KAR, "model": "post_postkar", "x": 48.0, "z": 52.0,
		"params": {"brieven": _over()}})
	print("[probe] spel=start id=", ctx.id, " kamer=", ctx.kamer, " brieven=", _over())
	_vraag()

func stop() -> void:
	State.bewaar()
	print("[probe] spel=stop post i=", int(ctx.data().get("i", 0)))

## How many letters are still on the cart.
func _over() -> int:
	var d := ctx.data()
	return maxi(0, (d.get("brieven", []) as Array).size() - int(d.get("i", 0)))

## The card for the letter of the turn: its number on the sum line, the four
## holes as the strip.  Every number stands in the world (the plate on the
## hole, the number on the letter), the sentence only asks.
func _vraag() -> void:
	var d := ctx.data()
	var i := int(d.get("i", 0))
	var brieven: Array = d.get("brieven", [])
	if i >= brieven.size():
		_klaar()
		return
	var br: Dictionary = brieven[i]
	var vakken: Array = d["vakjes"]
	var keuzes: Array = []
	for j in vakken.size():
		var vk: Dictionary = vakken[j]
		var kies := func(_id) -> void:
			_kies(j)
		keuzes.append({"id": "vak%d" % j, "icoon": "💌", "tekst": Beurt.plaat(vk),
			"kort": str(vk["van"]), "kies": kies})
	_kaart = ctx.ui.somkaart(KAST, str(br["tekst"]), {
		"id": KAART, "kamer": KAMER, "hoog": 26.0, "icoon": "💌",
		"regel": REGEL, "keuze_titel": KEUZE_TITEL, "keuzes": keuzes,
	})
	ctx.ui.getal_tag(KAR, _over())

func _kies(j: int) -> void:
	if _vast or not actief:
		return
	var d := ctx.data()
	var i := int(d.get("i", 0))
	var brieven: Array = d.get("brieven", [])
	if i >= brieven.size():
		return
	var br: Dictionary = brieven[i]
	if j != int(br["vak"]):
		# wrong: no help, the same question stays (AGENTS.md §1.3)
		d["mis"] = int(d.get("mis", 0)) + 1
		Ui.misser(_kaart, "", ctx.id)
		print("[probe] post mis brief=", br["getal"], " vak=", j)
		return
	_vast = true
	ctx.snd.ja()
	d["i"] = i + 1
	State.bewaar()
	ctx.ui.getal_tag(KAR, _over())
	if _kaart != null:
		_kaart.klaar()
	print("[probe] post goed brief=", br["getal"], " vak=", j, " over=", _over())
	if not await na(0.6):
		return
	_vast = false
	_vraag()

func _klaar() -> void:
	var d := ctx.data()
	var ms := Time.get_ticks_msec() - _t0
	ctx.state.tel(int(d.get("mis", 0)) == 0, ms)
	ctx.ui.toast(TOAST_KLAAR, "happy")
	ctx.taak_klaar(TAAK)
	print("[probe] spel=klaar post mis=", int(d.get("mis", 0)), " sterren=", State.s["sterren"])
	# the next day gets a fresh pile
	d["i"] = 0
	d.erase("brieven")
	ctx.sluit()
