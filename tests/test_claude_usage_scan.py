"""Tests for scripts/claude-usage-scan, run against synthetic transcripts.

Usage: python3 -I tests/test_claude_usage_scan.py
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "claude-usage-scan")
TS = "2099-01-01T00:00:00.000Z"  # always inside the default 30-day window


def assistant(sid, mid, tool_uses=(), input_tokens=0):
    content = [{"type": "tool_use", "id": tid, "name": "Agent",
                "input": {"subagent_type": t, "description": d, "prompt": "do it"}}
               for tid, t, d in tool_uses]
    return json.dumps({"type": "assistant", "sessionId": sid, "timestamp": TS, "cwd": "/x/proj",
                       "message": {"id": mid, "model": "claude-sonnet", "content": content,
                                   "usage": {"input_tokens": input_tokens}}}, separators=(",", ":"))  # compact, like real transcripts


def write_fixture(root, subagents):
    """subagents: list of (tool_use_id, agent_type, description, input_tokens)."""
    proj = os.path.join(root, ".claude-test", "projects", "slug")
    os.makedirs(os.path.join(proj, "s1", "subagents"), exist_ok=True)
    with open(os.path.join(proj, "s1.jsonl"), "w") as f:
        f.write(assistant("s1", "m0", [(tid, t, d) for tid, t, d, _ in subagents], 10) + "\n")
    for tid, t, d, tok in subagents:
        base = os.path.join(proj, "s1", "subagents", f"agent-{tid}")
        with open(base + ".jsonl", "w") as f:
            f.write(assistant("s1", f"m-{tid}", (), tok) + "\n")
        with open(base + ".meta.json", "w") as f:
            json.dump({"agentType": t, "model": "sonnet", "toolUseId": tid}, f)
    return os.path.join(root, ".claude-test", "projects")


def run(*args):
    r = subprocess.run([sys.executable, "-I", SCRIPT, *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise AssertionError(f"exit {r.returncode}: {r.stderr}")
    return r.stdout


class ScanTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def scan_to(self, name, subagents):
        root = write_fixture(os.path.join(self.d, name), subagents)
        path = os.path.join(self.d, name + ".json")
        with open(path, "w") as f:
            f.write(run("--root", root, "--json"))
        return path

    def test_headline_gp_share(self):
        p = self.scan_to("a", [("t1", "general-purpose", "implement task 1", 100),
                               ("t2", "reviewer", "review task 1", 300)])
        with open(p) as f:
            h = json.load(f)["periods"]["window"]["headline"]
        self.assertEqual(h["agent_calls"], 2)
        self.assertEqual(h["gp_calls"], 1)
        self.assertEqual(h["gp_call_share_pct"], 50.0)
        self.assertEqual(h["sub_tokens"], 400)
        self.assertEqual(h["gp_sub_tokens"], 100)
        self.assertEqual(h["gp_token_share_pct"], 25.0)
        self.assertEqual(h["sub_tokens_by_type"], {"general-purpose": 100, "reviewer": 300})

    def test_compare_text(self):
        base = self.scan_to("base", [("t1", "general-purpose", "implement task 1", 300),
                                     ("t2", "reviewer", "review", 100)])
        cur = self.scan_to("cur", [("t1", "general-purpose", "implement task 1", 100),
                                   ("t2", "reviewer", "review", 300)])
        out = run("--compare", base, "--current", cur)
        self.assertRegex(out, r"gp_token_share_pct\s+75\.0\s+->\s+25\.0\s+\(-50\.0\)")
        self.assertIn("reviewer", out)

    def test_compare_json(self):
        base = self.scan_to("base", [("t1", "general-purpose", "x", 300)])
        cur = self.scan_to("cur", [("t1", "general-purpose", "x", 100)])
        cmp = json.loads(run("--compare", base, "--current", cur, "--json"))
        self.assertEqual(cmp["window"]["gp_sub_tokens"], {"base": 300, "current": 100, "delta": -200})

    def test_compare_handles_new_types(self):
        base = self.scan_to("base", [("t1", "general-purpose", "x", 300)])
        cur = self.scan_to("cur", [("t1", "general-purpose", "x", 100), ("t2", "implementer", "y", 50)])
        out = run("--compare", base, "--current", cur)
        self.assertRegex(out, r"implementer\s+new\s+->\s+50")


if __name__ == "__main__":
    unittest.main()
