---

name: prowler-github-review-flow
description: Use this skill when working in the GitHub-first review loop for this repository: GitHub hosts richer architecture and implementation context, external AI review happens against GitHub, Codex executes changes locally, and GitLab receives the final operationally relevant result. Use it for documentation shaping, review-flow discipline, anti-overengineering review, and deciding what belongs to GitHub-only context versus GitLab delivery.

---

# Prowler GitHub Review Flow Skill

## Purpose

Support the repository workflow where:

1. GitHub is the rich context and review remote.
2. ChatGPT or another reviewer reads GitHub and suggests improvements.
3. Codex implements the requested changes locally.
4. GitLab receives the final operationally relevant result.

## Core rule

Do not assume GitHub and GitLab should carry identical documentation.

Use this split:

- GitHub:
  - detailed technical explanation
  - architecture context
  - implementation rationale
  - richer maintenance notes
  - context intended for future specialist agents
- GitLab:
  - practical operational docs
  - low-noise delivery context
  - deployment-relevant information only

## Responsibilities

When this skill is active, the agent should:

- preserve the GitHub-first review loop
- keep documentation useful for external AI review
- identify overengineering early
- separate analysis material from delivery material
- keep the final delivery repository clean

## Prowler-specific guidance

For this repository, detailed GitHub context should usually explain:

- runtime architecture
- persistence model
- IRSA and StackSet design
- worker behavior and memory constraints
- scan grouping strategy
- remote strategy and documentation split
- future V2 direction

GitLab-facing docs should usually focus on:

- deploy flow
- maintenance flow
- required secrets
- runtime dependencies
- operational checks

## Future specialist agent profile

The future specialist agent reading GitHub should be able to understand:

- why Prowler App runs in Kubernetes
- why GitLab is not the scan runner
- why Postgres is the persistence layer
- why Valkey is treated as disposable broker state
- why scan grouping is preferred over broad all-at-once schedules
- why worker autoscaling is secondary to memory sizing and workload shaping
- why documentation split exists between remotes

## Anti-overengineering rules

Prefer:

- simple scan grouping
- explicit schedules
- stable memory sizing
- clear docs
- minimal runtime surface

Avoid proposing by default:

- event-driven orchestration layers
- extra queues or databases
- public MCP exposure
- broad platform abstractions
- excessive documentation in GitLab

## Trigger examples

Use this skill when the user asks for:

- GitHub-first documentation updates
- material for external AI review
- guidance on what should or should not go to GitLab
- future specialist-agent preparation
- anti-overengineering review for proposed features
