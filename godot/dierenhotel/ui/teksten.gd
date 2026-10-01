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
## `Je was bij <n dag|dagen> — met <n gast|gasten>, <n munt|munten> en
## <n ster|sterren>.`  world.md §7.10: `meervoud` is ALWAYS used — "1 sterren"
## makes a six-year-old read the sentence twice (V1 finding 3).
## Since the hotels (2026-10-01) the sheet shows numbers with pictograms on a
## tile per hotel instead; this sentence is what a tile says to a screen reader.
static func start_stand(dagen: int, gasten: int, munten: int, sterren: int) -> String:
	return "Je was bij %s — met %s, %s en %s." % [
		Ui.meervoud(dagen, "dag", "dagen"), Ui.meervoud(gasten, "gast", "gasten"),
		Ui.meervoud(munten, "munt", "munten"), Ui.meervoud(sterren, "ster", "sterren")]

# ------------------------------------------------------------- de hotels
## Save slots (owner 2026-10-01: "En ik wil save files maken"): the tablet
## holds three hotels, each a tile on the start sheet that is told apart
## without reading — its own animal and colour, its number, and the day, the
## stars and the guests as numbers with a pictogram.  `Verder spelen ▸` and
## `Nieuw spel` are gone: a tile IS the button that continues that hotel, an
## empty one starts a new hotel there.
##
## The animal is the HOTEL's, one per slot, and not its first guest's: every
## hotel starts with the same guest (Boef 🐶, the pool has a fixed order), so a
## first-guest picture would make all three tiles look alike.
const HOTEL_ICOON := ["🐶", "🐱", "🐰"]
static func hotel_naam(n: int) -> String:
	return "Hotel %d" % n
## `📅 3  ⭐ 5  🐾 2` — day, stars, guests.  Each pictogram is glued to its
## number with a no-break space, so a narrow tile wraps between the pairs and
## never between a pictogram and its number.
static func hotel_cijfers(dag: int, sterren: int, gasten: int) -> String:
	return "📅 %d  ⭐ %d  🐾 %d" % [dag, sterren, gasten]
## An empty tile, and the button that asks for a fourth when all three are taken.
const HOTEL_NIEUW := "➕ Nieuw hotel"
## A new hotel when all three are taken: which one goes?  Then once more, with
## that hotel alone on the sheet, before anything is thrown away.
const HOTEL_WEG := "🗑️ Welk hotel mag weg?"
const HOTEL_ZEKER := "🗑️ Weet je het zeker?"
const HOTEL_JA := "✅ Ja, weg ermee"
const HOTEL_NEE := "⬅ Nee, terug"
## For a parent: the hotel as a file (back-up, another tablet), small, under the
## tiles.  `💾 Bewaar` downloads it, `📂 Open` puts a file into a hotel.
const HOTEL_BEWAAR := "💾 Bewaar"
const HOTEL_OPEN := "📂 Open"
const HOTEL_WELKE := "💾 Welk hotel bewaar je?"
const HOTEL_BEWAARD := "💾 Het hotel is bewaard!"
const HOTEL_GELADEN := "📂 Het hotel is er!"
const HOTEL_KAPOT := "📂 Dit bestand is geen hotel."

# ------------------------------------------------------------ §7.2 de intro
## The welcome of a FRESH game, `ui/intro.gd`: one card that goes by itself
## (owner, 2026-09-24: "geen intro waar je 5x door moet klikken … zonder
## tutorial").  The five tutorial sentences and the `Verder ▸` / `Overslaan ▸▸`
## buttons of the 2026-09-23 story are gone.
const INTRO_WELKOM := "👋 Welkom in het Dierenhotel!"

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

# ------------------------------------------------------------------ de trap
## The stairs between the floors (owner, 2026-09-24: the hotel is a tower; a
## lift until 2026-09-25: "Ik wil graag de lift vervangen voor een trap").  Its
## button on the stairwell, the words a screen reader says, and the panel it
## opens — the same tower as the map (`ui/plattegrond.gd`).  No emoji: the
## pictogram is drawn (`UiTrapIcoon`), on the button and before the title.
const TRAP := "Trap"
const TRAP_TITEL := "Neem de trap"
const TRAP_BLAD := "De trap"
const TRAP_HINT := "Waar wil je heen?"

# ------------------------------------------------------------ §7.7 prikbord
## The board is a sheet (owner, 2026-09-23); its cards are the hotel's own
## strings, this is only what the sheet says around them.
const BORD_HINT := "Tik op een taakje om erheen te gaan."

