"""Tests for scripts/claude-agent-model-guard, the PreToolUse hook (Agent).

Usage: python3 -I tests/test_claude_agent_model_guard.py
"""
import json
import os
import subprocess
import sys
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "claude-agent-model-guard")


def run_guard(stdin, subagent_model=None):
    """Run the guard with `stdin`; returns (returncode, stdout)."""
    env = {k: v for k, v in os.environ.items() if k != "CLAUDE_CODE_SUBAGENT_MODEL"}
    if subagent_model is not None:
        env["CLAUDE_CODE_SUBAGENT_MODEL"] = subagent_model
    p = subprocess.run([SCRIPT], input=stdin, capture_output=True, text=True, env=env)
    return p.returncode, p.stdout


def payload(**tool_input):
    return json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Agent",
                       "tool_input": {"description": "d", "prompt": "p", **tool_input}})


class AgentModelGuard(unittest.TestCase):
    def assertDenied(self, stdin, **kw):
        rc, out = run_guard(stdin, **kw)
        self.assertEqual(rc, 0)
        decision = json.loads(out)["hookSpecificOutput"]
        self.assertEqual(decision["hookEventName"], "PreToolUse")
        self.assertEqual(decision["permissionDecision"], "deny")
        self.assertIn("without an explicit model", decision["permissionDecisionReason"])

    def assertAllowed(self, stdin, **kw):
        self.assertEqual(run_guard(stdin, **kw), (0, ""))

    def test_denies_general_purpose_without_model(self):
        self.assertDenied(payload(subagent_type="general-purpose"))

    def test_denies_absent_subagent_type_without_model(self):
        self.assertDenied(payload())

    def test_denies_empty_subagent_type_and_empty_model(self):
        self.assertDenied(payload(subagent_type="", model=""))

    def test_allows_general_purpose_with_model(self):
        self.assertAllowed(payload(subagent_type="general-purpose", model="sonnet"))

    def test_allows_dedicated_agent_without_model(self):
        self.assertAllowed(payload(subagent_type="implementer"))

    def test_allows_when_subagent_model_env_set(self):
        self.assertAllowed(payload(subagent_type="general-purpose"), subagent_model="moonshotai/kimi-k3")

    def test_empty_subagent_model_env_does_not_exempt(self):
        self.assertDenied(payload(), subagent_model="")

    def test_garbage_stdin_fails_open(self):
        for stdin in ("", "not json", "[1, 2]", "null", '{"tool_input": "x"}'):
            with self.subTest(stdin=stdin):
                self.assertAllowed(stdin)


if __name__ == "__main__":
    unittest.main()
