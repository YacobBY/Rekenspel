class_name UiTekst
extends RefCounted
## Every child-facing string the SHELL owns, verbatim from world.md §7.
##
## They live in one file on purpose (architecture.md §1.1 F3): a reviewer greps
## one place, `tests/test_ui.gd` walks this file's constants for the F4 budget
## and for a glyph the bundled font subset does not carry, and a game never
## copies a shell string into its own directory.
##
## Strings the GAMES own stay in `res://games/<id>/`; strings the day cycle owns
## (prikbord cards, check-in, the bill, the letters) belong to W2 and are not
## repeated here.

# ---------------------------------------------------------- §7.1 shell / HUD
const LOGO := "🛎️ Dierenhotel"
const DAG := "📅 Dag"
const DAG_TITEL := "Dag"
const MUNT_TITEL := "De kassa"
const STER_TITEL := "Sterren"
const GELUID_AAN := "🔊"
const GELUID_UIT := "🔇"
const GELUID_TITEL := "Geluid"
const GELUID_UITLEG := "Geluid aan of uit"
const RONDE_OCHTEND := "☀️ Ochtendronde"
const RONDE_AVOND := "🌙 Avondronde"
const RONDE_VRIJ := "🐾 Vrij spelen"
const PRIKBORD := "📋 Prikbord"
const AVOND := "🌙 Avond"
const VOET := "Dierenhotel Kwispelsteeg · demo · rustig aan, je mag alles zo vaak proberen als je wil"

# ------------------------------------------------------------ §7.2 startscherm
const START_TERUG := "Welkom terug in het Dierenhotel! 👋"
const START_VERDER := "Verder spelen ▸"
const START_NIEUW := "Nieuw spel"
## `Je was bij <n dag|dagen> — met <n gast|gasten>, <munten> munten en <sterren> sterren.`
static func start_stand(dagen: int, gasten: int, munten: int, sterren: int) -> String:
	return "Je was bij %s — met %s, %d munten en %d sterren." % [
		Ui.meervoud(dagen, "dag", "dagen"), Ui.meervoud(gasten, "gast", "gasten"),
		munten, sterren]

## The v5 shelter branch of world.md §6.2 cannot happen in this build: the Godot
## export lives on another origin and cannot read the HTML game's localStorage,
## so architecture.md §9 drops every migration.  The three strings are kept here
## so the inventory of world.md §7.2 is complete and correctly worded the day a
## save-import path is added; nothing shows them today.
const START_V5_TITEL := "Er staan nog dieren in de Kwispelsteeg! 🐾"
const START_V5_VERHUIS := "Ja, verhuizen naar het hotel ▸"
const START_V5_BED := "🛏 Geef iedereen een bed"
static func start_v5_regel(gasten: int) -> String:
	return "Je oude opvang staat nog op deze tablet: %s. Neem je ze mee naar het hotel? Ze krijgen dan een echt bed." \
		% Ui.meervoud(gasten, "gast", "gasten")

# ---------------------------------------------------------- §7.3 plattegrond
const KAART_TITEL := "🗺️ De plattegrond"
const KAART_HINT := "Tik op een ruimte om er naartoe te gaan."
const SLUITEN := "Sluiten"

# ------------------------------------------------------------- §7.4 deuren
## `Ga naar <kamernaam>` — the title of a door hotspot.
static func ga_naar(kamer_naam: String) -> String:
	return "Ga naar %s" % kamer_naam

# --------------------------------------------------------------- §7.9 kassa
const KASSA_TITEL := "💰 De kassa"
const KASSA_UITLEG_1 := "Munten komen uit het uitchecken: elke gast betaalt zijn nachten. Sterren krijg je voor meedoen — of je som klopt of niet."
const KASSA_UITLEG_2 := "In het meubelboek koop je straks nieuwe bedden, mandjes en badkuipen. Meer bedden = meer gasten = grotere sommen."
static func kassa_munten(n: int) -> String:
	return "💰 %d munten" % n
static func kassa_sterren(n: int) -> String:
	return "⭐ %d sterren" % n
static func kassa_snoep(n: int) -> String:
	return "🍬 %d in de snoeppot" % n

# ------------------------------------------------------- §7.8 brievenmuur
const BRIEVEN_TITEL := "💌 De brievenmuur"
const BRIEVEN_UITLEG_1 := "Hier komen de bedankjes van de families die hun dier bij jou lieten slapen."
const BRIEVEN_UITLEG_2 := "Laat een gast zijn nachten uitslapen en reken netjes af — dan komt er post."

# ------------------------------------------------------------------ §7.10
const SPEL_MIS := "💛 Probeer iets anders"
