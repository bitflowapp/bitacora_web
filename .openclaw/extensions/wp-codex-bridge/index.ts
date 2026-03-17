import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import { emptyPluginConfigSchema } from "openclaw/plugin-sdk";
import { registerWhatsAppCodexBridge } from "../../../automation/wp_codex_bridge/index.mjs";

const plugin = {
  id: "wp-codex-bridge",
  name: "WhatsApp Codex Bridge",
  description: "Bridge allowlisted WhatsApp prefix commands to local Codex CLI.",
  configSchema: emptyPluginConfigSchema(),
  register(api: OpenClawPluginApi) {
    registerWhatsAppCodexBridge(api);
  },
};

export default plugin;
