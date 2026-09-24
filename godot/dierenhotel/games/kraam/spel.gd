extends WinkelSpel
## kraam — de souvenirkraam, het vierde kraampje van de Winkelstraat: een
## sjaaltje, een hoedje en een bal (gele luifel, een cadeautje op het bord).
##
## THE STALL MOVED IN FROM THE GARDEN (owner, 2026-09-24: "De kraam in de tuin
## voelt nu dubbelop die kan verwerkt worden in de winkels").  It used to be a
## game of its own on the lawn (games-b.md §5: coins dragged onto a counter,
## its own stall models); now it is one of the shops, so the street has one way
## of paying and one rule for a wrong amount: the animal is sent out of the
## shop (`WinkelSpel._weggestuurd`).  What stayed:
##   * the game id `kraam`, so a save's drawer, unlock and star keep working
##     (an unfinished coin turn in that drawer becomes a fresh choice for the
##     same animal, `WinkelSpel._normaliseer`);
##   * the souvenirs themselves — sjaaltje, hoedje, bal — the wardrobe pieces
##     an animal may already own from the garden;
##   * the 🎁 wish and its board card "<naam> wil een souvenir": a guest with
##     that wish shops first, and buying fulfils it (`winkel().wens`).
## The whole turn lives in `games/_winkel/winkel.gd` (games-d.md §4); here
## stands only which shop this is and where everything is.

const WENS := "souvenir"
## Child text, verbatim (games-d.md §4.5).
const T_TAAK := "Souvenir"
const T_WIL := "%s wil een souvenir"

func winkel() -> Dictionary:
	return {"id": "kraam", "naam": "Souvenirkraam", "icoon": "🎁", "label": "Souvenirs",
		"decor": "souvenirkraam", "x": 118.0, "z": 12.0, "top": 10.0, "knop_hoog": 30.0,
		"plekken": [Vector2(-8, 4), Vector2(0, 4), Vector2(8, 4)],
		"klant": Vector2(118, 34), "buiten": Vector2(108, 86), "wens": WENS}

## The shop's registration plus the 🎁 wish and its board card (the garden
## stall had them, games-b.md §5.2; the other shops have no card, games-d.md
## §4.1).  None of these may touch `self` (architecture.md §6.1).
func definitie() -> Dictionary:
	var def := super()
	# who wants a souvenir and can shop (the shop sells to guests with a bed)
	var wil := func(s: Dictionary) -> Dictionary:
		for g in s.get("gasten", []):
			if str(g.get("behoefte", "")) == "souvenir" and not bool(g.get("blij", false)) \
					and not str(g.get("bed", "")).is_empty():
				return g
		return {}
	var wanneer := func(s: Dictionary) -> bool:
		return not wil.call(s).is_empty()
	var tekst := func(s: Dictionary) -> String:
		var g: Dictionary = wil.call(s)
		return T_TAAK if g.is_empty() else T_WIL % str(g.get("naam", ""))
	def["wens"] = WENS
	def["taak"] = {"id": "souvenir", "prio": 1, "icoon": "🎁", "wanneer": wanneer,
		"tekst": tekst}
	return def
