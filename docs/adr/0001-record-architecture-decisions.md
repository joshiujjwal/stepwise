# 1. Record architecture decisions

Date: 2026-06-06
Status: Accepted

## Context
We need a durable, low-friction record of significant architectural decisions so future contributors
(human and AI) understand the "why" behind the design.

## Decision
We use **Architecture Decision Records** (ADRs), as described by Michael Nygard. Each ADR is a short,
numbered markdown file in `docs/adr`. Statuses: Proposed, Accepted, Superseded.

## Consequences
Decisions are discoverable and reversible with context. A new significant decision adds a new ADR rather
than rewriting history; superseding ADRs link back to what they replace.
