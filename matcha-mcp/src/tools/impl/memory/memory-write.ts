import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { describeResponse, sendAndWait } from "../../factory.js";

export default function register(server: McpServer): void {
  server.registerTool(
    "memory-write",
    {
      title: "Write process memory via Matcha",
      description:
        "Write a value to RobloxPlayerBeta.exe memory using Matcha's memory_write. Requires unsafe Luau enabled. Use with care.",
      inputSchema: z.object({
        address: z.number().describe("Memory address (integer)"),
        value: z.union([z.string(), z.number(), z.boolean()]).describe("Value to write"),
        memoryType: z
          .enum(["int", "float", "double", "byte", "string", "uintptr_t"])
          .optional()
          .default("uintptr_t"),
      }),
    },
    async (options) =>
      sendAndWait({
        type: "memory-write",
        data: {
          address: options.address,
          value: options.value,
          memoryType: options.memoryType,
        },
        failureMessage: (r) => "memory-write failed: " + describeResponse(r),
        successMessage: () => "memory-write ok",
      })
  );
}
