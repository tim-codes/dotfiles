"""The attended fragment's ask and allow rules, matched against example commands.

The matcher follows https://code.claude.com/docs/en/permissions ("Wildcard patterns",
read 23 Nov 2026): a `*` matches any text, spaces included; `:*` at the end equals ` *`;
a trailing ` *` that is the rule's only wildcard also matches the bare command; deny and
ask are checked before allow. Compound splitting and wrapper stripping are out of scope:
every example here is one simple command.

Usage: python3 -I tests/test_attended_ask_rules.py
"""
import json
import os
import re
import unittest

FRAG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "files", "claude", "settings.attended.json")
with open(FRAG) as f:
    PERMS = json.load(f)["permissions"]


def bash_patterns(key):
    return [r[5:-1] for r in PERMS.get(key, []) if r.startswith("Bash(") and r.endswith(")")]


def matches(pattern, cmd):
    if pattern.endswith(":*"):
        pattern = pattern[:-2] + " *"
    rx = ".*".join(map(re.escape, pattern.split("*")))
    if re.fullmatch(rx, cmd, re.S):
        return True
    # a trailing " *" that is the only wildcard also matches the bare command
    return pattern.endswith(" *") and pattern.count("*") == 1 and cmd == pattern[:-2]


def decision(cmd):
    for key in ("deny", "ask", "allow"):
        if any(matches(p, cmd) for p in bash_patterns(key)):
            return key
    return None


class AttendedRules(unittest.TestCase):
    def assertDecision(self, want, cmds):
        for cmd in cmds:
            self.assertEqual(decision(cmd), want, cmd)

    def test_gh_api_writes_ask(self):
        self.assertDecision("ask", [
            "gh api repos/o/r/issues -f title=x",
            "gh api repos/o/r/issues -ftitle=x",
            "gh api repos/o/r/issues -F number=1",
            "gh api -f query=x graphql",
            "gh api graphql -f query='query { viewer { login } }'",  # read and mutation look alike: ask
            "gh api -X DELETE repos/o/r/git/refs/heads/x",
            "gh api repos/o/r/pulls/1/merge --method PUT",
            "gh api repos/o/r/issues --field title=x",
            "gh api repos/o/r/issues --raw-field body=x",
            "gh api repos/o/r/issues --input body.json",
        ])

    def test_gh_api_reads_do_not_ask(self):
        self.assertDecision("allow", [
            "gh api repos/o/r/contents/some-file",
            "gh api repos/o/r/contents/docs/my-file.md",
            "gh api repos/o/r/actions/runs --jq '.workflow_runs[] | .head_branch'",
            "gh api repos/o/r/git/refs/heads/feature-flag --jq .object.sha",
        ])

    def test_push_to_default_branch_asks(self):
        self.assertDecision("ask", [
            "git push origin main",
            "git push -u origin main",
            "git push origin main --force",
            "git push origin HEAD:main",
            "git push origin HEAD:main --force-with-lease",
            "git push origin +HEAD:refs/heads/main",
            "git push origin refs/heads/main",
            "git push origin +main",
            "git push origin master",
            "git push origin HEAD:refs/heads/master",
        ])

    def test_push_to_other_branches_does_not_ask(self):
        self.assertDecision("allow", [
            "git push origin claude/maintenance-x",
            "git push -u origin claude/main-menu",
            "git push origin feature/x:main-v2",
            "git push --force-with-lease origin claude/remaining",
            "git push origin x/main",
        ])

    def test_process_listings_are_allowed(self):
        self.assertDecision("allow", ["ps", "ps aux", "ps -o pid,command -p 123", "pgrep -fl vitest", "pgrep node"])
        self.assertNotIn("Bash(ps:*)", PERMS["ask"])
        self.assertNotIn("Bash(pgrep:*)", PERMS["ask"])


if __name__ == "__main__":
    unittest.main()
