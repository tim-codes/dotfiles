# .zshenv - loaded for ALL zsh shells, interactive or not, and the ONLY file a
# non-interactive zsh reads.
#
# Load-bearing, because zsh is the LOGIN shell on these machines
# (scripts/setup-linux chsh's to it, macOS defaults to /bin/zsh) while
# interactive use goes through fish. So ssh one-liners, cron, scripts and
# Claude Code all land here and nowhere else. The block below used to be
# commented out, which left zsh — the redundant/fallback shell — as the only
# one with no shared config at all.
#
# The shared minimal set (variables + PATH) lives in one file sourced by both
# bash and zsh so the two cannot drift apart again. Aliases, prompt and
# completions are deliberately NOT included: zsh is the fallback for machines
# and contexts without fish, not a second fish.
#
# Keep this file silent — output here corrupts scp/sftp and captured ssh output.

if [ -f "$HOME/.config/shell/common.sh" ]; then
    . "$HOME/.config/shell/common.sh"
fi
