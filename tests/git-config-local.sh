#!/bin/bash
# Tests for scripts/git-config-local. Fake $HOME and a stub `uname`/`cygpath`
# on PATH, so platform branches are exercised on any host and the real
# ~/.gitconfig is never touched.
# Usage: bash tests/git-config-local.sh
set -uo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$SRC_REPO/scripts/git-config-local"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"

fail=0
ok()  { printf 'ok:   %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }

# Stub uname: prints $FAKE_UNAME. Stub cygpath: echoes its last argument, so
# the windows branch is testable off Windows.
cat >"$T/bin/uname" <<'STUB'
#!/bin/bash
printf '%s\n' "${FAKE_UNAME:-Linux}"
STUB
cat >"$T/bin/cygpath" <<'STUB'
#!/bin/bash
for a; do :; done
printf '%s\n' "$a"
STUB
chmod +x "$T/bin/uname" "$T/bin/cygpath"
export PATH="$T/bin:/usr/bin:/bin"

run() { # run <fake-uname> [home]
    FAKE_UNAME="$1" HOME="${2:-$T/home}" LOCALAPPDATA="${LOCALAPPDATA:-/fake/AppData/Local}" \
        bash "$SCRIPT" 2>&1
}

# a: --print emits the signing stanza without writing anything
mkdir -p "$T/home"
OUT="$(FAKE_UNAME=Darwin HOME="$T/home" bash "$SCRIPT" --print 2>/dev/null)"
case "$OUT" in *'[gpg "ssh"]'*) ok "a: --print emits the gpg.ssh stanza";; *) bad "a: stanza missing: $OUT";; esac
case "$OUT" in *"1Password.app/Contents/MacOS/op-ssh-sign"*) ok "a: mac path on Darwin";; *) bad "a: mac path missing";; esac
[ -e "$T/home/.gitconfig.local" ] && bad "a: --print wrote the file" || ok "a: --print wrote nothing"

# b: linux render
run Linux >/dev/null
grep -q '/opt/1Password/op-ssh-sign' "$T/home/.gitconfig.local" && ok "b: linux path rendered" || bad "b: linux path"
grep -q '# platform: linux' "$T/home/.gitconfig.local" && ok "b: platform recorded" || bad "b: platform comment"

# c: idempotent re-run leaves the file alone
touch -t 202001010000 "$T/home/.gitconfig.local"
before="$(ls -li "$T/home/.gitconfig.local" | awk '{print $1}')"
OUT="$(run Linux)"
after="$(ls -li "$T/home/.gitconfig.local" | awk '{print $1}')"
case "$OUT" in *"already current"*) ok "c: reports already current";; *) bad "c: re-run output: $OUT";; esac
[ "$before" = "$after" ] && ok "c: file untouched" || bad "c: file rewritten"

# d: a changed file is backed up, not clobbered silently
echo "drifted" > "$T/home/.gitconfig.local"
run Linux >/dev/null
ls "$T/home"/.gitconfig.local.bak-* >/dev/null 2>&1 && ok "d: backed up before rewrite" || bad "d: no backup"
grep -q '/opt/1Password/op-ssh-sign' "$T/home/.gitconfig.local" && ok "d: rewritten" || bad "d: not rewritten"

# e: windows also writes a real ~/.gitconfig including the baseline + layers
H="$T/winhome"; mkdir -p "$H"
run MINGW64_NT-10.0 "$H" >/dev/null
grep -q 'op-ssh-sign.exe' "$H/.gitconfig.local" && ok "e: windows signer" || bad "e: windows signer"
grep -q 'allowedSignersFile' "$H/.gitconfig.local" && ok "e: allowedSignersFile set (no stow)" || bad "e: allowedSignersFile"
grep -q 'hooksPath' "$H/.gitconfig.local" && ok "e: hooksPath set (no stow)" || bad "e: hooksPath"
[ -e "$H/.gitconfig" ] && ok "e: wrote ~/.gitconfig" || bad "e: no ~/.gitconfig"
grep -q 'src/.gitconfig' "$H/.gitconfig" && ok "e: includes the repo baseline" || bad "e: baseline include"
grep -q '.gitconfig.local' "$H/.gitconfig" && ok "e: includes .local (works on an older baseline)" || bad "e: .local include"
grep -q '.gitconfig.private' "$H/.gitconfig" && ok "e: includes .private" || bad "e: .private include"

# f: non-windows does NOT write ~/.gitconfig (stow owns it there)
[ -e "$T/home/.gitconfig" ] && bad "f: clobbered the stowed ~/.gitconfig" || ok "f: left ~/.gitconfig to stow"

# g: the superseded ~/.gpg.gitconfig is retired, ~/.gitconfig.private untouched
H2="$T/legacy"; mkdir -p "$H2"
echo "old" > "$H2/.gpg.gitconfig"; echo "mine" > "$H2/.gitconfig.private"
run Linux "$H2" >/dev/null
[ -e "$H2/.gpg.gitconfig" ] && bad "g: .gpg.gitconfig still in place" || ok "g: .gpg.gitconfig retired"
ls "$H2"/.gpg.gitconfig.superseded-* >/dev/null 2>&1 && ok "g: retired by rename, not deletion" || bad "g: no superseded file"
[ "$(cat "$H2/.gitconfig.private")" = "mine" ] && ok "g: .gitconfig.private untouched" || bad "g: .private modified"

[ "$fail" = 0 ] && echo "ok: git-config-local tests clean"
exit "$fail"
