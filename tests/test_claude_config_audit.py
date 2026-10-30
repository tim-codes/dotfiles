"""Tests for scripts/claude-config-audit, run against synthetic repos in a temp dir.

HOME, CLAUDE_CONFIG_DIR and git's global config are all redirected into the
temp dir, so nothing reads or writes the real contexts and no commit is signed.

Usage: python3 -I tests/test_claude_config_audit.py
"""
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "claude-config-audit")
_loader = importlib.machinery.SourceFileLoader("claude_config_audit", SCRIPT)
_spec = importlib.util.spec_from_loader("claude_config_audit", _loader)
cca = importlib.util.module_from_spec(_spec)
_loader.exec_module(cca)


class Fixture:
    def __init__(self, root):
        self.root = root
        self.home = os.path.join(root, "home")
        os.makedirs(os.path.join(self.home, ".claude-personal", "skills"), exist_ok=True)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("GIT_", "CLAUDE_"))}
        self.env.update({
            "HOME": self.home, "CLAUDE_CONFIG_DIR": os.path.join(self.home, ".claude-personal"),
            "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.invalid",
            "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.invalid",
        })

    def git(self, repo, *args, date=None):
        env = dict(self.env)
        if date:
            env["GIT_AUTHOR_DATE"] = env["GIT_COMMITTER_DATE"] = date
        subprocess.run(["git", "-C", repo, "-c", "commit.gpgsign=false", "-c", "protocol.file.allow=always",
                        *args], check=True, capture_output=True, env=env)

    def repo(self, rel, files=None, date=None):
        path = os.path.join(self.root, rel)
        os.makedirs(path, exist_ok=True)
        self.git(path, "init", "-q", "-b", "main")
        self.write(path, files or {"README": "x\n"})
        self.git(path, "add", "-A")
        self.git(path, "commit", "-q", "-m", "init", date=date)
        return path

    @staticmethod
    def write(repo, files):
        for rel, content in files.items():
            p = os.path.join(repo, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as f:
                f.write(content if isinstance(content, str) else json.dumps(content, indent=2))

    def run(self, *args):
        r = subprocess.run([sys.executable, "-I", SCRIPT, *args], capture_output=True, text=True,
                           env=self.env, cwd=self.root)
        return r.returncode, r.stdout, r.stderr

    def audit(self, repo, *extra):
        code, out, err = self.run("--repo", repo, "--json", *extra)
        self.last_err = err
        return code, json.loads(out)


def checks(doc, level=None):
    return {(f["check"], f["level"]) if level is None else f["check"]
            for r in doc["repos"] for f in r["findings"] if level in (None, f["level"])}


class ClassifierTests(unittest.TestCase):
    def test_dangerous(self):
        for rule in ["Bash", "Bash(*)", "Bash(just:*)", "Bash(just *)", "Bash(git:*)", "Bash(python3:*)",
                     "Bash(npx:*)", "Bash(pulumi:*)", "Bash(pulumi up:*)", "Bash(pulumi refresh --yes:*)",
                     "Bash(esc env get:*)", "Bash(gcloud secrets versions access:*)", "Bash(gcloud secrets *)",
                     "Bash(git reset --hard:*)", "Bash(ansible ragnar -m shell -a:*)", "Bash(ssh:*)",
                     "Bash(docker run:*)", "Bash(op read:*)", "Bash(rm:*)",
                     "Bash(pulumi env get exxo/x/dev --show-secrets)",
                     "Bash(MYSQL_PWD=$(gcloud secrets versions access latest) mysql -e 'x')"]:
            self.assertIsNotNone(cca.dangerous_reason(rule), rule)

    def test_benign(self):
        for rule in ["Bash(just check:*)", "Bash(git status:*)", "Bash(pulumi preview:*)",
                     "Bash(pulumi env get:*)", "Bash(gcloud * list:*)", "Bash(python3 -m json.tool)",
                     "Bash(just --justfile=agent/Justfile:*)", "Bash(pnpm test:*)", "Bash(TURBO_FORCE=1 just check)",
                     "WebSearch", "mcp__ide__getDiagnostics", "Bash(pulumi)"]:
            self.assertIsNone(cca.dangerous_reason(rule), rule)

    def test_junk(self):
        for rule in ["Bash(done)", "Bash(for f in *)", "Bash(mkdir /Users/tim/dev/x:*)",
                     "Bash(git commit -m \"$(cat <<'EOF'\nmsg\nEOF\n)\")", "mcp__plugin_Notion_notion__notion-search",
                     "mcp__plugin_vercel_vercel__get_project"]:
            self.assertIsNotNone(cca.junk_reason(rule), rule)
        self.assertIsNone(cca.junk_reason("Read(//Users/tim/dev/sibling/**)"))
        self.assertIsNone(cca.junk_reason("WebFetch(domain:tailscale.com)"))  # classified in strip_plan

    def test_covered(self):
        allows = ["Bash(git log:*)", "Bash(just --list:*)", "WebSearch"]
        self.assertTrue(cca.covered("Bash(git log --oneline:*)", allows))
        self.assertTrue(cca.covered("Bash(just --list)", allows))
        self.assertTrue(cca.covered("WebSearch", allows))
        self.assertFalse(cca.covered("Bash(git push:*)", allows))

    def test_mutating_recipes(self):
        with tempfile.NamedTemporaryFile("w", suffix="Justfile", delete=False) as f:
            f.write('set shell := ["bash", "-uc"]\nlist:\n    @just --list\napi-prod-get path:\n    curl x\n'
                    'backend-deploy env="dev":\n    ./deploy {{env}}\nfoo:\n    echo X=1 > ../.env\n'
                    'semrush-prod-july-urls:\n    echo\n')
        try:
            names = [n for n, _ in cca.mutating_recipes(f.name)]
        finally:
            os.unlink(f.name)
        self.assertEqual(names, ["backend-deploy", "foo", "semrush-prod-july-urls"])

    def _splicing(self, text):
        with tempfile.NamedTemporaryFile("w", suffix="Justfile", delete=False) as f:
            f.write(text)
        try:
            return cca.splicing_recipes(f.name)
        finally:
            os.unlink(f.name)

    def test_splicing_recipes(self):
        self.assertEqual(self._splicing('show path:\n    cat {{ path }}\n'), ["show"])
        self.assertEqual(self._splicing('run +args:\n    @tool {{args}}\n'), ["run"])
        self.assertEqual(self._splicing('lg env="dev" n="5":\n    echo "{{ n }}"\n    echo ok\n'), ["lg"])
        # positional arguments referenced as "$1" are the safe form
        self.assertEqual(self._splicing('set positional-arguments\nshow path:\n    cat -- "$1"\n'), [])
        # recipe functions are not parameters
        self.assertEqual(self._splicing('where:\n    ls {{ justfile_directory() }}\n'), [])
        # a function-call argument that merely shares a prefix with the param is fine
        self.assertEqual(self._splicing('show path:\n    echo {{ justfile_directory() }} "$1"\n'), [])
        # comments don't count; $-prefixed params are env vars, not spliced
        self.assertEqual(self._splicing('show path:\n    # {{ path }}\n    echo hi\n'), [])
        self.assertEqual(self._splicing('show $path:\n    echo "$path"\n'), [])


class CliTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.fx = Fixture(os.path.realpath(self.tmp.name))

    def tearDown(self):
        self.tmp.cleanup()

    def test_clean_repo(self):
        repo = self.fx.repo("clean")
        code, doc = self.fx.audit(repo)
        self.assertEqual(code, 0)
        self.assertEqual(checks(doc), set())

    def test_committed_dangerous_is_error(self):
        repo = self.fx.repo("r", {".claude/settings.json": {"permissions": {"allow": ["Bash(just:*)", "Bash(just check:*)"]}}})
        code, doc = self.fx.audit(repo)
        self.assertEqual(code, 1)
        self.assertIn(("committed-dangerous", "error"), checks(doc))

    def test_fix_local(self):
        repo = self.fx.repo("r")
        local = os.path.join(repo, ".claude", "settings.local.json")
        self.fx.write(repo, {".claude/settings.local.json": {"permissions": {
            "allow": ["Bash(git:*)", "Bash(git status:*)", "Bash(done)", "WebSearch", "Bash(just test-web:*)",
                      "Bash(just test-web:*)", "mcp__plugin_vercel_vercel__get_project"],
            "deny": ["Bash(rm -rf:*)"], "additionalDirectories": ["/tmp/x"]}, "outputStyle": "x"}})
        code, doc = self.fx.audit(repo)
        self.assertEqual(code, 1)
        self.assertIn(("local-dangerous", "error"), checks(doc))
        self.assertIn(("local-strippable", "warn"), checks(doc))
        code, doc = self.fx.audit(repo, "--fix-local")
        self.assertEqual(code, 0, doc)
        with open(local) as f:
            new = json.load(f)
        self.assertEqual(new, {"permissions": {"allow": ["Bash(just test-web:*)"], "deny": ["Bash(rm -rf:*)"],
                                               "additionalDirectories": ["/tmp/x"]}, "outputStyle": "x"})
        self.assertTrue(os.path.exists(local + ".bak"))
        self.assertEqual(doc["repos"][0]["fixed"][0]["removed"], 6)
        self.assertEqual(checks(doc), set())

    def test_webfetch_domain_allows_are_redundant(self):
        repo = self.fx.repo("r")
        local = os.path.join(repo, ".claude", "settings.local.json")
        self.fx.write(repo, {".claude/settings.local.json": {"permissions": {
            "allow": ["WebFetch(domain:docs.anthropic.com)", "WebFetch(domain:github.com)", "WebSearch",
                      "Bash(just test-web:*)"]}}})
        _, doc = self.fx.audit(repo)
        self.assertIn(("local-strippable", "info"), checks(doc))
        _, doc = self.fx.audit(repo, "--fix-local")
        with open(local) as f:
            self.assertEqual(json.load(f), {"permissions": {"allow": ["Bash(just test-web:*)"]}})
        self.assertEqual(doc["repos"][0]["fixed"][0]["removed"], 3)  # two WebFetch + WebSearch (global)

    def test_fix_local_empties_to_braces(self):
        repo = self.fx.repo("r")
        self.fx.write(repo, {".claude/settings.local.json": {"permissions": {"allow": ["Bash(git:*)"]}}})
        self.fx.audit(repo, "--fix-local")
        with open(os.path.join(repo, ".claude", "settings.local.json")) as f:
            self.assertEqual(json.load(f), {})

    def test_local_oversize(self):
        repo = self.fx.repo("r")
        self.fx.write(repo, {".claude/settings.local.json": {"permissions": {
            "allow": [f"Bash(just r{i}:*)" for i in range(30)]}}})
        _, doc = self.fx.audit(repo)
        self.assertIn(("local-oversize", "warn"), checks(doc))

    def test_justfile_blanket(self):
        jf = "list:\n    @just --list\nrelease-deploy:\n    ./x\n"
        repo = self.fx.repo("r", {"agent/Justfile": jf})
        _, doc = self.fx.audit(repo)
        self.assertNotIn("justfile-blanket", checks(doc, "error"))  # not trusted: no finding
        self.fx.write(repo, {".claude/settings.json": {"permissions": {"allow": ["Bash(just --justfile=agent/Justfile:*)"]}}})
        code, doc = self.fx.audit(repo)
        self.assertEqual(code, 1)
        self.assertIn("justfile-blanket", checks(doc, "error"))

    def test_justfile_param_splice(self):
        bad = "show path:\n    cat {{ path }}\n"
        good = 'set positional-arguments\nshow path:\n    cat -- "$1"\nwhere:\n    ls {{ justfile_directory() }}\n'
        trust = {".claude/settings.json": {"permissions": {"allow": ["Bash(just --justfile=agent/Justfile:*)"]}}}
        repo = self.fx.repo("r", {"agent/Justfile": bad})
        _, doc = self.fx.audit(repo)
        self.assertNotIn("justfile-param-splice", checks(doc, "error"))  # not trusted: no finding
        self.fx.write(repo, trust)
        code, doc = self.fx.audit(repo)
        self.assertEqual(code, 1)
        self.assertIn("justfile-param-splice", checks(doc, "error"))
        msg = [f["message"] for r in doc["repos"] for f in r["findings"] if f["check"] == "justfile-param-splice"][0]
        self.assertIn("agent/Justfile:show", msg)
        self.fx.write(repo, {"agent/Justfile": good})
        code, doc = self.fx.audit(repo)
        self.assertNotIn("justfile-param-splice", checks(doc))
        self.assertEqual(code, 0)

    def test_deny_floor_partial_restatement(self):
        repo = self.fx.repo("r", {".claude/settings.json": {"permissions": {"deny": ["Bash(op read:*)"]}}})
        _, doc = self.fx.audit(repo)
        self.assertIn(("deny-floor", "warn"), checks(doc))
        floor = cca.global_settings("personal")["floor"]
        self.fx.write(repo, {".claude/settings.json": {"permissions": {"deny": floor + ["Bash(just db-destroy:*)"]}}})
        _, doc = self.fx.audit(repo)
        self.assertNotIn("deny-floor", checks(doc, "warn"))
        self.fx.write(repo, {".claude/settings.json": {"permissions": {"deny": ["Bash(just db-destroy:*)"]}}})
        _, doc = self.fx.audit(repo)
        self.assertNotIn("deny-floor", checks(doc, "warn"))

    def test_claude_md(self):
        body = "# Repo\n\n## Secrets are referenced, never written\n\nx\n" + "line\n" * 310
        repo = self.fx.repo("r", {"CLAUDE.md": body})
        _, doc = self.fx.audit(repo)
        self.assertIn(("claude-md-size", "warn"), checks(doc))
        self.assertIn(("claude-md-restated", "warn"), checks(doc))

    def test_skill_links(self):
        repo = self.fx.repo("r", {"vendor/skills/styling/SKILL.md": "x"})
        d = os.path.join(repo, ".claude", "skills")
        os.makedirs(d)
        os.symlink("../../vendor/skills/styling", os.path.join(d, "styling"))
        os.symlink("../../vendor/skills/styling", os.path.join(d, "portal-styling"))
        _, doc = self.fx.audit(repo)
        msg = [f["message"] for f in doc["repos"][0]["findings"] if f["check"] == "skill-links"][0]
        self.assertIn("same skill linked twice", msg)
        self.assertIn("portal-styling: aliases upstream 'styling'", msg)

    def test_submodule_behind(self):
        up = self.fx.repo("skills-upstream")
        pinned = subprocess.run(["git", "-C", up, "rev-parse", "HEAD"], capture_output=True, text=True,
                                env=self.fx.env).stdout.strip()
        for i in range(5):
            self.fx.write(up, {f"f{i}": "x"})
            self.fx.git(up, "add", "-A")
            self.fx.git(up, "commit", "-q", "-m", f"c{i}")
        repo = self.fx.repo("r", {".gitmodules": '[submodule ".claude/vendor/skills"]\n'
                                                 '\tpath = .claude/vendor/skills\n\turl = ../skills.git\n'})
        self.fx.git(repo, "update-index", "--add", "--cacheinfo", f"160000,{pinned},.claude/vendor/skills")
        self.fx.git(repo, "commit", "-q", "-m", "pin")
        self.fx.git(self.fx.root, "clone", "-q", up, os.path.join(repo, ".claude", "vendor", "skills"))
        _, doc = self.fx.audit(repo)
        f = [f for f in doc["repos"][0]["findings"] if f["check"] == "skills-submodule"][0]
        self.assertEqual(f["level"], "warn")
        self.assertIn("5 commit(s) behind", f["message"])

    def test_hook_mode(self):
        plain = os.path.join(self.fx.root, "not-a-repo")
        os.makedirs(plain)
        code, out, _ = self.fx.run("--repo", plain, "--quiet", "--hook")
        self.assertEqual((code, out), (0, ""))
        clean = self.fx.repo("clean")
        code, out, _ = self.fx.run("--repo", clean, "--quiet", "--hook")
        self.assertEqual((code, out), (0, ""))
        bad = self.fx.repo("bad", {".claude/settings.json": {"permissions": {"allow": ["Bash(git:*)"]}}})
        code, out, _ = self.fx.run("--repo", bad, "--quiet", "--hook")
        self.assertEqual(code, 0)
        payload = json.loads(out)
        self.assertIn("1 error(s)", payload["systemMessage"])
        self.assertEqual(payload["hookSpecificOutput"]["hookEventName"], "SessionStart")
        self.assertIn("committed-dangerous", payload["hookSpecificOutput"]["additionalContext"])

    def test_quiet_text(self):
        clean = self.fx.repo("clean")
        code, out, _ = self.fx.run("--repo", clean, "--quiet")
        self.assertEqual((code, out), (0, ""))

    def test_estate_discovery(self):
        active = self.fx.repo("dev/active")
        self.fx.repo("dev/old", date="2020-01-01T00:00:00Z")
        self.fx.repo("dev/picnic-thing")
        self.fx.repo("dev/group/nested", {".claude/settings.json": {"permissions": {"allow": ["Bash(git:*)"]}}})
        self.fx.git(active, "worktree", "add", "-q", os.path.join(self.fx.root, "dev", "active-wt"), "-b", "wt")
        root = os.path.join(self.fx.root, "dev")
        code, out, _ = self.fx.run("--estate", "--root", root, "--json")
        doc = json.loads(out)
        names = sorted(os.path.basename(r["repo"]) for r in doc["repos"])
        self.assertEqual(names, ["active", "nested"])
        self.assertEqual([os.path.basename(s["repo"]) for s in doc["skipped"]], ["old"])
        self.assertEqual(code, 1)
        code, out, _ = self.fx.run("--estate", "--root", root, "--json", "--all")
        names = sorted(os.path.basename(r["repo"]) for r in json.loads(out)["repos"])
        self.assertEqual(names, ["active", "nested", "old"])


if __name__ == "__main__":
    unittest.main()
