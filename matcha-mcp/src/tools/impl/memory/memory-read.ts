import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { describeResponse, sendAndWait } from "../../factory.js";

export default function register(server: McpServer): void {
  server.registerTool(
    "memory-read",
    {
      title: "Read process memory via Matcha",
      description:
        "Read a value from RobloxPlayerBeta.exe memory using Matcha's memory_read. Requires unsafe Luau enabled in Matcha.",
      inputSchema: z.object({
        address: z.number().describe("Memory address (integer)"),
        memoryType: z
          .enum(["int", "float", "double", "byte", "string", "uintptr_t"])
          .optional()
          .default("uintptr_t"),
      }),
    },
    async (options) =>
      sendAndWait({
        type: "memory-read",
        data: { address: options.address, memoryType: options.memoryType },
        failureMessage: (r) => "memory-read failed: " + describeResponse(r),
        successMessage: (r) => String(r.output ?? ""),
      })
  );
}
