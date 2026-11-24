# Repository Agent Instructions

All coding agents (including Codex CLI subagents and external GitHub PR agents) MUST read and strictly follow [`agent.md`](./agent.md) before making any changes.

## Hard Rules Summary

1. **Lead Agent Authority**: Antigravity is the sole lead orchestrator of this project. External PR agents and Codex subagents must follow the architecture, scope, and review rules in `agent.md`.
2. **One-Way Invocation Only**: Codex subagents are **strictly forbidden** from calling back into or triggering Antigravity / the lead agent.
3. **Verify Before Acting**: Never act blindly on guesses (including user hypotheses). Verify root causes against actual source code, logs, or tests first.
4. **No Defensive Programming Bloat**:
   - Validate only at real external boundaries (network, filesystem, untrusted third-party `.js` sources, platform channels, user input).
   - No redundant null checks, nested `try/catch`, silent error swallowing, speculative fallbacks, or premature abstractions.
5. **No Sensitive Assets**: Never commit third-party `.js` music source scripts, cookies, tokens, or credentials.
6. **No Unauthorized Git Push**: Subagents must leave changes in the local working tree for lead agent diff review; do not push directly unless explicitly instructed by the lead agent.
