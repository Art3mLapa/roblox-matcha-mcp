import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import registerSetActiveClient from "./impl/clients/set-active-client.js";
import registerListClients from "./impl/clients/list-clients.js";

import registerExecute from "./impl/execution/execute.js";
import registerExecuteFile from "./impl/execution/execute-file.js";

import registerGetScriptContent from "./impl/inspection/get-script-content.js";
import registerGetDataByCode from "./impl/inspection/get-data-by-code.js";
import registerGetConsoleOutput from "./impl/inspection/get-console-output.js";
import registerSearchInstances from "./impl/inspection/search-instances.js";
import registerScriptGrep from "./impl/inspection/script-grep.js";
import registerSemanticSearchScripts from "./impl/inspection/semantic-search-scripts.js";
import registerGetGameInfo from "./impl/inspection/get-game-info.js";
import registerGetDescendantsTree from "./impl/inspection/get-descendants-tree.js";

import registerMemoryRead from "./impl/memory/memory-read.js";
import registerMemoryWrite from "./impl/memory/memory-write.js";
import registerGetMemoryBase from "./impl/memory/get-memory-base.js";

export function registerAllTools(server: McpServer): void {
  registerSetActiveClient(server);
  registerListClients(server);

  registerExecute(server);
  registerExecuteFile(server);

  registerGetScriptContent(server);
  registerGetDataByCode(server);
  registerGetConsoleOutput(server);
  registerSearchInstances(server);
  registerScriptGrep(server);
  registerSemanticSearchScripts(server);
  registerGetGameInfo(server);
  registerGetDescendantsTree(server);

  registerMemoryRead(server);
  registerMemoryWrite(server);
  registerGetMemoryBase(server);
}
