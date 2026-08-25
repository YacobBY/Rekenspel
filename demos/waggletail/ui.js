/* ui.js - kleine helpers: selecteren, toast, sheet en slepen met pointer events */
function $(sel, root) { return (root || document).querySelector(sel); }
function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

function esc(s) {
  return String(s).replace(/[&<>"]/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
  });
}

function meervoud(n, een, veel) { return n === 1 ? n + ' ' + een : n + ' ' + veel; }

/* 'de bezorger brengt de brokken' -> 'De bezorger brengt de brokken' */
function hoofdletter(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

var _toastT = null;
function toast(msg, kind) {
  var t = $('#toast');
  t.textContent = msg;
  t.className = 'toast ' + (kind || '');
  clearTimeout(_toastT);
  _toastT = setTimeout(function () { t.className = 'toast hidden'; }, 2600);
}

function openSheet(html) {
  var o = $('#overlay');
  $('#sheet').innerHTML = html;
  o.classList.remove('hidden');
  o.setAttribute('aria-hidden', 'false');
  return $('#sheet');
}
function closeSheet() {
  var o = $('#overlay');
  o.classList.add('hidden');
  o.setAttribute('aria-hidden', 'true');
  $('#sheet').innerHTML = '';
}
document.addEventListener('click', function (e) {
  if (e.target && e.target.id === 'overlay') closeSheet();
});

function shake(node) {
  if (!node) return;
  node.classList.remove('wiggle');
  void node.offsetWidth;
  node.classList.add('wiggle');
}

/* ---------------------------------------------------------------
   dragKit: werkt met muis, pen en vinger (pointer events).
   opts = { ghostHTML(), dropSel, canDrag(), onDrop(target), onTap() }
   Kleine beweging telt als tik -> ook bruikbaar zonder slepen.
---------------------------------------------------------------- */
function makeDraggable(node, opts) {

  function targetAt(x, y) {
    var e = document.elementFromPoint(x, y);
    return e && e.closest ? e.closest(opts.dropSel) : null;
  }

  node.addEventListener('pointerdown', function (ev) {
    if (opts.canDrag && !opts.canDrag()) return;
    if (ev.button !== undefined && ev.button !== 0) return;

    var sx = ev.clientX, sy = ev.clientY, pid = ev.pointerId;
    var ghost = null, hot = null, dragging = false;
    ev.preventDefault();
    /* capture is fijn, maar we luisteren op window zodat het ook zonder werkt */
    try { node.setPointerCapture(pid); } catch (e) { /* geeft niet */ }

    function stop() {
      window.removeEventListener('pointermove', move, true);
      window.removeEventListener('pointerup', up, true);
      window.removeEventListener('pointercancel', cancel, true);
      document.body.classList.remove('sleept');
      if (ghost && ghost.parentNode) ghost.parentNode.removeChild(ghost);
      if (hot) hot.classList.remove('drop-hot');
      ghost = null; hot = null;
    }

    function move(e2) {
      if (e2.pointerId !== pid) return;
      var dx = e2.clientX - sx, dy = e2.clientY - sy;
      if (!dragging && dx * dx + dy * dy < 64) return;
      if (!dragging) {
        dragging = true;
        /* tijdens het slepen mogen geplaatste blokjes de vakjes eronder niet afschermen */
        document.body.classList.add('sleept');
        ghost = document.createElement('div');
        ghost.className = 'ghost';
        ghost.innerHTML = opts.ghostHTML ? opts.ghostHTML() : node.outerHTML;
        document.body.appendChild(ghost);
      }
      ghost.style.left = e2.clientX + 'px';
      ghost.style.top = e2.clientY + 'px';
      var t = targetAt(e2.clientX, e2.clientY);
      if (t !== hot) {
        if (hot) hot.classList.remove('drop-hot');
        hot = t;
        if (hot) hot.classList.add('drop-hot');
      }
    }

    function up(e2) {
      if (e2.pointerId !== pid) return;
      var wasDrag = dragging;
      var t = wasDrag ? targetAt(e2.clientX, e2.clientY) : null;
      stop();
      if (wasDrag) { if (t && opts.onDrop) opts.onDrop(t); }
      else if (opts.onTap) opts.onTap();
    }

    function cancel(e2) { if (e2.pointerId === pid) stop(); }

    window.addEventListener('pointermove', move, true);
    window.addEventListener('pointerup', up, true);
    window.addEventListener('pointercancel', cancel, true);
  });
}
