# I2 — Wave-2 integration: contract gaps and cross-cutting fixes (draft, grows as games land)

TASK
After all ten game branches are merged into main, close the contract gaps the game workers reported (they worked around each inside their own folder; the workarounds stay until the central fix lands, then each game's local workaround is removed by this ticket), fix the cross-cutting test, and re-run everything.

ITEMS SO FAR
1. tests/test_hotel.gd morgen trace asserts every bedded guest wants "eten" each morning; with wish-granting games registered (zwembad, tobbe, hinkel, kraam) a guest gets 🎁/🏊 on days 3/5/7. Make the assertion honest: hide wave-2 games from the registry in that test's _voor() (as the file already does for stand-ins) or widen it to ["eten"] + Hotel.NIEUWE_WENS.
2. Ui.bron: support an unlimited source (no count pill, drag allowed with aantal ≤ 0 or a flag) and a minimum size (kraam).
3. UiGetalTag: add the "veel" (pink) variant used by kraam.
4. Ui.zet_scherm: allow un-setting (Vector2.ZERO = no screen) and reset it in the runner between test files (kraam, wekker).
5. Hotel.spel_taken(): a taak.prio may be a Callable (hinkel: 2 or 5); call it with State.s.
6. Ui.somkaart(): a second somkaart with the same id loses the card because the new Kaart is stored before Hits.maak removes the old spot whose on_weg erases it (hinkel). Order the operations correctly and add a test.
7. Hits: a spot with no object must be expressible (wekker's dial tag on the dial): a `geen_vlak: true` flag that disables the lift-off-own-object rule. (Hits.plaats() already hides unplaced spots since V1-F1; remove the wekker workaround.)
8. Name plate over the keypad band at 740×360 without krap (kraam): the keypad band must reserve its cells before name plates are placed, or plates flip below the guest.
9. Price tag 10.56 % overlap by height on the €12 bag at 360×740 (kraam): decide whether dekking measures area or height; make the rule and the measurement agree and document it in §4.3.
10. A dev hook to start from a given save in the browser (query flag `?opslag=<base64 json>` or a `[probe]`-only injection) so every wave-2 browser proof can reach bands 4/5 without playing days; must be disabled in the production build or harmless (read-only when the flag is absent).
11. The worktrees started before V1-F1 do not have the isolated test.sh; after the merge, run the whole suite with the new test.sh three times and report flakiness.
(more items appended as games land)
12. tools/test.sh counts a 4th ERROR "2 resources still in use at exit" (17 leaked ObjectDB) whenever any test file sorts before tests/test_art.gd; games/<id>/test_<id>.gd always does. Find the leak in test_art.gd's setup order (or the runner's teardown) and fix it centrally (zwembad reproduced it with a 4-line empty test file).
13. Ui.somkaart: forward a `volg` option to the Hits spot (zwembad sets Hits.spot(id).volg after creation).
14. tools/export.sh and tools/probe.js: per-worktree log dir and port (DH_LOG_DIR, DH_PORT) so parallel runs cannot overwrite each other or probe another build.
15. Snd.klok(force := false): the waking gong in wekker must never be throttled (games-b §2.9); add a force path and remove wekker's local workaround.
16. Ui.vergeet_scherm() public reset (sleutels, wekker, kraam) and a runner-level reset between test files.
17. ctx.ui.wolk: add a hang-on-object/guest form (obj or dier id) so games do not build x/z or volg themselves (sleutels).
18. ui/kamerbalk.gd::_chip crashes when a stale shell (freed or replaced) still answers Ui.thema_veranderd; disconnect on exit_tree (sleutels saw it with five shells in one process).
19. ui/kaart.gd: BREED_KLEIN 170 with text clamped to breed−20 wraps a 28-character F4-valid sentence under the paper ruling at 360×740 (kraam "Boef gaf €20, het kost €11"); let the card grow to the frame width minus margins on phones, or draw the ruling under the measured text height. Verify with the longest F4 sentence of every game.
20. ui/bron.gd: the hand badge must be "☝" (icon only, per games-b §5.8) or "☝ 1 munt" (icon with word), never "☝ 1"; and it must not straddle the ✔ klaar button.
21. Kraam NITs (apply after the merge, in games/kraam/): taak.tekst must use the same !blij filter as wanneer; set g["waar"] only on arrival; avoid the first-frame 145 px card.
22. Rooms.meubel_zet returns `id` for a slot but `meubel` for decor: make the return shape one thing and document it (meubels).
23. Font subset: decide the allowed glyph set for games (add U+21A9 ↩ and U+FF0B ＋ or document the exclusion) and add a headless test that every string literal in games/**/*.gd is covered by the bundled fonts (the glyph check Ui already has).
24. Suite time: 15 s → 40 s with four shell viewports per game; after the merge, measure and, if over 60 s, share one shell per test file or cache built shells in the runner (tests must stay honest).
