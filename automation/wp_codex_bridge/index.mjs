import { getBridgeConfig } from "./config.mjs";
import { createBridgeLogger } from "./logger.mjs";
import { buildCodexPrompt } from "./prompt-builder.mjs";
import { runCodexPrompt } from "./codex-runner.mjs";
import { fallbackChunkText, formatCodexOutput } from "./output-formatter.mjs";
import {
  isAllowedSender,
  normalizeE164,
  parseWhatsAppInbound,
  sendWhatsAppChunks,
} from "./whatsapp-adapter.mjs";

function cleanupDedupeCache(state, ttlMs) {
  const threshold = Date.now() - ttlMs;
  for (const [key, timestamp] of state.recentMessageIds.entries()) {
    if (timestamp < threshold) {
      state.recentMessageIds.delete(key);
    }
  }
}

function cleanupNativeSendSuppressions(state, ttlMs) {
  const now = Date.now();
  for (const [key, entry] of state.nativeSendSuppressions.entries()) {
    if (entry.expiresAt < now || now - entry.armedAt > ttlMs || entry.remainingCancels <= 0) {
      state.nativeSendSuppressions.delete(key);
    }
  }
}

function buildNativeSuppressionKey(target, accountId) {
  const normalizedTarget = normalizeE164(target);
  const normalizedAccountId = String(accountId ?? "").trim() || "default";
  return normalizedTarget ? `${normalizedTarget}|${normalizedAccountId}` : "";
}

function armNativeAutoReplySuppression(state, inbound, config) {
  const key = buildNativeSuppressionKey(inbound.replyTarget, inbound.accountId);
  if (!key) {
    return;
  }

  const now = Date.now();
  state.nativeSendSuppressions.set(key, {
    armedAt: now,
    expiresAt: now + Math.max(config.timeoutMs, 90_000),
    remainingCancels: 8,
    messageId: inbound.messageId,
    target: inbound.replyTarget,
  });
}

async function maybeCancelNativeAutoReplySend({
  event,
  ctx,
  logger,
  state,
}) {
  if (ctx?.channelId !== "whatsapp") {
    return;
  }

  cleanupNativeSendSuppressions(state, 60_000);
  const key = buildNativeSuppressionKey(event?.to, ctx?.accountId);
  if (!key) {
    return;
  }

  const suppression = state.nativeSendSuppressions.get(key);
  if (!suppression) {
    return;
  }

  suppression.remainingCancels -= 1;
  if (suppression.remainingCancels <= 0) {
    state.nativeSendSuppressions.delete(key);
  } else {
    state.nativeSendSuppressions.set(key, suppression);
  }

  await logger.info("native whatsapp auto-reply cancelled", {
    target: suppression.target,
    messageId: suppression.messageId,
    remainingCancels: Math.max(suppression.remainingCancels, 0),
    preview: String(event?.content ?? "").slice(0, 160),
  });

  return { cancel: true };
}

function createRuntimeBridge(api) {
  return {
    chunkText(text, limit) {
      const chunkWithMode = api?.runtime?.channel?.text?.chunkTextWithMode;
      if (typeof chunkWithMode === "function") {
        return chunkWithMode(text, limit, "newline");
      }

      const chunk = api?.runtime?.channel?.text?.chunkText;
      if (typeof chunk === "function") {
        return chunk(text, limit);
      }

      return fallbackChunkText(text, limit);
    },
    async sendText(to, text, accountId) {
      const send = api?.runtime?.channel?.whatsapp?.sendMessageWhatsApp;
      if (typeof send !== "function") {
        throw new Error("WhatsApp runtime sendMessageWhatsApp is unavailable");
      }

      return await send(to, text, {
        verbose: false,
        accountId: accountId || undefined,
      });
    },
  };
}

export function createBridgeState() {
  return {
    recentMessageIds: new Map(),
    nativeSendSuppressions: new Map(),
  };
}

