# Cross-plan seams (section 5)

Moved verbatim from SKILL.md section 5.

- **Contract first.** When two plans build on the same new contract (a
  protocol type, a tool definition, a table), one task lands it first on
  the build branch as a seam: the stub, the types, the parity tests. The
  dependent branch then rebases onto the build branch before its first
  task. Order it in the preflight table.
- **One commit across languages.** A change that must move together (a
  config key with its TypeScript twins and the Rust struct that reads it;
  a schema with its generated client) is one commit by one lane, even when
  it belongs to another plan. The parity tests refuse a half-done change,
  so splitting it makes both lanes red. Rule it in the preflight table:
  which lane does it, which branch rebases after, cost if wrong.
- **Whichever lands second wires both.** Rewrite that sentence into a
  ruling: name the lane that creates the shared file and the lane that must
  not.