## Where a task card is done, under its sentence: "in de keuken", "in kamer 1",
## "bij het zwembad" — a room with a number has no article, and the pool is a
## place you stand next to, not in.
static func in_kamer(kamer_id: String, naam: String) -> String:
	if kamer_id == "zwembad":
		return "bij het zwembad"
	if naam.to_lower().begins_with("kamer"):
		return "in " + naam.to_lower()
	return "in de " + naam.to_lower()

# ------------------------------------------------------------- §7.4 deuren
## `Ga naar <kamernaam>` — the title of a door hotspot.
static func ga_naar(kamer_naam: String) -> String:
	return "Ga naar %s" % kamer_naam

# --------------------------------------------------------------- §7.9 kassa
const KASSA_TITEL := "💰 De kassa"
const KASSA_UITLEG_1 := "Munten komen uit het uitchecken: elke gast betaalt zijn nachten. Sterren krijg je voor meedoen — of je som klopt of niet."
const KASSA_UITLEG_2 := "In het meubelboek koop je straks nieuwe bedden, mandjes en badkuipen. Meer bedden = meer gasten = grotere sommen."
## The same rule on the till sheet: `💰 1 munt`, `⭐ 1 ster` (V1 finding 3).
static func kassa_munten(n: int) -> String:
	return "💰 %s" % Ui.meervoud(n, "munt", "munten")
static func kassa_sterren(n: int) -> String:
	return "⭐ %s" % Ui.meervoud(n, "ster", "sterren")
static func kassa_snoep(n: int) -> String:
	return "🍬 %d in de snoeppot" % n

# ------------------------------------------------------- §7.8 brievenmuur
const BRIEVEN_TITEL := "💌 De brievenmuur"
const BRIEVEN_UITLEG_1 := "Hier komen de bedankjes van de families die hun dier bij jou lieten slapen."
const BRIEVEN_UITLEG_2 := "Laat een gast zijn nachten uitslapen en reken netjes af — dan komt er post."

# ------------------------------------------------------------------ §7.10
const SPEL_MIS := "💛 Probeer iets anders"

## A miss, said by the animal (S5, owner 2026-09-20).  Pictogram and word in
## one bubble, as always; together they read `🔄 Nog een keer` — three words,
## fourteen characters.  It is not a scolding and it is not a repeat of the
## turn: the same question comes back after a short pause, and nothing was
## taken away to get there.
##
## The plan asked for `😢`.  That codepoint (U+1F622) is not in `fonts/Emoji.ttf`,
## the 112-glyph subset this build ships, so it would have drawn tofu.  🔄
## (U+1F504) is in the subset and is already the house glyph for `opnieuw`
## (voerkar `ICO_OPNIEUW`, tobbe's "opnieuw", bedden's "terug"), so the
## picture says what the word says.  The sadness the plan wanted is not lost:
## it is carried by the animal itself, which goes `sip`.
const MIS_ICOON := "🔄"
const MIS_ZIN := "Nog een keer"

# ------------------------------------------------------------- de spelbalk
## The one button that leaves a running minigame, always in the same place
## (bottom left of the frame) with the game's name beside it.
const TERUG := "⬅ Terug"
const TERUG_TITEL := "Terug naar het hotel"

## The animal of the turn, beside it (owner, 2026-09-23: "een methode om te
## wisselen met welk dier je de spellen speelt"): `🐶 Boef 🔄`.  Its pictogram
## and its name, and 🔄 for "another one" — tap it and the next animal plays.
##
## The design sketch had ⇄ (U+21C4).  That arrow is in none of the three
## bundled subsets, and not in Noto Sans Symbols 2 either (only Noto Sans Math
## carries it), so it would have drawn tofu; 🔄 is in `fonts/Emoji.ttf` and is
## the house glyph for "nog een keer / opnieuw", which is what a switch is: the
## same game once more, with somebody else.
const SPELER_WISSEL := "🔄"
const SPELER_TITEL := "Speel met een ander dier"

## The label of the animal button.  The pictogram is the hotel's own
## (`Hotel.DIER_ICOON`, the one its "komt eraan" bubbles wear).  In the rail
## beside the frame the name goes on a line of its own under the two pictures,
## so the button stays as narrow as the rail (three chips of 48 units).
static func speler_knop(icoon: String, naam: String, rail := false) -> String:
	if rail:
		return "%s %s\n%s" % [icoon, SPELER_WISSEL, naam]
	return "%s %s %s" % [icoon, naam, SPELER_WISSEL]
