import path from "node:path";
import { fileURLToPath } from "node:url";
import { handleWhatsAppCodexBridgeMessage } from "./index.mjs";
import { getBridgeConfig } from "./config.mjs";

function chunkTextWithMode(text, limit) {
  const chunks = [];
  let remaining = String(text ?? "").trim();

  while (remaining.length > limit) {
    let boundary = remaining.lastIndexOf("\n\n", limit);
    if (boundary < Math.floor(limit * 0.5)) {
      boundary = remaining.lastIndexOf("\n", limit);
    }
    if (boundary < Math.floor(limit * 0.5)) {
      boundary = limit;
    }

    chunks.push(remaining.slice(0, boundary).trim());
    remaining = remaining.slice(boundary).trim();
  }

  if (remaining) {
    chunks.push(remaining);
  }

  return chunks;
}

const moduleDir = path.dirname(fileURLToPath(import.meta.url));
process.env.WP_CODEX_BRIDGE_CODEX_SCRIPT = path.join(moduleDir, "fake-codex.mjs");

const sent = [];
const api = {
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
        chunkText: chunkTextWithMode,
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

const config = getBridgeConfig();
const result = await handleWhatsAppCodexBridgeMessage({
  api,
  event: {
    from: "+5492996209136",
    content: "bitflow: decime en una linea para que sirve este repo",
    metadata: {
      messageId: "smoke-bridge-001",
      senderE164: "+5492996209136",
    },
  },
  ctx: {
    channelId: "whatsapp",
    accountId: "default",
    conversationId: "+5492996209136",
  },
  config,
});

process.stdout.write(
  `${JSON.stringify(
    {
      handled: result.handled,
      reason: result.reason ?? null,
      responseText: result.responseText,
      sent,
    },
    null,
    2,
  )}\n`,
);
