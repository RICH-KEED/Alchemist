# ADR-0001: Use Claude Code Plugin Format with Auto-Discovered Skills

## Status
Accepted (2026-06-20)

## Context
We needed to structure the flutter-android ecosystem as a set of capabilities that
can be composed organically. Options considered:

1. **Claude Code plugin format** — skill directories with SKILL.md instructions
   and scripts/, auto-discovered by the Claude Code harness via directory scanning.
2. **Hardcoded pipeline** — a monolithic script that calls each stage sequentially.
3. **MCP server** — a separate process that exposes tools via Model Context Protocol.

## Decision
We chose **Claude Code plugin format** because:

- Each skill lives in its own directory with a clear contract (SKILL.md).
- The harness auto-discovers skills by scanning the skills/ directory — no
  registration ceremony needed.
- Skill composition is declarative: the master orchestrator (skill 01) reads
  skill availability and chains them.
- Token economy: skills can be loaded on-demand rather than all at once.
- Standard Claude Code mechanisms (settings.json, hooks) apply uniformly.

## Consequences

- Skills are numbered 01–77 for stable ordering and reference.
- The pipeline is a 24-stage system (see PIPELINE.md), but skills can also run
  independently.
- Each skill may be updated/replaced independently — no coupled release cycle.
- Token-economy skills (25–30, 35) enable cost-aware routing and compression.
