import fs from "node:fs/promises";
import path from "node:path";

function serializeFields(fields) {
  if (!fields || Object.keys(fields).length === 0) {
    return "";
  }

  try {
    return ` ${JSON.stringify(fields)}`;
  } catch {
    return " [fields_unserializable]";
  }
}

export function createBridgeLogger(config, apiLogger = null) {
  const baseDir = config.logDir;

  async function write(level, message, fields = undefined) {
    const timestamp = new Date().toISOString();
    const line = JSON.stringify({
      ts: timestamp,
      level,
      message,
      ...(fields ?? {}),
    });
    const logPath = path.join(baseDir, `${timestamp.slice(0, 10)}.log`);

    await fs.mkdir(baseDir, { recursive: true });
    await fs.appendFile(logPath, `${line}\n`, "utf8");

    const sink =
      level === "debug"
        ? apiLogger?.debug ?? apiLogger?.info
        : level === "warn"
          ? apiLogger?.warn
          : level === "error"
            ? apiLogger?.error
            : apiLogger?.info;

    if (typeof sink === "function") {
      sink(`${config.bridgeName}: ${message}${serializeFields(fields)}`);
    }
  }

  return {
    debug(message, fields) {
      return write("debug", message, fields);
    },
    info(message, fields) {
      return write("info", message, fields);
    },
    warn(message, fields) {
      return write("warn", message, fields);
    },
    error(message, fields) {
      return write("error", message, fields);
    },
  };
}
