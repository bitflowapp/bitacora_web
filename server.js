// server.js  (Node + Express + Resend, CommonJS)
const express = require("express");
const cors = require("cors");
const { Resend } = require("resend");

// --- Config ---
const PORT = process.env.PORT || 8787;
const AUTH = process.env.MAIL_TOKEN || ""; // opcional: si se setea, exigir header x-auth
const FROM = process.env.MAIL_FROM || "onboarding@resend.dev";
const RESEND_KEY = process.env.RESEND_API_KEY || "";

const resend = new Resend(RESEND_KEY);
const app = express();

app.use(cors({ origin: true }));
app.use(express.json({ limit: "12mb" }));

// --- Auth simple por header x-auth (opcional) ---
app.use((req, res, next) => {
  if (AUTH && req.header("x-auth") !== AUTH) {
    return res.status(401).json({ ok: false, error: "unauthorized" });
  }
  next();
});

// --- Utils ---
function stripDataUrl(b64) {
  if (typeof b64 !== "string") return "";
  const i = b64.indexOf("base64,");
  return i >= 0 ? b64.slice(i + "base64,".length) : b64;
}

async function sendViaResend({ from, to, subject, text, attachments }) {
  const toList = Array.isArray(to) ? to : [to];
  const out = await resend.emails.send({
    from,
    to: toList,
    subject: subject || "(sin asunto)",
    text: text || "",
    attachments,
  });
  if (out?.error) {
    const err = out.error;
    throw new Error(`${err.name || "ResendError"}: ${err.message || "unknown"}`);
  }
  return out?.data?.id || null;
}

// --- Health + diagnóstico ---
app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "mailer",
    from: FROM,
    has_key: Boolean(RESEND_KEY),
    auth_enabled: Boolean(AUTH),
  });
});

// --- CORS preflight ---
app.options("/send-plain", (_req, res) => res.sendStatus(204));
app.options("/send-report", (_req, res) => res.sendStatus(204));

// --- Envío sin adjunto ---
app.post("/send-plain", async (req, res) => {
  try {
    const { to, subject, message } = req.body || {};
    if (!to) return res.status(400).json({ ok: false, error: "missing 'to'" });

    console.log("send-plain >", { to, from: FROM, subject });
    const id = await sendViaResend({
      from: FROM,
      to,
      subject: subject || "Gridnote",
      text: message || "",
      attachments: [],
    });
    return res.json({ ok: true, id });
  } catch (e) {
    console.error("Mailer error (plain):", e);
    return res.status(502).json({ ok: false, error: String(e) });
  }
});

// --- Envío con adjunto XLSX (base64) ---
app.post("/send-report", async (req, res) => {
  try {
    const { to, subject, message, fileName, xlsxBase64 } = req.body || {};
    if (!to || !fileName || !xlsxBase64) {
      return res.status(400).json({ ok: false, error: "missing fields" });
    }

    const b64 = stripDataUrl(xlsxBase64);
    console.log("send-report >", {
      to,
      from: FROM,
      fileName,
      b64len: b64.length,
    });

    const id = await sendViaResend({
      from: FROM,
      to,
      subject: subject || "Gridnote Reporte",
      text: message || "",
      attachments: [
        {
          filename: fileName,
          content: Buffer.from(b64, "base64"),
          contentType:
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        },
      ],
    });
    return res.json({ ok: true, id });
  } catch (e) {
    console.error("Mailer error (report):", e);
    return res.status(502).json({ ok: false, error: String(e) });
  }
});

// --- Start ---
app.listen(PORT, () => console.log(`Mailer en http://localhost:${PORT}`));
