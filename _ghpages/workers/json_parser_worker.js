/* Simple Web Worker: parsea JSON y envía en chunks para no bloquear UI */
self.onmessage = function (e) {
  try {
    const data = e.data || {};
    if (data.type !== 'start') return;
    const raw = data.raw;
    const chunkSize = data.chunkSize || 800;

    const parsed = JSON.parse(raw);
    const headers = Array.isArray(parsed.headers) ? parsed.headers.map(String) : [];
    const rows = Array.isArray(parsed.rows) ? parsed.rows : [];
    self.postMessage({ type: 'meta', headers: headers, total: rows.length });

    let buf = [];
    for (let i = 0; i < rows.length; i++) {
      const r = Array.isArray(rows[i]) ? rows[i].map(x => String(x ?? '')) : [];
      buf.push(r);
      if (buf.length === chunkSize) {
        self.postMessage({ type: 'chunk', rows: buf, done: false });
        buf = [];
      }
    }
    self.postMessage({ type: 'chunk', rows: buf, done: true });
  } catch (err) {
    self.postMessage({ type: 'error', message: String(err && err.message || err) });
  }
};
