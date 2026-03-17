function truncateInput(text, maxChars) {
  if (text.length <= maxChars) {
    return { text, truncated: false };
  }

  return {
    text: `${text.slice(0, maxChars).trimEnd()}\n\n[Mensaje recortado por el bridge para mantener el prompt estable.]`,
    truncated: true,
  };
}

export function buildCodexPrompt(config, inbound) {
  const preparedInput = truncateInput(inbound.commandText, config.maxPromptChars);
  const sender = inbound.senderE164 || inbound.rawFrom || "desconocido";

  return {
    prompt: [
      "Trabaja sobre el repo local indicado y responde para WhatsApp.",
      `Repo raiz: ${config.repoPath}`,
      `Remitente autorizado: ${sender}`,
      "",
      "Reglas de respuesta:",
      "- Responde en espanol claro y directo.",
      "- No modifiques archivos.",
      "- No ejecutes comandos destructivos.",
      "- Si necesitas inspeccionar el repo, hazlo en modo solo lectura.",
      "- No uses tablas Markdown.",
      "- Si no puedes verificar algo, dilo de forma explicita.",
      "- Devuelve solo la respuesta final; no expliques tu proceso.",
      "",
      "Pedido recibido por WhatsApp:",
      preparedInput.text,
    ].join("\n"),
    promptTruncated: preparedInput.truncated,
  };
}
