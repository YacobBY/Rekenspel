/* ---------------------------------------------------------------
   game.js - opstarten en de knoppen om de wereld heen.

   Klein gehouden: het hotel zelf zit in hotel.js, de ruimtes in
   rooms.js en elk spelletje in games/. Hier staat alleen de
   startvraag ("verder spelen of nieuw spel?"), de balk bovenin en
   het opbergen als je het tabblad wegklikt.
---------------------------------------------------------------- */

/* ---------- de balk bovenin ---------- */
function hudKnoppen() {
  var lb = $('#lettersBtn');
  if (lb) lb.addEventListener('click', function () { Hotel.brievenMuur(); });
  /* de kassa zat op de balie; die knop staat nu bovenin, zodat de receptie
     rustig blijft terwijl er een gast aan de balie staat */
  var mb = $('#muntBadge');
  if (mb) mb.addEventListener('click', function () { Hotel.kassa(); });
  var pb = $('#prikBtn');
  if (pb) pb.addEventListener('click', function () { Hotel.prikbord(); });
  var ab = $('#avondBtn');
  if (ab) ab.addEventListener('click', function () { Hotel.avondronde(); });
  var sb = $('#sndBtn');
  if (sb) {
    sb.textContent = Snd.dempt() ? '🔇' : '🔊';
    sb.addEventListener('click', function () {
      Snd.schakel();
      sb.textContent = Snd.dempt() ? '🔇' : '🔊';
    });
  }
  /* elke knop krijgt een zacht tikje - via delegatie, zo hoeft geen knop apart.
     .padstrip is het cijferpad als het onder het kader staat (laag kader op een
     liggende telefoon): dat is geen .hot, maar het tikt natuurlijk wel. */
  document.addEventListener('click', function (e) {
    if (e.target.closest && (e.target.closest('.btn') || e.target.closest('.hot') ||
                             e.target.closest('.kchip') ||
                             e.target.closest('.padstrip .padk'))) Snd.tik();
  });
}

/* ---------- opbergen als het tabblad naar de achtergrond gaat ---------- */
function bewaarBijWeggaan() {
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'hidden') bewaarSpel();
  });
  window.addEventListener('pagehide', function () { bewaarSpel(); });
}

/* ---------- verder spelen of nieuw spel ---------- */
function beginScherm() {
  var s = leesSpel();
  var oud = s ? null : leesOudSpel();
  newGame();
  Hotel.start();
  if (!s && !oud) { startKeuze = true; bewaarSpel(); return; }

  var h, b = s || oud;
  var gasten = meervoud((b.gasten || []).length, 'gast', 'gasten');
  if (s) {
    h = '<h2>Welkom terug in het Dierenhotel! 👋</h2>' +
      '<p class="hint" style="text-align:center;margin:0 0 14px">Je was bij <b>' +
      meervoud(b.dag || 1, 'dag', 'dagen') + '</b> — met ' + gasten + ', <b>' +
      (b.munten || 0) + '</b> munten en <b>' + (b.sterren || 0) + '</b> sterren.</p>';
  } else {
    h = '<h2>Er staan nog dieren in de Kwispelsteeg! 🐾</h2>' +
      '<p class="hint" style="text-align:center;margin:0 0 14px">Je oude opvang staat nog op deze tablet: ' +
      gasten + '. Neem je ze mee naar het hotel? Ze krijgen dan een echt bed.</p>';
  }
  h += '<div class="row center" style="gap:10px">' +
    '<button class="btn go big" type="button" id="verderBtn">' +
    (s ? 'Verder spelen ▸' : 'Ja, verhuizen naar het hotel ▸') + '</button>' +
    '<button class="btn big" type="button" id="nieuwBtn">Nieuw spel</button></div>';
  openSheet(h);
  $('#verderBtn').onclick = function () {
    closeSheet();
    state = b;
    startKeuze = true;
    herbereken();
    Hotel.start();
    bewaarSpel();
    if (!s) toast('🛏 Geef iedereen een bed', 'happy');
  };
  $('#nieuwBtn').onclick = function () {
    closeSheet();
    wisSpel();
    newGame();
    startKeuze = true;
    Hotel.start();
    bewaarSpel();
  };
}

hudKnoppen();
bewaarBijWeggaan();
beginScherm();
