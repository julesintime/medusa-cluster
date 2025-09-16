# Claude Code Action - Alpine Linux Compatible

This is a local version of the `markwylde/claude-code-gitea-action` modified for Alpine Linux compatibility.

## Changes Made

- **Replaced setup-bun step**: The original action uses `oven-sh/setup-bun` which downloads glibc-compiled Bun that doesn't work on Alpine Linux (musl libc)
- **Added Alpine-compatible setup**: Uses the official Bun installer which works with Alpine Linux
- **Enhanced error handling**: Verifies Bun installation before proceeding

## Usage

Replace the original action reference in your workflow:

```yaml
# Instead of:
# uses: markwylde/claude-code-gitea-action@v1.0.5

# Use:
uses: ./.gitea/actions/claude-code-alpine
```

## Technical Details

The issue was that `setup-bun` downloads Bun v1.2.11 compiled for glibc (standard Linux), but Alpine Linux uses musl libc. This causes relocation errors:

- `Error relocating /root/.bun/bin/bun: gnu_get_libc_version: symbol not found`
- `Error relocating /root/.bun/bin/bun: unsupported relocation type 37`

Our fix installs Bun using the official installer which detects the system and installs the appropriate version.