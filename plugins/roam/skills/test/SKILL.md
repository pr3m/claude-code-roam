---
name: roam:test
description: Smoke test — verify platform, scripts, yolo gate cases without actually entering roam. Use when user says "test roam", "smoke test roam", "/roam:test", "is roam working".
---

# /roam:test

```sh
~/.claude/roam/bin/roam-cli test
```

Show output verbatim. The smoke-test script exits 0 on success, 1 on any failure.

## On failure

- **Missing CLI tool** — reinstall Xcode Command Line Tools (`xcode-select --install`).
- **Script not executable** — reinstall the plugin: `/plugin install roam@claude-code-roam`.
- **Yolo case mismatch** — open an issue at https://github.com/pr3m/claude-code-roam with the failing case.
