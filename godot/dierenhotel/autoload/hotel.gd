extends Node
## Hotel — the day, the wishes, check-in, the prikbord and the HUD.  Autoload #10.
## Port of `demos/dierenhotel/hotel.js` (world.md §3).
##
## W2 fills in every method here: morgen() with its eight steps, the wish
## algorithm of §3.2, the bell and the three-step check-in of §3.3, feeding and
## playing (§3.4), the evening round and the bill (§3.5), stars/coins/letters
## (§3.6), the prikbord with its 3-chip cap and fair rotation (§3.7) and the HUD
## (§3.8).  The skeleton only carries the signals the other modules call.

signal hud_veranderd()
signal bord_veranderd()
signal dag_veranderd(dag: int)

func start() -> void:
	pass                                 # W2

func render() -> void:
	hud_veranderd.emit()                 # W2

func hud() -> void:
	hud_veranderd.emit()                 # W2

func morgen() -> void:
	push_warning("Hotel.morgen: W2")     # W2

func bel() -> void:
	push_warning("Hotel.bel: W2")        # W2

func avondronde() -> void:
	push_warning("Hotel.avondronde: W2") # W2

func bord_dicht() -> void:
	bord_veranderd.emit()                # W2

func bord_open() -> void:
	bord_veranderd.emit()                # W2

## `Hotel.taakAf(id)` — tick a task card by task id or by game id.
func taak_af(_id: String) -> void:
	pass                                 # W2

## `Hotel.wensAf(gastId, welke)` = ctx.wereld.behoefteKlaar.  No star.
func wens_af(_gast_id: String, _welke: String) -> bool:
	return false                         # W2

func naar_kamer(id: String) -> void:
	World.naar(id)
	State.s["kamerNu"] = id
	Snd.deur()
	render()
