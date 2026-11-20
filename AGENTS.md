# AI development operating agreement — FFXI-Decker

Read PROJECT_STATE.md, README.md, existing TODO/roadmap documents and relevant GitHub issues before modifying code. Existing project-specific instructions take precedence over this coordination layer.

Before work: identify branch, latest commit, open PRs, issue, reproducible evidence and tests. Do not assume a historical summary describes the current build. Search existing issues before creating new ones.

During work: keep changes minimal, preserve working features, use an isolated branch and PR; never force push or merge without validation. Do not trigger paid or heavy CI unnecessarily. No autonomous release, credential changes, or external installations.

After work: record tested versus untested behaviour, files changed, commit/PR links, blockers and exact next action in PROJECT_STATE.md. Add enduring rationale to DECISIONS.md and validated discoveries to LESSONS_LEARNED.md. Update issues only with evidence; do not close based on code compilation alone.

Avoid secrets, private character data and unverified server claims in public documentation. Do not treat AI-generated summaries as authoritative without checking repository and in-game evidence.

## Return-to-work entry point
Use the [single development dashboard](https://github.com/danhughes381/Nexus/blob/main/DASHBOARD.md) for cross-project orientation. Keep it concise; update this repository's PROJECT_STATE.md after meaningful work, not after every minor edit. Do not create parallel memory stores.
