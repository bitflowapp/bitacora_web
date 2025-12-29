// web/interop.js
(() => {
  const on = (el, ev, fn, opt) => el && el.addEventListener(ev, fn, opt);
  const dispatch = (name, detail) => window.dispatchEvent(new CustomEvent(name, { detail }));

  // ---------- Helpers seguros (Safari / private mode) ----------
  const safeLS = {
    get(key) {
      try { return localStorage.getItem(key); } catch (_) { return null; }
    },
    set(key, val) {
      try { localStorage.setItem(key, val); } catch (_) {}
    },
  };

  // iOS / iPadOS moderno (iPadOS se hace pasar por Mac)
  const ua = navigator.userAgent || '';
  const isAppleMobile =
    /iPad|iPhone|iPod/.test(ua) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

  // ---------- Inyectar CSS + FABs si no existen ----------
  function ensureStyle() {
    if (document.getElementById('bf-interop-style')) return;
    const st = document.createElement('style');
    st.id = 'bf-interop-style';
    st.textContent = `
      .bf-fab {
        position: fixed;
        z-index: 2147483646;
        width: 52px;
        height: 52px;
        border-radius: 999px;
        border: 1px solid rgba(0,0,0,0.18);
        background: rgba(255,255,255,0.86);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
        box-shadow: 0 10px 28px rgba(0,0,0,0.14);
        display: grid;
        place-items: center;
        cursor: pointer;
        user-select: none;
        -webkit-user-select: none;
        touch-action: none; /* importante para drag */
      }
      .bf-fab:active { transform: scale(0.98); }
      .bf-fab[disabled] {
        opacity: 0.45;
        cursor: not-allowed;
        filter: grayscale(0.3);
      }
      .bf-fab.levitating { box-shadow: 0 18px 44px rgba(0,0,0,0.22); }
      .bf-fab.dragging { transform: scale(1.02); }
      .bf-fab.is-recording {
        outline: 2px solid rgba(255,0,0,0.55);
        outline-offset: 2px;
      }
      .bf-fab svg { width: 22px; height: 22px; opacity: 0.9; }
    `;
    document.head.appendChild(st);
  }

  function ensureFab(id, defaultPos, title, svgPathD) {
    let el = document.getElementById(id);
    if (el) return el;

    el = document.createElement('button');
    el.id = id;
    el.type = 'button';
    el.className = 'bf-fab';
    el.title = title;

    // default pos
    el.style.right = defaultPos.right;
    el.style.bottom = defaultPos.bottom;

    el.innerHTML = `
      <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
        <path d="${svgPathD}"></path>
      </svg>
    `;

    document.body.appendChild(el);
    return el;
  }

  // ---------- Speech-to-text ----------
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  const SpeechOk = !!SR && !isAppleMobile; // mantenemos tu regla: no iPhone/iPad

  let rec = null;
  let recording = false;

  function setRecordingUI(on) {
    recording = !!on;
    const micFab = document.getElementById('micFab');
    if (micFab) micFab.classList.toggle('is-recording', recording);
  }

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
          if (r && r.isFinal) finalText += (r[0]?.transcript || '');
        }
        finalText = (finalText || '').trim();
        if (finalText) {
          dispatch('bitacora:speech', { text: finalText });
          try { navigator.clipboard?.writeText?.(finalText); } catch (_) {}
        }
      };

      rec.onerror = () => {
        setRecordingUI(false);
      };

      rec.onend = () => {
        // si seguimos “grabando”, reintenta
        if (recording) {
          try { rec.start(); } catch (_) {}
        }
      };
    }

    try {
      rec.start();
      setRecordingUI(true);
    } catch (_) {}
  }

  function stopSpeech() {
    setRecordingUI(false);
    try { rec && rec.stop(); } catch (_) {}
  }

  function toggleMic() {
    recording ? stopSpeech() : startSpeech();
  }

  // ---------- Geolocalización ----------
  function askGps() {
    if (!('geolocation' in navigator)) { alert('Geolocalización no disponible.'); return; }

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const c = pos.coords || {};
        const latitude = c.latitude;
        const longitude = c.longitude;
        const accuracy = c.accuracy;
        const altitude = c.altitude;
        const speed = c.speed;
        const heading = c.heading;

        const latOk = Number.isFinite(latitude);
        const lonOk = Number.isFinite(longitude);
        if (!latOk || !lonOk) { alert('Ubicación inválida.'); return; }

        const lat = latitude.toFixed(6);
        const lon = longitude.toFixed(6);
        const accStr = Number.isFinite(accuracy) && accuracy > 0 ? ` ±${Math.round(accuracy)} m` : '';
        const text = `${lat}, ${lon}${accStr}`;

        dispatch('bitacora:gps', { lat: latitude, lon: longitude, accuracy, altitude, speed, heading, text });

        try { navigator.clipboard?.writeText?.(text); } catch (_) {}
      },
      (err) => {
        console.warn('geo error', err);
        alert('No se pudo obtener ubicación.');
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    );
  }

  // Hooks desde Flutter
  window.addEventListener('bitacora:askGps', askGps);
  window.addEventListener('bitacora:toggleMic', toggleMic);

  // ---------- Drag con long-press + persistencia ----------
  function makeDraggable(el, key) {
    if (!el) return;

    const saved = safeLS.get(key);
    if (saved) {
      try {
        const { x, y } = JSON.parse(saved);
        if (Number.isFinite(x) && Number.isFinite(y)) {
          el.style.left = x + 'px';
          el.style.top = y + 'px';
          el.style.right = '';
          el.style.bottom = '';
        }
      } catch (_) {}
    }

    let dragging = false;
    let pressT = null;
    let moved = false;

    let startX = 0, startY = 0, elX = 0, elY = 0;

    const clamp = (v, min, max) => Math.max(min, Math.min(max, v));

    const bounds = () => {
      const w = window.innerWidth, h = window.innerHeight;
      const r = el.getBoundingClientRect();
      return { maxX: w - r.width - 8, maxY: h - r.height - 8 };
    };

    const startDrag = (px, py) => {
      dragging = true;
      moved = false;
      el.classList.add('levitating', 'dragging');
      const r = el.getBoundingClientRect();
      elX = r.left; elY = r.top;
      startX = px; startY = py;
      el.style.right = '';
      el.style.bottom = '';
      el.style.left = elX + 'px';
      el.style.top = elY + 'px';
    };

    const moveDrag = (px, py) => {
      if (!dragging) return;
      const dx = px - startX, dy = py - startY;
      if (Math.abs(dx) > 4 || Math.abs(dy) > 4) moved = true;
      const b = bounds();
      el.style.left = clamp(elX + dx, 8, b.maxX) + 'px';
      el.style.top = clamp(elY + dy, 8, b.maxY) + 'px';
    };

    const endDrag = () => {
      if (!dragging) return;
      dragging = false;
      el.classList.remove('levitating', 'dragging');
      try {
        const r = el.getBoundingClientRect();
        safeLS.set(key, JSON.stringify({ x: r.left, y: r.top }));
      } catch (_) {}
    };

    const cancelPress = () => {
      if (pressT) { clearTimeout(pressT); pressT = null; }
    };

    el.addEventListener('pointerdown', (ev) => {
      // Si está disabled, no hagas nada
      if (el.hasAttribute('disabled')) return;

      // Mouse: drag SOLO con Alt (si no, click normal)
      if (ev.pointerType === 'mouse') {
        if (!ev.altKey) return;
        ev.preventDefault();
        startDrag(ev.clientX, ev.clientY);
      } else {
        // Touch: long press 280ms
        ev.preventDefault();
        cancelPress();
        const downX = ev.clientX, downY = ev.clientY;
        pressT = setTimeout(() => startDrag(downX, downY), 280);
      }

      try { el.setPointerCapture(ev.pointerId); } catch (_) {}
    }, { passive: false });

    el.addEventListener('pointermove', (ev) => {
      if (pressT && !dragging) {
        // Si el dedo se movió, cancelá el long-press
        const dx = ev.movementX || 0;
        const dy = ev.movementY || 0;
        if (Math.abs(dx) > 2 || Math.abs(dy) > 2) cancelPress();
        return;
      }
      moveDrag(ev.clientX, ev.clientY);
    }, { passive: true });

    el.addEventListener('pointerup', (ev) => {
      cancelPress();
      try { el.releasePointerCapture(ev.pointerId); } catch (_) {}
      endDrag();

      // Si se movió, cancelá el click “fantasma”
      if (moved) {
        moved = false;
        ev.preventDefault();
        ev.stopPropagation();
      }
    }, { passive: false });

    el.addEventListener('pointercancel', () => { cancelPress(); endDrag(); });

    window.addEventListener('resize', () => {
      const r = el.getBoundingClientRect();
      const b = bounds();
      el.style.left = clamp(r.left, 8, b.maxX) + 'px';
      el.style.top = clamp(r.top, 8, b.maxY) + 'px';
    }, { passive: true });
  }

  // ---------- Boot ----------
  function init() {
    ensureStyle();

    // Iconos minimalistas (path)
    const gpsPath = 'M12 2c3.86 0 7 3.14 7 7 0 5.25-7 13-7 13S5 14.25 5 9c0-3.86 3.14-7 7-7zm0 9.5A2.5 2.5 0 1 0 12 6.5a2.5 2.5 0 0 0 0 5z';
    const micPath = 'M12 14a3 3 0 0 0 3-3V6a3 3 0 0 0-6 0v5a3 3 0 0 0 3 3zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.92V21h2v-3.08A7 7 0 0 0 19 11h-2z';

    const gpsFab = ensureFab('gpsFab', { right: '14px', bottom: '86px' }, 'GPS', gpsPath);
    const micFab = ensureFab('micFab', { right: '14px', bottom: '22px' }, 'Micrófono', micPath);

    // Clicks
    gpsFab.addEventListener('click', askGps);

    if (!SpeechOk) {
      micFab.setAttribute('disabled', 'true');
      micFab.title = isAppleMobile
        ? 'Dictado web no soportado en iPhone/iPad. Usá el mic del teclado.'
        : 'SpeechRecognition no disponible en este navegador.';
    } else {
      micFab.addEventListener('click', () => {
        toggleMic();
        // UI se sincroniza por setRecordingUI()
      });
    }

    // Drag persistente
    makeDraggable(micFab, 'fab:mic');
    makeDraggable(gpsFab, 'fab:gps');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
