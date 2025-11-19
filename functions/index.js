// functions/index.js
// Cloud Function HTTPS para enviar XLSX vía Resend.

const functions = require("firebase-functions/v1");
const {Resend} = require("resend");
require("dotenv").config();

const RESEND_API_KEY = process.env.RESEND_API_KEY || "";

if (!RESEND_API_KEY) {
  console.warn(
    "[sendXlsxMail] RESEND_API_KEY vacío; revisá .env en functions"
  );
}

/**
 * Devuelve una instancia de Resend sólo si hay API key.
 * Si no hay key, devuelve null para que el handler responda 500
 * pero sin explotar en el require del módulo.
 */
let resendInstance = null;
function getResend() {
  if (!RESEND_API_KEY) {
    return null;
  }
  if (!resendInstance) {
    resendInstance = new Resend(RESEND_API_KEY);
  }
  return resendInstance;
}

/**
 * Body esperado:
 * {
 *   to: string,
 *   subject?: string,
 *   text?: string,
 *   html?: string,
 *   fileName: string,
 *   fileBase64?: string,
 *   xlsxBase64?: string
 * }
 */
exports.sendXlsxMail = functions
  .region("southamerica-east1")
  .https.onRequest(async (req, res) => {
    // CORS siempre
    res.set("Access-Control-Allow-Origin", "*");

    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({error: "Sólo POST"});
      return;
    }

    const resend = getResend();
    if (!resend) {
      console.error(
        "[sendXlsxMail] Llamada sin RESEND_API_KEY configurada"
      );
      res.status(500).json({
        error: "Backend sin RESEND_API_KEY (revisá .env en functions)",
      });
      return;
    }

    const body = req.body || {};
    const to = (body.to || "").trim();
    const fileName = (body.fileName || "").trim();
    const b64 = body.fileBase64 || body.xlsxBase64;

    if (!to || !to.includes("@")) {
      res.status(400).json({error: "Campo 'to' inválido"});
      return;
    }
    if (!fileName || !b64) {
      res.status(400).json({
        error: "Faltan fileName o fileBase64/xlsxBase64",
      });
      return;
    }

    let buffer;
    try {
      buffer = Buffer.from(b64, "base64");
    } catch (e) {
      console.error("[sendXlsxMail] Base64 inválido", e);
      res.status(400).json({error: "fileBase64 inválido"});
      return;
    }

    const subject =
      (body.subject && String(body.subject).trim()) ||
      "Reporte Gridnote";
    const text =
      (body.text && String(body.text)) ||
      "Adjunto XLSX generado desde Gridnote.";
    const html =
      body.html ||
      "<p>Adjunto XLSX generado desde <strong>Gridnote</strong>.</p>";

    try {
      const {data, error} = await resend.emails.send({
        from: "Bitacora <onboarding@resend.dev>",
        to: [to],
        subject,
        text,
        html,
        attachments: [
          {
            filename: fileName,
            content: buffer,
          },
        ],
      });

      if (error) {
        console.error("[sendXlsxMail] Error Resend", error);
        res.status(500).json({
          error: (error && error.message) || "Error Resend",
        });
        return;
      }

      res.json({ok: true, id: data && data.id});
    } catch (e) {
      console.error("[sendXlsxMail] Excepción", e);
      res.status(500).json({
        error: (e && e.message) || "Error interno enviando correo",
      });
    }
  });