export async function handleWhatsAppCodexBridgeMessage({
  api,
  event,
  ctx,
  config = getBridgeConfig(),
  logger = createBridgeLogger(config, api?.logger),
  state = createBridgeState(),
}) {
  if (ctx?.channelId !== "whatsapp") {
    return { handled: false, reason: "not_whatsapp" };
  }

  const inbound = parseWhatsAppInbound(event, ctx, config);
  if (!inbound) {
    return { handled: false, reason: "no_prefix" };
  }

  cleanupDedupeCache(state, config.dedupeTtlMs);
  if (state.recentMessageIds.has(inbound.messageId)) {
    await logger.info("duplicate inbound skipped", {
      messageId: inbound.messageId,
      from: inbound.rawFrom,
    });
    return { handled: false, reason: "duplicate", inbound };
  }
  state.recentMessageIds.set(inbound.messageId, Date.now());

  if (inbound.isGroup) {
    await logger.info("group inbound ignored", {
      messageId: inbound.messageId,
      conversationId: inbound.conversationId,
    });
    return { handled: false, reason: "group_ignored", inbound };
  }

  if (!isAllowedSender(inbound, config)) {
    await logger.warn("non-allowlisted sender ignored", {
      messageId: inbound.messageId,
      sender: inbound.senderE164 || inbound.rawFrom,
    });
    return { handled: false, reason: "sender_not_allowed", inbound };
  }

  armNativeAutoReplySuppression(state, inbound, config);
  const runtime = createRuntimeBridge(api);

  if (!inbound.commandText) {
    const helpText = "Escribime algo despues de codex:, bitflow: o repo:.";
    const chunks = runtime.chunkText(helpText, config.outboundChunkChars);
    await sendWhatsAppChunks(runtime, inbound, chunks);
    await logger.info("empty command replied with help", {
      messageId: inbound.messageId,
      sender: inbound.senderE164 || inbound.rawFrom,
    });
    return {
      handled: true,
      inbound,
      responseText: helpText,
      chunks,
      reason: "empty_command_help",
    };
  }

  const promptInfo = buildCodexPrompt(config, inbound);
  await logger.info("codex request started", {
    messageId: inbound.messageId,
    sender: inbound.senderE164 || inbound.rawFrom,
    prefix: inbound.commandPrefix,
    promptChars: promptInfo.prompt.length,
    promptTruncated: promptInfo.promptTruncated,
  });

  try {
    const result = await runCodexPrompt(config, promptInfo.prompt, inbound.messageId);
    const formatted = formatCodexOutput(result.outputText, config);
    const chunks = runtime.chunkText(formatted.text, config.outboundChunkChars);
    await sendWhatsAppChunks(runtime, inbound, chunks);

    await logger.info("codex request completed", {
      messageId: inbound.messageId,
      sender: inbound.senderE164 || inbound.rawFrom,
      exitCode: result.exitCode,
      outputPath: result.outputPath,
      chunkCount: chunks.length,
      responseChars: formatted.text.length,
      responseTruncated: formatted.truncated,
      usedArgs: result.usedArgs.join(" "),
    });

    return {
      handled: true,
      inbound,
      responseText: formatted.text,
      chunks,
      result,
    };
  } catch (error) {
    const isTimeout = error?.name === "TimeoutError";
    const failureText = isTimeout
      ? "Codex tardo demasiado y corte la ejecucion. Proba con un pedido mas chico."
      : "Codex fallo al procesar el pedido. Reintenta en unos minutos.";
    const chunks = runtime.chunkText(failureText, config.outboundChunkChars);
    await sendWhatsAppChunks(runtime, inbound, chunks);

    await logger.error("codex request failed", {
      messageId: inbound.messageId,
      sender: inbound.senderE164 || inbound.rawFrom,
      error: String(error?.stack || error),
      timedOut: isTimeout,
    });

    return {
      handled: true,
      inbound,
      error: String(error?.message || error),
      chunks,
      responseText: failureText,
    };
  }
}

export function registerWhatsAppCodexBridge(api) {
  const config = getBridgeConfig();
  const logger = createBridgeLogger(config, api?.logger);
  const state = createBridgeState();

  api.on("gateway_start", async (event) => {
    await logger.info("bridge ready", {
      port: event?.port,
      repoPath: config.repoPath,
      codexHome: config.codexHome,
      allowlist: config.allowlist,
      prefixes: config.prefixes,
    });
  });

  api.on("message_received", async (event, ctx) => {
    await handleWhatsAppCodexBridgeMessage({
      api,
      event,
      ctx,
      config,
      logger,
      state,
    });
  });

  api.on("message_sending", async (event, ctx) => {
    return await maybeCancelNativeAutoReplySend({
      event,
      ctx,
      logger,
      state,
    });
  });
}
