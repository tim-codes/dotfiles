# Claude Code Setup

## Installation

Claude Code is installed natively (`installMethod: native`). Auto-updates are disabled.

## Global Config

- `~/.claude/settings.json` — plugins, model preference
- `~/.claude/settings.local.json` — permissions
- `~/.claude/CLAUDE.md` — global instructions (use gh CLI for GitHub resources)
- `~/.claude.json` — runtime state (auto-managed)

## Plugins

Enabled in `~/.claude/settings.json`:

- `feature-dev@claude-plugins-official`
- `superpowers@claude-plugins-official`
- `Notion@claude-plugins-official`
- `linear@claude-plugins-official`
- `typescript-lsp@claude-plugins-official` (see fix below)

## TypeScript LSP Plugin Fix

The official `typescript-lsp` plugin from the Claude Code marketplace is broken upstream (see [anthropics/claude-code#15148](https://github.com/anthropics/claude-code/issues/15148)). The plugin directory ships with only `LICENSE` and `README.md` — the `lspServers` config defined in the marketplace's `marketplace.json` is never extracted into the plugin cache.

### Prerequisites

Install the language server globally:

```bash
pnpm i -g typescript-language-server@latest typescript@latest
```

Verify:

```bash
which typescript-language-server  # /Users/tim/Library/pnpm/typescript-language-server
which tsserver                    # /Users/tim/Library/pnpm/tsserver
```

### Environment Variable

Add to `~/.config/fish/config.fish`:

```fish
set -gx ENABLE_LSP_TOOL 1
```

This is an undocumented env var required to activate the LSP tool system.

### Patch the Plugin Cache

The plugin cache lives at `~/.claude/plugins/cache/claude-plugins-official/typescript-lsp/1.0.0/`. Two files need to be created manually:

**`~/.claude/plugins/cache/claude-plugins-official/typescript-lsp/1.0.0/.lsp.json`**

```json
{
  "typescript": {
    "command": "typescript-language-server",
    "args": ["--stdio"],
    "extensionToLanguage": {
      ".ts": "typescript",
      ".tsx": "typescriptreact",
      ".js": "javascript",
      ".jsx": "javascriptreact",
      ".mts": "typescript",
      ".cts": "typescript",
      ".mjs": "javascript",
      ".cjs": "javascript"
    }
  }
}
```

**`~/.claude/plugins/cache/claude-plugins-official/typescript-lsp/1.0.0/.claude-plugin/plugin.json`**

```json
{
  "name": "typescript-lsp",
  "description": "TypeScript/JavaScript language server for enhanced code intelligence",
  "version": "1.0.0",
  "author": {
    "name": "Anthropic",
    "email": "support@anthropic.com"
  },
  "lspServers": "./.lsp.json"
}
```

### Verification

Restart Claude Code, then the `LSP` tool should be available with operations: `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `workspaceSymbol`, `goToImplementation`, `prepareCallHierarchy`, `incomingCalls`, `outgoingCalls`.

### Caveat

If the plugin is updated from the marketplace, the cache directory gets replaced and these manual files will be lost. Re-apply the patch after any plugin update.
