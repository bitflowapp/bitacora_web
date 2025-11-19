// src/index.ts
import express, { Request, Response } from 'express';
import cors from 'cors';
import { Resend } from 'resend';
import dotenv from 'dotenv';

// Carga .env y PISA cualquier variable previa (User/Machine)
dotenv.config({
  path: '.env',
  override: true,
});

const RESEND_API_KEY = process.env.RESEND_API_KEY ?? '';
const PORT = Number(process.env.PORT ?? 4000);
const FROM_EMAIL = 'Bitacora <onboarding@resend.dev>';

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

console.log(
  `[BOOT] key prefix = ${RESEND_API_KEY.slice(0, 10)} len = ${RESEND_API_KEY.length}`,
);

const resend = new Resend(RESEND_API_KEY);

// Tipos
type SendXlsxBody = {
  to: string;
  subject?: string;
  text?: string;
  html?: string;
  fileName: string;
  fileBase64: string; // base64 puro
};

// Health
app.get('/health', (_req, res) => res.json({ ok: true }));

// Env visible
app.get('/whoami', (_req, res) => {
  res.json({
    hasKey: RESEND_API_KEY.length > 0,
    prefix: RESEND_API_KEY.slice(0, 10),
    len: RESEND_API_KEY.length,
    node: process.version,
  });
});

// Test SDK sin adjuntos
app.post('/self-test', async (req: Request, res: Response) => {
  try {
    const to =
      (req.body?.to as string) || 'marcoantoniolunavillegas@gmail.com';

    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: [to],
      subject: 'Self-test SDK',
      text: 'OK',
    });

    if (error) {
      return res
        .status(500)
        .json({ error: (error as any).message ?? 'error' });
    }

    res.json({ ok: true, id: (data as any)?.id });
  } catch (e: any) {
    res.status(500).json({ error: e?.message ?? 'exception' });
  }
});

// Test RAW directo
app.post('/raw-test', async (req: Request, res: Response) => {
  try {
    const to =
      (req.body?.to as string) || 'marcoantoniolunavillegas@gmail.com';

    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'onboarding@resend.dev',
        to,
        subject: 'Raw-test',
        html: '<p>OK RAW</p>',
      }),
    });

    const j = await r.json();
    if (!r.ok) return res.status(r.status).json(j);
    res.json(j);
  } catch (e: any) {
    res.status(500).json({ error: e?.message ?? 'exception' });
  }
});

// Envío con adjunto base64
app.post('/send-xlsx', async (req: Request, res: Response) => {
  const body = req.body as Partial<SendXlsxBody>;

  if (!RESEND_API_KEY) {
    return res.status(500).json({ error: 'Falta RESEND_API_KEY' });
  }

  if (!body.to || !body.fileName || !body.fileBase64) {
    return res
      .status(400)
      .json({ error: 'Faltan: to, fileName, fileBase64' });
  }

  try {
    const fileBuffer = Buffer.from(body.fileBase64, 'base64');

    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: [body.to],
      subject: body.subject ?? 'Planilla de Bitácora',
      text: body.text ?? 'Adjunto XLSX generado desde Bitácora.',
      html:
        body.html ??
        '<p>Adjunto XLSX generado desde <strong>Bitácora</strong>.</p>',
      attachments: [{ filename: body.fileName, content: fileBuffer }],
    });

    if (error) {
      return res
        .status(500)
        .json({ error: (error as any).message ?? 'Error Resend' });
    }

    res.json({ ok: true, id: (data as any)?.id });
  } catch (e: any) {
    res
      .status(500)
      .json({ error: e?.message ?? 'Error interno enviando correo' });
  }
});

app.listen(PORT, () => {
  console.log(`Bitacora mailer escuchando en http://localhost:${PORT}`);
});
