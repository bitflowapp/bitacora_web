import fs from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";

async function pathExists(targetPath) {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function resolveCodexScriptPath(config) {
  if (config.codexScriptPath) {
    if (await pathExists(config.codexScriptPath)) {
      return config.codexScriptPath;
    }
    throw new Error(`Configured Codex script was not found: ${config.codexScriptPath}`);
  }

  const searchNames = ["codex.cmd", "codex", "codex.ps1"];
  const pathEntries = String(process.env.PATH || "")
    .split(path.delimiter)
    .map((entry) => entry.trim())
    .filter(Boolean);

  for (const entry of pathEntries) {
    for (const searchName of searchNames) {
      const wrapperPath = path.join(entry, searchName);
      if (!(await pathExists(wrapperPath))) {
        continue;
      }

      const candidate = path.join(entry, "node_modules", "@openai", "codex", "bin", "codex.js");
      if (await pathExists(candidate)) {
        return candidate;
      }
    }
  }

  throw new Error("Could not resolve Codex CLI script from PATH");
}

function appendLimited(chunks, nextChunk, maxLength) {
  if (!nextChunk) {
    return;
  }

  chunks.push(nextChunk);
  const merged = chunks.join("");
  if (merged.length > maxLength) {
    const trimmed = merged.slice(merged.length - maxLength);
    chunks.length = 0;
    chunks.push(trimmed);
  }
}

async function runSingleAttempt({ config, prompt, outputPath, extraArgs }) {
  const stdoutChunks = [];
  const stderrChunks = [];
  const codexScriptPath = await resolveCodexScriptPath(config);

  const args = [
    codexScriptPath,
    ...extraArgs,
    "exec",
    "-C",
    config.repoPath,
    "-s",
    "read-only",
    "--color",
    "never",
    "--skip-git-repo-check",
    "-o",
    outputPath,
    "-",
  ];

  return await new Promise((resolve, reject) => {
    const child = spawn(process.execPath, args, {
      cwd: config.repoPath,
      env: {
        ...process.env,
        CODEX_HOME: config.codexHome,
        FORCE_COLOR: "0",
        NO_COLOR: "1",
      },
      stdio: ["pipe", "pipe", "pipe"],
      windowsHide: true,
    });

    const timeout = setTimeout(() => {
      child.kill("SIGKILL");
      const timeoutError = new Error(`Codex timed out after ${config.timeoutMs}ms`);
      timeoutError.name = "TimeoutError";
      reject(timeoutError);
    }, config.timeoutMs);

    child.stdout.on("data", (chunk) => {
      appendLimited(stdoutChunks, String(chunk), 24000);
    });

    child.stderr.on("data", (chunk) => {
      appendLimited(stderrChunks, String(chunk), 24000);
    });

    child.on("error", (error) => {
      clearTimeout(timeout);
      reject(error);
    });

    child.on("close", async (code) => {
      clearTimeout(timeout);

      let outputText = "";
      if (await pathExists(outputPath)) {
        outputText = await fs.readFile(outputPath, "utf8");
      }

      resolve({
        exitCode: code ?? -1,
        stdout: stdoutChunks.join(""),
        stderr: stderrChunks.join(""),
        outputText,
      });
    });

    child.stdin.end(prompt);
  });
}

export async function runCodexPrompt(config, prompt, correlationId) {
  await fs.mkdir(config.runDir, { recursive: true });

  const authJsonPath = path.join(config.codexHome, "auth.json");
  if (!(await pathExists(config.codexHome))) {
    throw new Error(`CODEX_HOME does not exist: ${config.codexHome}`);
  }
  if (!(await pathExists(authJsonPath))) {
    throw new Error(`Expected auth.json was not found: ${authJsonPath}`);
  }

  const outputPath = path.join(config.runDir, `${Date.now()}-${correlationId}-last.txt`);

  const attempts = [
    ["-a", "never"],
    [],
  ];

  let lastError = null;
  for (const extraArgs of attempts) {
    try {
      const result = await runSingleAttempt({
        config,
        prompt,
        outputPath,
        extraArgs,
      });

      if (result.exitCode === 0 && result.outputText.trim()) {
        return {
          ...result,
          outputPath,
          usedArgs: extraArgs,
        };
      }

      const combinedError = `${result.stderr}\n${result.stdout}`.trim();
      const approvalFlagRejected =
        extraArgs.length > 0 &&
        /unexpected argument '-a'|unknown option|unexpected option/i.test(combinedError);

      if (approvalFlagRejected) {
        lastError = new Error(combinedError || "Codex rejected the approval flag");
        continue;
      }

      if (result.outputText.trim()) {
        return {
          ...result,
          outputPath,
          usedArgs: extraArgs,
        };
      }

      throw new Error(
        combinedError || `Codex exited with code ${result.exitCode} and no final message`,
      );
    } catch (error) {
      lastError = error;
      if (error?.name === "TimeoutError") {
        throw error;
      }
    }
  }

  throw lastError ?? new Error("Codex execution failed");
}
