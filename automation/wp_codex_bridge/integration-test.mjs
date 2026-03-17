import { getBridgeConfig } from "./config.mjs";
import { registerWhatsAppCodexBridge } from "./index.mjs";

function chunkTextWithMode(text, limit) {
  const chunks = [];
  let remaining = String(text ?? "").trim();

  while (remaining.length > limit) {
    chunks.push(remaining.slice(0, limit));
    remaining = remaining.slice(limit).trim();
  }

  if (remaining) {
    chunks.push(remaining);
  }

  return chunks;
}

const inputText =
  process.argv[2] ||
  "bitflow: responde exactamente INTEGRATION_JARIEL_OK_20260317 y nada mas";
const sender = process.argv[3] || "+5492996209136";

const handlers = new Map();
const sent = [];

const api = {
  on(eventName, handler) {
    if (!handlers.has(eventName)) {
      handlers.set(eventName, []);
    }
    handlers.get(eventName).push(handler);
  },
  logger: {
    info(message) {
      process.stdout.write(`[info] ${message}\n`);
    },
    warn(message) {
      process.stdout.write(`[warn] ${message}\n`);
    },
    error(message) {
      process.stdout.write(`[error] ${message}\n`);
    },
    debug(message) {
      process.stdout.write(`[debug] ${message}\n`);
    },
  },
  runtime: {
    channel: {
      text: {
        chunkTextWithMode,
      },
      whatsapp: {
        async sendMessageWhatsApp(to, text, options) {
          sent.push({ to, text, options });
          return {
            messageId: `stub-${sent.length}`,
            toJid: to,
          };
        },
      },
    },
  },
};

registerWhatsAppCodexBridge(api);

for (const handler of handlers.get("gateway_start") ?? []) {
  await handler({ port: 18789 });
}

const inboundEvent = {
  from: sender,
  content: inputText,
  metadata: {
    messageId: "integration-hook-001",
    senderE164: sender,
  },
};
const inboundCtx = {
  channelId: "whatsapp",
  accountId: "default",
  conversationId: sender,
};

for (const handler of handlers.get("message_received") ?? []) {
  await handler(inboundEvent, inboundCtx);
}

let cancelResult = null;
for (const handler of handlers.get("message_sending") ?? []) {
  const result = await handler({ to: sender, content: "native auto-reply probe" }, inboundCtx);
  if (result) {
    cancelResult = result;
  }
}

console.log(
  JSON.stringify(
    {
      codexHome: getBridgeConfig().codexHome,
      registeredHooks: Object.fromEntries(
        Array.from(handlers.entries(), ([key, value]) => [key, value.length]),
      ),
      sendCount: sent.length,
      lastSend: sent.at(-1) ?? null,
      cancelResult,
    },
    null,
    2,
  ),
);
