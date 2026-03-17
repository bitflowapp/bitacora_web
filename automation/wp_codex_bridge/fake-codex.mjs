import fs from "node:fs/promises";
import path from "node:path";

const args = process.argv.slice(2);

function readArgValue(name, shortName) {
  const longIndex = args.indexOf(name);
  if (longIndex >= 0 && longIndex + 1 < args.length) {
    return args[longIndex + 1];
  }

  const shortIndex = shortName ? args.indexOf(shortName) : -1;
  if (shortIndex >= 0 && shortIndex + 1 < args.length) {
    return args[shortIndex + 1];
  }

  return "";
}

const outputPath = readArgValue("--output-last-message", "-o");
const stdin = await new Promise((resolve) => {
  let data = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => {
    data += chunk;
  });
  process.stdin.on("end", () => resolve(data));
});

const response = [
  "Stub Codex response.",
  "",
  `Prompt chars: ${stdin.length}`,
  `Prompt preview: ${stdin.trim().slice(0, 120)}`,
].join("\n");

if (!outputPath) {
  throw new Error("Missing output path");
}

await fs.mkdir(path.dirname(outputPath), { recursive: true });
await fs.writeFile(outputPath, response, "utf8");
process.stdout.write("stub-codex-ok\n");
