import fs from 'node:fs';
import path from 'node:path';

export const DEFAULT_DEMO_URL =
  'https://bitflowapp.github.io/bitacora_web/?hard=20260311T194947Z-720ab27';

export function normalizePhone(value) {
  const digits = String(value ?? '').replace(/\D/g, '');
  if (!digits) return '';

  let normalized = digits;
  if (normalized.startsWith('00')) {
    normalized = normalized.slice(2);
  }

  if (normalized.startsWith('549')) return normalized;
  if (normalized.startsWith('54') && normalized.length >= 12) {
    return `549${normalized.slice(2).replace(/^9/, '')}`;
  }
  if (normalized.startsWith('9') && normalized.length === 11) {
    return `54${normalized}`;
  }
  if (normalized.length === 10) {
    return `549${normalized}`;
  }

  return normalized;
}

export function maskPhone(value) {
  const digits = normalizePhone(value);
  if (!digits) return 'unknown';
  if (digits.length <= 4) return '****';
  return `${'*'.repeat(Math.max(0, digits.length - 4))}${digits.slice(-4)}`;
}

export function parseBoolean(value, fallback = false) {
  if (value == null || value === '') return fallback;
  return ['1', 'true', 'yes', 'y', 'on', 'si', 'sí'].includes(
    String(value).trim().toLowerCase(),
  );
}

export function parseAllowedPhones(raw) {
  return String(raw ?? '')
    .split(/[,\s;]+/)
    .map(normalizePhone)
    .filter(Boolean);
}

export function createConfig(env = process.env) {
  const allowedPhones = parseAllowedPhones(env.CLAWBOT_ALLOWED_PHONES);
  const ownerPhone = normalizePhone(env.CLAWBOT_OWNER_PHONE);
  const allowGroups = parseBoolean(env.CLAWBOT_ALLOW_GROUPS, false);
  const requirePrefix = parseBoolean(env.CLAWBOT_REQUIRE_PREFIX, false);
  const commandPrefix = String(env.CLAWBOT_COMMAND_PREFIX ?? '').trim();
  const dryRun = parseBoolean(env.CLAWBOT_DRY_RUN, false);
  const modelProvider = String(env.CLAWBOT_MODEL_PROVIDER ?? 'none').trim().toLowerCase();
  const modelName = String(env.CLAWBOT_MODEL_NAME ?? 'local-commands').trim();
  const demoUrl = String(env.BITFLOW_DEMO_URL ?? DEFAULT_DEMO_URL).trim();

  return {
    ownerPhone,
    allowedPhones,
    allowGroups,
    requirePrefix,
    commandPrefix,
    dryRun,
    modelProvider,
    modelName,
    demoUrl,
    hasAllowlist: allowedPhones.length > 0,
  };
}

export function extractPhoneFromWhatsAppId(id) {
  const raw = String(id ?? '').split('@')[0];
  return normalizePhone(raw);
}

export function isGroupChatId(id) {
  return String(id ?? '').endsWith('@g.us');
}

export function isAuthorizedChat({ from, author, isGroup }, config) {
  if (isGroup && !config.allowGroups) {
    return { allowed: false, reason: 'group blocked' };
  }

  if (!config.hasAllowlist) {
    return { allowed: false, reason: 'allowlist missing' };
  }

  const candidates = [from, author]
    .map(extractPhoneFromWhatsAppId)
    .filter(Boolean);
  const allowed = new Set(config.allowedPhones.map(normalizePhone));

  if (candidates.some((candidate) => allowed.has(candidate))) {
    return { allowed: true, reason: 'allowed' };
  }

  return { allowed: false, reason: 'unauthorized chat' };
}

export function stripCommandPrefix(text, config) {
  const value = String(text ?? '').trim();
  if (!config.requirePrefix) return value;
  if (!config.commandPrefix) return '';
  if (!value.startsWith(config.commandPrefix)) return '';
  return value.slice(config.commandPrefix.length).trim();
}

export function getBasicCommandResponse(text, config) {
  const command = stripCommandPrefix(text, config).trim().toLowerCase();
  if (!command) return null;

  switch (command) {
    case 'ping':
      return 'pong';
    case 'estado':
      return 'Clawbot activo. Bit Flow listo para asistencia.';
    case 'bitflow':
      return 'Bit Flow es una herramienta para relevamientos técnicos con datos, GPS, fotos/evidencias y exportación PDF/Excel/paquete.';
    case 'demo':
      return `Demo web: ${config.demoUrl}`;
    case 'tareas':
      return 'Tareas disponibles: ayuda, estado, ping, bitflow, demo y parar.';
    case 'parar':
      return 'Modo pausa solicitado. Para detener el bot, cerrá la consola o ejecutá el script stop si existe.';
    case 'ayuda':
      return [
        'Comandos disponibles:',
        'ayuda - muestra este menú',
        'estado - estado del bot',
        'ping - prueba rápida',
        'bitflow - descripción breve',
        'demo - link de demo web',
        'tareas - lista de tareas disponibles',
        'parar - instrucciones para detener',
      ].join('\n');
    default:
      return null;
  }
}

export function isBasicCommand(text, config) {
  return getBasicCommandResponse(text, config) != null;
}

export function appendSafeLog(repoRoot, line) {
  const logDir = path.join(repoRoot, 'logs');
  fs.mkdirSync(logDir, { recursive: true });
  const stamp = new Date().toISOString();
  fs.appendFileSync(
    path.join(logDir, 'clawbot-whatsapp.log'),
    `[${stamp}] ${line}\n`,
    'utf8',
  );
}
