import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import qrcode from 'qrcode-terminal';
import OpenAI from 'openai';
import Anthropic from '@anthropic-ai/sdk';
import pkg from 'whatsapp-web.js';
import {
  appendSafeLog,
  createConfig,
  getBasicCommandResponse,
  isAuthorizedChat,
  isGroupChatId,
  maskPhone,
} from './clawbot_core.mjs';

const { Client, LocalAuth } = pkg;
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');

dotenv.config({ path: path.join(repoRoot, '.env.clawbot.local'), override: false });
dotenv.config({ path: path.join(repoRoot, '.env'), override: false });

const config = createConfig(process.env);
const sessionPath = process.env.CLAWBOT_SESSION_PATH
  ? path.resolve(repoRoot, process.env.CLAWBOT_SESSION_PATH)
  : path.join(repoRoot, '.clawbot-whatsapp-session');

function logSafe(message) {
  console.log(message);
  appendSafeLog(repoRoot, message);
}

async function getAiResponse(text) {
  const provider = config.modelProvider;
  const prompt = [
    'Sos Clawbot, asistente local de Marco Luna para Bit Flow.',
    'Respondé breve, útil y en español.',
    'No ejecutes comandos del sistema.',
    'No pidas ni expongas tokens, credenciales ni datos sensibles.',
    'No prometas acciones sobre archivos o terceros desde WhatsApp.',
    '',
    `Mensaje: ${text}`,
  ].join('\n');

  if (provider === 'openai') {
    if (!process.env.OPENAI_API_KEY) return null;
    const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    const response = await openai.chat.completions.create({
      model: config.modelName || 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.2,
    });
    return response.choices?.[0]?.message?.content?.trim() || null;
  }

  if (provider === 'anthropic') {
    if (!process.env.ANTHROPIC_API_KEY) return null;
    const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
    const response = await anthropic.messages.create({
      model: config.modelName || 'claude-3-5-haiku-latest',
      max_tokens: 500,
      temperature: 0.2,
      messages: [{ role: 'user', content: prompt }],
    });
    return response.content
      ?.filter((part) => part.type === 'text')
      .map((part) => part.text)
      .join('\n')
      .trim() || null;
  }

  return null;
}

if (!config.hasAllowlist) {
  logSafe('SAFE MODE: CLAWBOT_ALLOWED_PHONES is missing. Bot will not respond to anyone.');
}

logSafe(`Clawbot WhatsApp starting. Provider=${config.modelProvider}; dryRun=${config.dryRun}; allowGroups=${config.allowGroups}`);
logSafe(`Allowlist configured for ${config.allowedPhones.length} phone(s). Owner=${maskPhone(config.ownerPhone)}`);

const client = new Client({
  authStrategy: new LocalAuth({
    clientId: 'clawbot',
    dataPath: sessionPath,
  }),
  puppeteer: {
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  },
});

client.on('qr', (qr) => {
  logSafe('WhatsApp QR generated on console. Ready to scan.');
  console.log('\nEscaneá este QR con WhatsApp > Dispositivos vinculados > Vincular dispositivo:\n');
  qrcode.generate(qr, { small: true });
  console.log('\nEl QR no se guarda en logs.\n');
});

client.on('ready', () => {
  logSafe('Clawbot WhatsApp ready. Send "ping" from an allowed phone.');
});

client.on('authenticated', () => {
  logSafe('WhatsApp session authenticated.');
});

client.on('auth_failure', (message) => {
  logSafe(`WhatsApp auth failure: ${String(message).slice(0, 120)}`);
});

client.on('disconnected', (reason) => {
  logSafe(`WhatsApp disconnected: ${String(reason).slice(0, 120)}`);
});

client.on('message', async (message) => {
  try {
    const from = message.from;
    const isGroup = isGroupChatId(from);
    const auth = isAuthorizedChat({ from, author: message.author, isGroup }, config);

    if (!auth.allowed) {
      logSafe(`ignored unauthorized chat: reason=${auth.reason}; chat=${maskPhone(from)}`);
      return;
    }

    const text = String(message.body ?? '').trim();
    const commandResponse = getBasicCommandResponse(text, config);
    const response = commandResponse || (await getAiResponse(text));

    if (!response) {
      logSafe(`ignored allowed chat without command/AI response: chat=${maskPhone(from)}`);
      return;
    }

    if (config.dryRun) {
      logSafe(`dry-run response skipped: chat=${maskPhone(from)}`);
      return;
    }

    await message.reply(response);
    logSafe(`sent response: chat=${maskPhone(from)}; command=${commandResponse ? 'basic' : 'ai'}`);
  } catch (error) {
    logSafe(`message handling error: ${error?.message ?? error}`);
  }
});

client.initialize();
