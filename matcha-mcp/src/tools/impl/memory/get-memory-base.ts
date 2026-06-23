import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { describeResponse, sendAndWait } from "../../factory.js";

export default function register(server: McpServer): void {
  server.registerTool(
    "get-memory-base",
    {
      title: "Get RobloxPlayerBeta.exe base address",
      description: "Returns the base address of RobloxPlayerBeta.exe via Matcha getbase().",
      inputSchema: z.object({}),
    },
    async () =>
      sendAndWait({
        type: "get-memory-base",
        data: {},
        failureMessage: (r) => "get-memory-base failed: " + describeResponse(r),
        successMessage: (r) => String(r.output ?? ""),
      })
  );
}
