class_name UiHotelbestand
extends Node
## A hotel as a file, for a parent (owner 2026-10-01: "En ik wil save files
## maken"): `💾 Bewaar` hands the browser a download, `📂 Open` asks the
## browser for a file.  This is ONLY the glue to the platform; what goes into
## the file and whether a file is a hotel is decided in GDScript, headless and
## tested (`State.exporteer`, `State.ontleed`, `UiStartblad.laad_tekst`).
##
## Web: the download is Godot's own `JavaScriptBridge.download_buffer`; the
## file picker is a hidden `<input type=file>` made once by the few lines of
## `JS_KIEZER`, which read the chosen file as text and hand it to a callback.
## A browser opens a file picker only inside a user gesture, and Godot handles
## a tap a frame AFTER the browser's event is over: so the button ARMS the
## picker when the finger goes down (`wapen`), and the picker opens in the
## browser's own `pointerup`/`touchend` of that same tap.  When the tap was so
## quick that Godot saw down and up together, `open()` opens it right away —
## still inside the browser's short "user activation" window.
## Desktop: a `FileDialog`, and the download becomes a file in `user://bewaard/`
## (the folder is shown).  Headless: the file is written, nothing is asked.

## The text of the file the parent picked ("" when it could not be read).
signal gelezen(tekst: String)

const MAP := "user://bewaard"

const JS_KIEZER := """
(function () {
  if (window.dhHotelBestand) return;
  var inv = document.createElement('input');
  inv.type = 'file';
  inv.accept = '.json,application/json,text/plain';
  inv.style.display = 'none';
  document.body.appendChild(inv);
  var terug = null, gewapend = 0;
  inv.addEventListener('change', function () {
    var f = inv.files && inv.files[0];
    inv.value = '';
    if (!f || !terug) return;
    if (f.size > %d) { terug(''); return; }
    var r = new FileReader();
    r.onload = function () { terug(String(r.result || '')); };
    r.onerror = function () { terug(''); };
    r.readAsText(f);
  });
  function open() {
    if (gewapend && Date.now() - gewapend < 1500) { gewapend = 0; inv.click(); }
  }
  ['pointerup', 'touchend'].forEach(function (t) { window.addEventListener(t, open, true); });
  window.dhHotelBestand = {
    terug: function (cb) { terug = cb; },
    wapen: function () { gewapend = Date.now(); },
    open: open
  };
})();
"""

var _terug = null          ## the JavaScriptObject callback; kept, or it is collected
var _dialoog: FileDialog = null

static func web() -> bool:
	return OS.has_feature("web")

## The finger went down on `📂 Open` (web only; elsewhere nothing to arm).
func wapen() -> void:
	if not web():
		return
	_maak_kiezer()
	JavaScriptBridge.eval("window.dhHotelBestand && window.dhHotelBestand.wapen()", true)

## Ask for a file.  Returns false where nobody can be asked (headless).
func open() -> bool:
	if web():
		_maak_kiezer()
		JavaScriptBridge.eval("window.dhHotelBestand && window.dhHotelBestand.open()", true)
		return true
	if DisplayServer.get_name() == "headless":
		return false
	if _dialoog == null:
		_dialoog = FileDialog.new()
		_dialoog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialoog.access = FileDialog.ACCESS_FILESYSTEM
		_dialoog.filters = PackedStringArray(["*.json"])
		_dialoog.use_native_dialog = true
		_dialoog.file_selected.connect(func(pad: String) -> void:
			gelezen.emit(_lees(pad)))
		add_child(_dialoog)
	_dialoog.popup_centered_ratio(0.6)
	return true

## Hand `tekst` over as the file `naam`.  Returns where it went: "download" on
## the web, the full path of the file elsewhere, "" when it failed.
func bewaar(naam: String, tekst: String) -> String:
	if web():
		JavaScriptBridge.download_buffer(tekst.to_utf8_buffer(), naam, "application/json")
		return "download"
	DirAccess.make_dir_recursive_absolute(MAP)
	var pad := MAP.path_join(naam)
	var f := FileAccess.open(pad, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(tekst)
	f.close()
	var echt := ProjectSettings.globalize_path(pad)
	if DisplayServer.get_name() != "headless":
		OS.shell_show_in_file_manager(echt)
	return echt

func _maak_kiezer() -> void:
	if _terug != null:
		return
	JavaScriptBridge.eval(JS_KIEZER % State.BESTAND_MAX, true)
	_terug = JavaScriptBridge.create_callback(func(args: Array) -> void:
		gelezen.emit(str(args[0]) if args.size() > 0 and args[0] != null else ""))
	var kiezer = JavaScriptBridge.get_interface("dhHotelBestand")
	if kiezer != null:
		kiezer.terug(_terug)

func _lees(pad: String) -> String:
	var f := FileAccess.open(pad, FileAccess.READ)
	if f == null:
		return ""
	if f.get_length() > State.BESTAND_MAX:
		f.close()
		return ""
	var tekst := f.get_as_text()
	f.close()
	return tekst
