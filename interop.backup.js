// web/interop.js (ESM)
// - Mic (Web Speech API) → emite ''bitacora:speech'' con {text}
// - GPS (Geolocation API) → emite ''bitacora:gps'' con {lat, lon, accuracy, ... , text}
// - FABs arrastrables con long-press; guardan posición en localStorage
(() => {
  const on = (el, ev, fn, opt) => el && el.addEventListener(ev, fn, opt);
  const off = (el, ev, fn, opt) => el && el.removeEventListener(ev, fn, opt);
  const dispatch = (name, detail) =>
    window.dispatchEvent(new CustomEvent(name, { detail }));

  // Speech-to-text
  let rec = null;
  function toggleMic() {
    try {
      const Speech = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!Speech) { alert('SpeechRecognition no disponible en este navegador.'); return; }
      if (rec) { rec.stop(); rec = null; return; }

      rec = new Speech();
      rec.lang = 'es-AR';
      rec.interimResults = false;
      rec.maxAlternatives = 1;

      rec.onresult = (e) => {
        const txt = e.results?.[0]?.[0]?.transcript || '';
        if (txt) dispatch('bitacora:speech', { text: txt });
      };
      rec.onerror = (e) => console.warn('speech error', e);
      rec.onend = () => { rec = null; };
      rec.start();
    } catch (err) {
      console.error(err);
      alert('Error al iniciar el micrófono.');
    }
  }

  // Geolocalización
  function askGps() {
    if (!('geolocation' in navigator)) { alert('Geolocalización no disponible.'); return; }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const { latitude, longitude, accuracy, altitude, speed, heading } = pos.coords || {};
        dispatch('bitacora:gps', {
          lat: latitude, lon: longitude, accuracy, altitude, speed, heading,
          text: `${latitude?.toFixed(6)}, ${longitude?.toFixed(6)} ±${Math.round(accuracy || 0)} m`,
        });
      },
      (err) => { console.warn('geo error', err); alert('No se pudo obtener ubicación.'); },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    );
  }

  // Drag de FABs con long-press (250 ms)
  function makeDraggable(el) {
    if (!el) return;
    const key = `pos:${el.id}`;
    const restore = () => {
      const s = localStorage.getItem(key);
      if (!s) return;
      try {
        const o = JSON.parse(s);
        if (o.left && o.top) {
          el.style.left = o.left; el.style.top = o.top;
          el.style.right = 'auto'; el.style.bottom = 'auto';
        }
      } catch {}
    };
    const save = () => localStorage.setItem(key, JSON.stringify({ left: el.style.left, top: el.style.top }));

    let startX=0, startY=0, origX=0, origY=0;
    let dragging = false;
    let pressTimer = null;

    const pointerDown = (e) => {
      const p = e.touches?.[0] || e;
      startX = p.clientX; startY = p.clientY;
      const rect = el.getBoundingClientRect();
      origX = rect.left; origY = rect.top;

      pressTimer = setTimeout(() => { dragging = true; el.classList.add('dragging'); }, 250);
      on(window, 'pointermove', pointerMove, { passive: false });
      on(window, 'pointerup', pointerUp, { passive: false, once: true });
    };

    const pointerMove = (e) => {
      const p = e;
      const dx = p.clientX - startX;
      const dy = p.clientY - startY;

      if (!dragging && (Math.abs(dx) > 6 || Math.abs(dy) > 6)) {
        dragging = true; el.classList.add('dragging'); clearTimeout(pressTimer);
      }
      if (dragging) {
        e.preventDefault();
        const x = Math.max(8, Math.min(window.innerWidth - el.offsetWidth - 8, origX + dx));
        const y = Math.max(8, Math.min(window.innerHeight - el.offsetHeight - 8, origY + dy));
        el.style.left = `${x}px`; el.style.top = `${y}px`;
        el.style.right = 'auto'; el.style.bottom = 'auto';
      }
    };

    const pointerUp = () => {
      clearTimeout(pressTimer);
      off(window, 'pointermove', pointerMove);
      if (dragging) { dragging = false; el.classList.remove('dragging'); save(); }
    };

    on(el, 'pointerdown', pointerDown, { passive: true });
    restore();
  }

  // Wire up
  const gpsFab = document.getElementById('gpsFab');
  const micFab = document.getElementById('micFab');
  on(gpsFab, 'click', askGps);
  on(micFab, 'click', toggleMic);
  makeDraggable(gpsFab);
  makeDraggable(micFab);

  // Hooks desde Flutter
  window.addEventListener('bitacora:toggleMic', toggleMic);
  window.addEventListener('bitacora:askGps', askGps);
})();
