# Starting from $HOME makes Claude ask to trust the ENTIRE home directory — a
# huge, mostly irrelevant trust scope granted in one keystroke — and starting
# in a context dir treats config state as a workspace. Both are redirected into
# ~/claude, the default working directory: small, purpose-made, and a sane
# thing to trust. Any real working directory is left alone — an explicit `cd`
# into a project is the whole point. pushd/popd so the caller's shell comes
# back to where it started.
# All arguments after the context dir pass straight through, so
# `claude-exxo --model fable --effort medium -p ...` works as if calling claude
# directly. Those flags are session-scoped and never touch settings.json; the
# in-session `/model` and `/effort` DO write your default, which is a habit to
# avoid rather than something to guard against — a rewrite shows up in
# `git diff` on files/claude/settings.json and is reverted there.
function __claude_ctx --description 'Run claude in a per-account config context'
    set -l dir $argv[1] # context dir, or "" for the default ~/.claude
    set -e argv[1]
    set -l home (path resolve $HOME)
    set -l here (path resolve .)
    set -l ctx_dirs $home/.claude-personal $home/.claude-reserve $home/.claude-exxo $home/.claude-exxo-personal $home/.claude-exxo-openrouter
    set -l jumped 0
    if test "$here" = "$home"; or contains -- "$here" $ctx_dirs
        mkdir -p $home/claude
        pushd $home/claude
        set jumped 1
    end
    # The exxo-openrouter overlay env is inherited by anything a K3 session
    # spawns; every other context must not see it, so it is unset for the
    # launched process only. The openrouter wrapper is left untouched.
    set -l scrub
    if test "$dir" != "$HOME/.claude-exxo-openrouter"
        for v in ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_FABLE_MODEL CLAUDE_CODE_SUBAGENT_MODEL
            set -a scrub -u $v
        end
    end
    if test -n "$dir"
        env $scrub CLAUDE_CONFIG_DIR=$dir claude $argv
    else
        env $scrub -u CLAUDE_CONFIG_DIR claude $argv
    end
    set -l st $status
    test $jumped -eq 1; and popd
    return $st
end
