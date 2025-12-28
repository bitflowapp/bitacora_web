// auth.js — Login con Google Identity Services, sin backend.
// Guarda perfil en localStorage y expone API mínima a Flutter.

const STATE_KEY = "bitacora.user";

// ----- Utils -----
function getClientId() {
  const q = new URLSearchParams(location.search).get("gid");
  if (q && q.trim()) return q.trim();
  const meta = document.querySelector('meta[name="google-signin-client_id"]');
  return meta?.content?.trim() || "";
}

function decodeJwt(jwt) {
  const b64 = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
  const pad = "=".repeat((4 - (b64.length % 4)) % 4);
  const json = decodeURIComponent(
    atob(b64 + pad).split("").map(c => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2)).join("")
  );
  return JSON.parse(json);
}

function getUser() {
  try { return JSON.parse(localStorage.getItem(STATE_KEY) || "null"); }
  catch { return null; }
}
function setUser(u) { localStorage.setItem(STATE_KEY, JSON.stringify(u)); }
function clearUser() { localStorage.removeItem(STATE_KEY); }

// Espera a que cargue Google Identity (GSI) hasta 5s
function waitForGsi(maxMs = 5000) {
  return new Promise((resolve, reject) => {
    if (window.google?.accounts?.id) return resolve();
    const t0 = Date.now();
    const iv = setInterval(() => {
      if (window.google?.accounts?.id) { clearInterval(iv); resolve(); }
      else if (Date.now() - t0 > maxMs) { clearInterval(iv); reject(new Error("GSI load timeout")); }
    }, 50);
    window.addEventListener("load", () => {
      if (window.google?.accounts?.id) { clearInterval(iv); resolve(); }
    });
  });
}

// ----- UI states -----
function renderAuthed(user) {
  const gbtn = document.getElementById("g-btn");
  const status = document.getElementById("authStatus");
  gbtn.innerHTML = "";
  status.style.display = "flex";
  status.innerHTML = `
    <img class="avatar" src="${user.picture || ""}" alt="">
    <div class="user" style="margin-left:.5rem">
      ${user.name || ""}<br><small>${user.email || ""}</small>
    </div>
  `;
  const btn = document.createElement("button");
  btn.className = "btn";
  btn.type = "button";
  btn.textContent = "Salir";
  btn.addEventListener("click", logout);
  gbtn.appendChild(btn);

  window.dispatchEvent(new CustomEvent("auth:changed", { detail: user }));
  try { google.accounts.id.disableAutoSelect(); } catch {}
}

async function renderSignedOut() {
  const cid = getClientId();
  const gbtn = document.getElementById("g-btn");
  const status = document.getElementById("authStatus");
  status.style.display = "none";
  status.textContent = "";

  if (!cid) {
    gbtn.innerHTML = `<small>Configurar Google Client ID. Para test: <code>?gid=TU_CLIENT_ID</code></small>`;
    window.dispatchEvent(new CustomEvent("auth:changed", { detail: null }));
    return;
  }

  try {
    await waitForGsi();
    google.accounts.id.initialize({
      client_id: cid,
      callback: onCredential,
      auto_select: true,
      ux_mode: "popup",
      itp_support: true,`n      use_fedcm_for_prompt: true
    });
    google.accounts.id.renderButton(gbtn, {
      type: "standard",
      shape: "pill",
      theme: "outline",
      size: "large",
      text: "signin_with",
      logo_alignment: "left"
    });
    google.accounts.id.prompt();
  } catch {
    gbtn.innerHTML = `<small>No cargó Google Identity. Revisá bloqueadores/extensiones.</small>`;
  }

  window.dispatchEvent(new CustomEvent("auth:changed", { detail: null }));
}

// ----- Callbacks -----
function onCredential(resp) {
  const payload = decodeJwt(resp.credential);
  const user = {
    sub: payload.sub,
    name: payload.name,
    email: payload.email,
    picture: payload.picture
  };
  setUser(user);
  renderAuthed(user);
}

function logout() {
  const user = getUser();
  try {
    if (user?.email) google.accounts.id.revoke(user.email, () => {});
    else google.accounts.id.disableAutoSelect();
  } catch {}
  clearUser();
  renderSignedOut();
}

// Exponer API a Flutter / JS
function signIn() { try { google.accounts.id.prompt(); } catch {} }
window.BitacoraAuth = { getUser, logout, signIn };

// Inicialización
window.addEventListener("DOMContentLoaded", () => {
  const user = getUser();
  if (user) renderAuthed(user); else renderSignedOut();
});

