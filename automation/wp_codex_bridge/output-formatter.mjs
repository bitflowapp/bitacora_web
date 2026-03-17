function stripAnsi(value) {
  return String(value ?? "").replace(
    // eslint-disable-next-line no-control-regex
    /\u001b\[[0-9;?]*[ -/]*[@-~]/g,
    "",
  );
}

function normalizeOutput(value) {
  return stripAnsi(value)
    .replace(/\u0000/g, "")
    .replace(/\r\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function truncateResponse(text, maxChars) {
  if (text.length <= maxChars) {
    return { text, truncated: false };
  }

  const clipped = text.slice(0, maxChars);
  const safeBreak = Math.max(
    clipped.lastIndexOf("\n\n"),
    clipped.lastIndexOf("\n"),
    clipped.lastIndexOf(". "),
  );
  const boundary = safeBreak > Math.floor(maxChars * 0.6) ? safeBreak : maxChars;

  return {
    text: `${clipped.slice(0, boundary).trimEnd()}\n\n[Respuesta recortada. Si queres, pedi que siga.]`,
    truncated: true,
  };
}

export function formatCodexOutput(rawOutput, config) {
  const normalized = normalizeOutput(rawOutput);
  if (!normalized) {
    return {
      text: "Codex no devolvio una respuesta util.",
      truncated: false,
    };
  }

  return truncateResponse(normalized, config.maxResponseChars);
}

export function fallbackChunkText(text, limit) {
  const cleaned = normalizeOutput(text);
  if (!cleaned) {
    return [];
  }

  if (cleaned.length <= limit) {
    return [cleaned];
  }

  const paragraphs = cleaned.split(/\n\s*\n/);
  const chunks = [];
  let current = "";

  for (const paragraph of paragraphs) {
    const candidate = current ? `${current}\n\n${paragraph}` : paragraph;
    if (candidate.length <= limit) {
      current = candidate;
      continue;
    }

    if (current) {
      chunks.push(current);
      current = "";
    }

    if (paragraph.length <= limit) {
      current = paragraph;
      continue;
    }

    let remaining = paragraph;
    while (remaining.length > limit) {
      chunks.push(remaining.slice(0, limit).trim());
      remaining = remaining.slice(limit).trim();
    }
    current = remaining;
  }

  if (current) {
    chunks.push(current);
  }

  return chunks;
}
