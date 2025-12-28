// web/interop.js (ESM)
(() => {
  const on = (el, ev, fn, opt) => el && el.addEventListener(ev, fn, opt);
  const dispatch = (name, detail) => window.dispatchEvent(new CustomEvent(name, { detail }));

  // ---------- Speech-to-text ----------
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  const SpeechOk = !!SR && !isIOS;

  let rec = null;
  let recording = false;

  function startSpeech(lang = 'es-AR') {
    if (!SpeechOk) return;
    if (!rec) {
      rec = new SR();
      rec.lang = lang;
      rec.interimResults = true;
      rec.continuous = true;
      rec.onresult = (e) => {
        let finalText = '';
        for (let i = e.resultIndex; i < e.results.length; i++) {
          const r = e.results[i];
          if (r.isFinal) finalText += r[0].transcript;
        }
        finalText = finalText.trim();
        if (finalText) {
          dispatch('bitacora:speech', { text: finalText });
          try { navigator.clipboard.writeText(finalText); } catch {}
        }
      };
      rec.onerror = (e) => { recording = false; };
      rec.onend = () => { if (recording) try { rec.start(); } catch {} };
    }
    try { rec.start(); recording = true; } catch {}
  }
  function stopSpeech() { recording = false; try { rec && rec.stop(); } catch {} }
  function toggleMic() { recording ? stopSpeech() : startSpeech(); }

  // ---------- Geolocalización ----------
  function askGps() {
    if (!('geolocation' in navigator)) { alert('Geolocalización no disponible.'); return; }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const { latitude, longitude, accuracy, altitude, speed, heading } = pos.coords || {};
        const lat = Number(latitude)?.toFixed(6);
        const lon = Number(longitude)?.toFixed(6);
        // usar “±” real y sólo si accuracy es válida (>0)
        const accStr = Number.isFinite(accuracy) && accuracy > 0 ? ` ±${Math.round(accuracy)} m` : '';
        const text = `${lat}, ${lon}${accStr}`;

        dispatch('bitacora:gps', { lat: latitude, lon: longitude, accuracy, altitude, speed, heading, text });

        try { navigator.clipboard.writeText(text); } catch {}
      },
      (err) => { console.warn('geo error', err); alert('No se pudo obtener ubicación.'); },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    );
  }

  // Hooks desde Flutter
  window.addEventListener('bitacora:askGps', askGps);
  window.addEventListener('bitacora:toggleMic', toggleMic);

  // ---------- FABs ----------
  const gpsFab = document.getElementById('gpsFab');
  const micFab = document.getElementById('micFab');
  if (gpsFab) gpsFab.addEventListener('click', askGps);
  if (micFab) {
    if (!SpeechOk) {
      micFab.setAttribute('disabled', 'true');
      micFab.title = 'Dictado web no soportado en iPhone. Usá el mic del teclado.';
    } else {
      micFab.addEventListener('click', () => {
        toggleMic();
        micFab.classList.toggle('is-recording', !!recording);
      });
    }
  }

  // ---------- Drag con long-press y posición persistente ----------
  function makeDraggable(el, key) {
    if (!el) return;
    const saved = localStorage.getItem(key);
    if (saved) {
      try {
        const { x, y } = JSON.parse(saved);
        if (Number.isFinite(x) && Number.isFinite(y)) {
          el.style.left = x + 'px';
          el.style.top = y + 'px';
          el.classList.add('free');
          el.style.right = '';
          el.style.bottom = '';
        }
      } catch {}
    }
    let dragging = false, longPress = false, pressT = null, moved = false;
    let startX = 0, startY = 0, elX = 0, elY = 0;
    const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
    const bounds = () => {
      const w = window.innerWidth, h = window.innerHeight;
      const r = el.getBoundingClientRect();
      return { maxX: w - r.width - 8, maxY: h - r.height - 8 };
    };
    const startDrag = (px, py) => {
      dragging = true; el.classList.add('levitating', 'dragging', 'free');
      const r = el.getBoundingClientRect(); elX = r.left; elY = r.top; startX = px; startY = py;
      el.style.right = ''; el.style.bottom = '';
    };
    const moveDrag = (px, py) => {
      if (!dragging) return;
      const dx = px - startX, dy = py - startY;
      if (Math.abs(dx) > 4 || Math.abs(dy) > 4) moved = true;
      const b = bounds();
      el.style.left = clamp(elX + dx, 8, b.maxX) + 'px';
      el.style.top  = clamp(elY + dy, 8, b.maxY) + 'px';
    };
    const endDrag = () => {
      if (!dragging) return false;
      dragging = false; el.classList.remove('levitating', 'dragging');
      try {
        const r = el.getBoundingClientRect();
        localStorage.setItem(key, JSON.stringify({ x: r.left, y: r.top }));
      } catch {}
      const wasMoved = moved; moved = false; return wasMoved;
    };
    const cancelPress = () => { if (pressT) { clearTimeout(pressT); pressT = null; } longPress = false; };

    el.addEventListener('pointerdown', (ev) => {
      if (ev.pointerType === 'mouse') { startDrag(ev.clientX, ev.clientY); }
      else { longPress = true; pressT = setTimeout(() => startDrag(ev.clientX, ev.clientY), 280); }
      el.setPointerCapture(ev.pointerId);
    });
    el.addEventListener('pointermove', (ev) => {
      if (longPress && !dragging) return;
      moveDrag(ev.clientX, ev.clientY);
    });
    el.addEventListener('pointerup', (ev) => { cancelPress(); el.releasePointerCapture(ev.pointerId); endDrag(); });
    el.addEventListener('pointercancel', () => { cancelPress(); endDrag(); });

    window.addEventListener('resize', () => {
      const r = el.getBoundingClientRect(); const b = bounds();
      el.style.left = clamp(r.left, 8, b.maxX) + 'px';
      el.style.top  = clamp(r.top,  8, b.maxY) + 'px';
    });
  }
  makeDraggable(micFab, 'fab:mic');
  makeDraggable(gpsFab, 'fab:gps');
})();
