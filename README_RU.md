# Matcha MCP

[English](README.md) | **Русский**

MCP-сервер, который подключает AI-ассистентов к активной сессии [Matcha LuaVM](https://doc.wabisabi.mom/matcha/). Ваш агент может выполнять Luau-код, изучать дерево игры, декомпилировать скрипты, искать по коду и использовать API памяти Matcha — всё из Cursor, Claude Code или любого другого MCP-клиента.

**Репозиторий:** [github.com/wavelyz/roblox-matcha-mcp](https://github.com/wavelyz/roblox-matcha-mcp)

```
AI-клиент  ←stdio→  matcha-mcp (Node, :16385)
                        ↑ HTTP-опрос / регистрация / ответ
                   matcha-connector.luau (внутри Matcha)
                        ↑
                   Matcha LuaVM ↔ Roblox
```

## Требования

- **Node.js** 18+
- **[Matcha](https://doc.wabisabi.mom/matcha/)**, подключённый к сессии Roblox
- MCP-совместимый редактор (Cursor, Claude Desktop, Claude Code, Windsurf и т.д.)

## Быстрый старт

### 1. Сборка сервера

```bash
git clone https://github.com/wavelyz/roblox-matcha-mcp.git
cd roblox-matcha-mcp/matcha-mcp
npm install
npm run build
```

### 2. Добавление в MCP-клиент

Используйте **абсолютный путь** к `matcha-mcp/dist/index.js`.

**Cursor** — `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "matcha-mcp": {
      "command": "node",
      "args": ["/абсолютный/путь/к/matcha-mcp/dist/index.js"]
    }
  }
}
```

**Claude Code:**

```bash
claude mcp add --global matcha-mcp -- node /абсолютный/путь/к/matcha-mcp/dist/index.js
```

**Claude Desktop** — `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "matcha-mcp": {
      "command": "node",
      "args": ["/абсолютный/путь/к/matcha-mcp/dist/index.js"]
    }
  }
}
```

**Codex / OpenAI:**

```toml
[mcp_servers.matcha-mcp]
command = "node"
args = ["/абсолютный/путь/к/matcha-mcp/dist/index.js"]
```

> Настройка для Windsurf и других клиентов — в [docs/setup.md](docs/setup.md).

Перезапустите редактор после изменения конфигурации.

### 3. Подключение Matcha

Выполните один раз за сессию Roblox (в auto-run Matcha или скрипт-хабе):

```lua
_G.MatchaMCP = _G.MatchaMCP or {}
_G.MatchaMCP.BridgeURL = _G.MatchaMCP.BridgeURL or "localhost:16385"

loadstring(game:HttpGet("http://" .. _G.MatchaMCP.BridgeURL .. "/script.luau"))()
```

Или просто запустите [`matcha-loader.luau`](matcha-loader.luau).

Коннектор загружается напрямую с MCP-сервера по адресу `http://localhost:16385/script.luau` — отдельная загрузка не нужна.

**Дашборд:** [http://localhost:16385/](http://localhost:16385/) — статус подключения и прогресс индексации скриптов.

### 4. Проверка

В AI-клиенте вызовите `list-clients`. Вы должны увидеть своё имя игрока и ID плейса. Затем попробуйте `get-game-info` или `get-descendants-tree` для `game.Players.LocalPlayer.Backpack`.

## Инструменты

### Сессия

| Инструмент | Описание |
|------------|----------|
| `list-clients` | Список подключённых сессий Matcha (игрок, плейс, job ID) |
| `set-active-client` | Выбор, какой `clientId` получает вызовы инструментов |

### Выполнение кода

| Инструмент | Описание |
|------------|----------|
| `execute` | Выполнить Luau в Matcha (без возврата значений — для побочных эффектов) |
| `execute-file` | Выполнить `.lua` / `.luau` файл с диска на хосте |
| `get-data-by-code` | Выполнить Luau и вернуть сериализованные значения (небольшие запросы) |

### Исследование игры

| Инструмент | Описание |
|------------|----------|
| `get-descendants-tree` | Обойти дочерние элементы по пути к инстансу |
| `search-instances` | Найти инстансы по классу/тегу/имени/свойству под корнем |
| `get-game-info` | PlaceId, JobId, название игры, версия исполнителя |

### Скрипты

| Инструмент | Описание |
|------------|----------|
| `get-script-content` | Декомпилировать скрипт по пути (с диапазоном строк) |
| `script-grep` | Поиск по декомпилированным исходникам (текст/регулярки) |
| `semantic-search-scripts` | Поиск скриптов по поведению (нужна настройка эмбеддингов) |

### Консоль и память

| Инструмент | Описание |
|------------|----------|
| `get-console-output` | Недавний вывод `print` / `warn` из сессии |
| `get-memory-base` | Базовый адрес `RobloxPlayerBeta.exe` (unsafe Luau) |
| `memory-read` / `memory-write` | Чтение/запись типизированных значений по адресу (unsafe Luau) |

Полное руководство по инструментам: [docs/tools.md](docs/tools.md)

## Как это работает

```
1. AI вызывает MCP-инструмент (например, get-descendants-tree)
2. Node ставит JSON-команду в очередь HTTP-опроса клиента
3. Коннектор получает команду в ответе на опрос
4. Обработчик выполняется (разрешение пути, обход дерева, декомпиляция и т.д.)
5. Коннектор отправляет результат POST-запросом на /respond
6. Node разрешает промис и возвращает текст AI
```

Коннектор также декомпилирует до 700 скриптов при подключении (сначала player/backpack) и загружает их на сервер для `script-grep`.

## Конфигурация коннектора

Задаётся в `_G.MatchaMCP` перед загрузкой:

| Ключ | По умолчанию | Описание |
|------|--------------|----------|
| `BridgeURL` | `localhost:16385` | Адрес MCP HTTP-сервера |
| `MaxScriptMapping` | `700` | Максимум скриптов для декомпиляции под `script-grep` |
| `DisableInitialScriptDecompMapping` | — | Установите `true`, чтобы пропустить индексацию скриптов |

## Решение проблем

| Симптом | Решение |
|---------|---------|
| MCP не запускается | Выполните `npm run build`; проверьте путь к Node в конфиге |
| Нет клиентов в `list-clients` | Запустите загрузчик в Matcha; проверьте дашборд на `:16385` |
| Инструменты зависают | HTTP в Matcha может быть заблокирован; BridgeURL должен совпадать |
| Устаревший коннектор после обновлений | Остановите старый скрипт, затем запустите загрузчик один раз (не накапливайте перезагрузки) |
| `script-grep` ничего не находит | Дождитесь индексации на дашборде; скрипты из Backpack индексируются первыми |

## Структура репозитория

| Путь | Назначение |
|------|------------|
| `matcha-mcp/` | Node MCP-сервер + дашборд |
| `matcha-mcp/matcha-connector.luau` | Мост внутри VM (раздаётся на `/script.luau`) |
| `matcha-loader.luau` | Минимальный сниппет загрузки |
| `matcha-scripts/` | Опциональные пресеты экспорта [SaveInstance](https://github.com/Matt-T-123/SaveInstance) |
| `docs/` | Архитектура, заметки по Matcha LuaVM, настройка, инструменты |

## Безопасность

- Порт **16385** **без аутентификации**. Используйте только на **localhost** — никогда не открывайте в интернет.
- `memory-read` / `memory-write` могут повредить процесс Roblox. Включайте только если понимаете риски.

## Документация

- [Matcha LuaVM — обзор](docs/matcha-luavm.md) — что такое Matcha, API, отличия от экзекуторов
- [Архитектура](docs/architecture.md) — как работает мост
- [Инструменты](docs/tools.md) — когда использовать каждый MCP-инструмент
- [Настройка (все клиенты)](docs/setup.md)
- [Официальная документация Matcha](https://doc.wabisabi.mom/matcha/)

## Благодарности

Вдохновлено [roblox-executor-mcp](https://github.com/notpoiu/roblox-executor-mcp). Переписано для Matcha — HTTP-only, без хуков, поверх LuaVM.

## Лицензия

MIT — см. [LICENSE](LICENSE).
