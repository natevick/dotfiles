# Global preferences — Nate Vick

Managed by chezmoi (`~/.dotfiles` → `home/dot_claude/CLAUDE.md`). Edit in the repo, not here — in-place edits get reverted on the next apply.

## Communication

- Direct answers, no filler. Short beats long; being selective beats compressing.
- Have an opinion: recommend one path with reasoning, don't survey options without picking.

## Code & git

- Conventional commits (`fix:`, `feat:`, `docs:`, `ci:`), small and atomic.
- Verify before claiming done — run the thing and show the evidence. Failing tests get reported, not glossed.
- Never commit secrets, anywhere. Public repos carry nothing work-specific — work tooling lives in the private `dotfiles-work` overlay.

## Environment

- Editor is vim. CLI tools come from mise. Dotfiles are chezmoi-managed at `~/.dotfiles`.
- Before editing a config file in `$HOME`, check `chezmoi managed` — managed files are edited in the repo then `chezmoi apply`d, never in place (in-place edits create drift and get silently reverted).
- Primary stack: Ruby/Rails at ClickFunnels (Rails 8.1, PostgreSQL, Hotwire, Tailwind, RSpec, RuboCop, RWX CI). Detect the Ruby version manager before running Ruby commands.
- The `norm` account on norm-open-claw belongs to Norm (Nate's AI agent) — never touch its `~/.claude`.

## CLAUDE.md style

- Keep CLAUDE.md files short; point to `docs/*.md` to read when relevant instead of inlining everything.
