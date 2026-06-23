# ADR-0004: 24-Stage Pipeline Orchestrated by a Master Skill

## Status
Accepted (2026-06-22)

## Context
There are 75+ skills in the flutter-android ecosystem. Running them ad-hoc leads
to fragmented output and missed stages. We needed a deterministic sequence that:

- Covers the full app lifecycle from planning to store publishing.
- Produces hand-off artifacts at each stage (gate checks).
- Allows independent execution of individual skills for rework loops.
- Supports parallel execution where dependency-free.

Options:
1. **Master orchestrator skill (01) chains stages** — one skill orchestrates the
   stage sequence, dispatching to other skills.
2. **Makefile/Justfile rules** — file-based dependency graph.
3. **CI-only pipeline** — stages exist only in GitHub Actions.

## Decision
We chose the **master orchestrator skill** because:

- It can track state in `.flutter-pipeline/STATE.md` and resume after interruption.
- Skills retain their autonomy — they can run independently or as part of the flow.
- The orchestrator can make routing decisions based on token budget (skill 30)
  and skill performance data (skill 35).
- It works identically in local dev and CI (skill 21).
- Gate artifacts (index.json, telemetry.json, decisions.json, cost_model.json)
  are produced at deterministic stages and consumed downstream.
- Diff-scoped context loading (skill 27) lets the orchestrator decide what to
  re-read based on what changed.

## Consequences

- The pipeline map is documented in PIPELINE.md with stage-to-artifact-to-gate
  mappings.
- Skill 25 (Context Compression) and Skill 27 (Diff-Scoped Loader) feed the
  orchestrator with minimal context.
- Skill 28 (Skill Router) selects the next skill based on availability and cost.
- Skill 30 (Token Budget Governor) caps per-stage token consumption.
- Skill 35 (Skill Telemetry) records every stage run for cost-model refinement.
