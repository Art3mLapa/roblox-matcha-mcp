import type { ToolTextResponse } from "./factory.js";

export const NO_CLIENT_ERROR: ToolTextResponse = {
  content: [
    {
      type: "text",
      text: "No Matcha client connected. Run matcha-loader.luau in Matcha (or load http://localhost:16385/script.luau) while this MCP server is running.",
    },
  ],
  isError: true,
};

export const INVALID_CLIENT_ERROR: ToolTextResponse = {
  content: [
    {
      type: "text",
      text: "Invalid client ID provided. Please use the list-clients tool to get a list of valid client IDs.",
    },
  ],
  isError: true,
};
