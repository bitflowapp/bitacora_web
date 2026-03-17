import { createHash } from "node:crypto";

function sanitizeText(value) {
  return String(value ?? "")
    .replace(/\u0000/g, "")
    .replace(/\r\n/g, "\n")
    .trim();
}

export function normalizeE164(value) {
  const digits = String(value ?? "")
    .replace(/^whatsapp:/i, "")
    .trim()
    .replace(/[^\d+]/g, "");

  if (!digits) {
    return "";
  }

  return digits.startsWith("+") ? `+${digits.slice(1)}` : `+${digits}`;
}

export function isWhatsAppGroupId(value) {
  return /@g\.us$/i.test(String(value ?? "").trim());
}

function detectPrefix(text, prefixes) {
  const trimmed = text.trimStart();
  const lower = trimmed.toLowerCase();

  for (const prefix of prefixes) {
    if (lower.startsWith(prefix)) {
      return {
        prefix,
        commandText: trimmed.slice(prefix.length).trim(),
        rawText: trimmed,
      };
    }
  }

  return null;
}

function deriveMessageId(event, ctx, content) {
  const metadataMessageId =
    typeof event?.metadata?.messageId === "string" ? event.metadata.messageId.trim() : "";

  if (metadataMessageId) {
    return metadataMessageId;
  }

  const seed = JSON.stringify({
    from: event?.from ?? "",
    conversationId: ctx?.conversationId ?? "",
    accountId: ctx?.accountId ?? "",
    timestamp: event?.timestamp ?? "",
    content,
  });

  return createHash("sha256").update(seed).digest("hex").slice(0, 16);
}

export function parseWhatsAppInbound(event, ctx, config) {
  const content = sanitizeText(event?.content);
  if (!content) {
    return null;
  }

  const prefixMatch = detectPrefix(content, config.prefixes);
  if (!prefixMatch) {
    return null;
  }

  const rawFrom = sanitizeText(event?.from);
  const conversationId = sanitizeText(ctx?.conversationId);
  const accountId = sanitizeText(ctx?.accountId);
  const senderE164FromMetadata =
    typeof event?.metadata?.senderE164 === "string" ? normalizeE164(event.metadata.senderE164) : "";
  const isGroup = isWhatsAppGroupId(rawFrom) || isWhatsAppGroupId(conversationId);
  const normalizedFrom = rawFrom ? normalizeE164(rawFrom) : "";
  const senderE164 = senderE164FromMetadata || (!isGroup ? normalizedFrom : "");
  const replyTarget = senderE164 || normalizedFrom;

  return {
    messageId: deriveMessageId(event, ctx, content),
    rawText: prefixMatch.rawText,
    commandPrefix: prefixMatch.prefix,
    commandText: prefixMatch.commandText,
    rawFrom,
    conversationId,
    accountId: accountId || undefined,
    isGroup,
    senderE164: senderE164 || undefined,
    replyTarget: replyTarget || undefined,
    timestamp: typeof event?.timestamp === "number" ? event.timestamp : undefined,
  };
}

export function isAllowedSender(inbound, config) {
  const sender = inbound.senderE164 || inbound.replyTarget || "";
  if (!sender) {
    return false;
  }

  return config.allowlist.includes(normalizeE164(sender));
}

export async function sendWhatsAppChunks(runtime, inbound, chunks) {
  if (!runtime || typeof runtime.sendText !== "function") {
    throw new Error("WhatsApp send runtime is not available");
  }

  if (!inbound.replyTarget) {
    throw new Error("Inbound reply target is missing");
  }

  for (let index = 0; index < chunks.length; index += 1) {
    const chunk = chunks[index];
    const message =
      chunks.length > 1 ? `[${index + 1}/${chunks.length}]\n${chunk}` : chunk;
    await runtime.sendText(inbound.replyTarget, message, inbound.accountId);
  }
}
