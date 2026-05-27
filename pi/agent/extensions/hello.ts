/**
 * Hello Tool - Minimal custom tool example
 */

import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const helloTool = defineTool({
  name: "hello",
  label: "Hello",
  description: "A simple greeting tool",
  parameters: Type.Object({
    name: Type.String({ description: "Name to greet" }),
  }),

  async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
    return {
      content: [{ type: "text", text: `Hello there, ${params.name}!` }],
      details: { greeted: params.name },
    };
  },
});

export default function (pi: ExtensionAPI) {
  // Tool callable by the LLM: hello({ name })
  pi.registerTool(helloTool);

  // Slash command callable by you: /hello ethan
  pi.registerCommand("hello", {
    description: "Say hello",
    handler: async (args, ctx) => {
      const name = (args || "world").trim() || "world";
      ctx.ui.notify(`Hello there, ${name}!`, "info");
    },
  });
}
