---
title: "Work Item Service Architecture Guide"
system: "Work Item Service"
version: "1.1"
status: "Approved"
document_owner: "Architecture Team"
last_reviewed: "2026-10-11"
reconciled_through_phase: 4
source_baseline: "wis-arch-baseline-1.1"
review_trigger: "Material change to purpose, outcomes, vision, principles, capabilities, drivers, or defining approach"
evidence_status: "Reconciled"
---

# Work Item Service Architecture Guide

> **Audience:** All stakeholders. This guide explains architectural intent and points to the authoritative detail. It is reconciled at the end of each architecture phase; update content only for material, verified changes.

## Reader Questions

| Reader | Question this guide answers |
|---|---|
| Executive or product stakeholder | What is the architectural direction, and why does it matter? |
| Developer | Which principles and defining approaches guide design? |
| Platform or operations | Which operational qualities materially shape the architecture? |
| Architect or ARB reviewer | Which drivers and trade-offs require deeper review? |

## Architecture at a Glance

The Work Item Service gives Momentum Rocket Skates' applications one shared place to create, assign, and track units of work. It is built around a small set of request-driven operations that change work items, and independent reactions that respond to those changes without slowing the caller. The highest-priority drivers are easy reuse by many applications, trustworthy history of every change, and an environment that can be provisioned quickly and repeatably from approved documents ([Executive Summary](executive-summary.md)).

## Purpose and Stakeholder Outcomes

Today, several Momentum Rocket Skates applications each maintain their own work tracking logic. The architectural purpose of the Work Item Service is to replace that duplication with one consistent service that applications call. Product teams benefit by integrating once instead of rebuilding; end users benefit from consistent behavior across applications; and platform operators benefit from one service to monitor instead of many.

The service enables people to be told when work is assigned or completed, and gives the organization a reliable record of what happened to each work item and when.

Business need, expected outcomes, and the funding request are summarized in the [Executive Summary](executive-summary.md). No separate business case or benefits register is maintained for this service.

## Architectural Vision

The Work Item Service is the single authoritative place where a work item's current state is decided. Everything that follows from a change, such as telling someone or recording history, happens as a reaction to an announced change instead of as part of the request that caused it. Callers get fast, predictable responses; reactions can be added, changed, or retried without touching the core operation.

The architecture favors small, independently understandable parts, identity-based trust over stored credentials, and infrastructure that is declared in a form that can be reviewed and reproduced exactly.

## Guiding Principles

| ID | Principle | Implication |
|---|---|---|
| P-1 | One authoritative home for work items. | Applications never keep their own copy of work item state; they ask the service. |
| P-2 | Announce change; react asynchronously. | Notifications, history, and future reactions are triggered by announced events, never by the original request waiting on them. |
| P-3 | Expect repeats; make reactions safe to repeat. | Every reaction must give the same result if the same announcement arrives more than once. |
| P-4 | Trust identity, not stored secrets. | Services and callers prove who they are with identity. Credentials are not placed in code or configuration where identity can be used. |
| P-5 | Reproducible by design. | Infrastructure is declared, reviewed, and generated consistently, so the same description always produces the same result. |
| P-6 | Observable by default. | A single request can be followed from the caller through every reaction it triggers. |

## Capability Narrative

- **Capture work:** a person or application can record a new unit of work with the information needed to act on it.
- **Assign and hand off:** work can be given to a responsible person and reassigned as circumstances change.
- **Track progress:** each work item moves through a defined lifecycle, so everyone sees the same state.
- **Stay informed:** the right people are told when work is assigned to them or completed.
- **Trace history:** the organization can see what happened to a work item, in order, after the fact.
- **Integrate easily:** a new application can start using work tracking through one consistent interface.

## How the Service Works - Conceptually

A person works in an application, and the application asks the Work Item Service to create or change a work item. The service checks the request, records the new state, and announces what happened. The caller receives a response as soon as the change is recorded.

Independently, other parts of the service hear the announcement and do their own work: one tells the people concerned, another writes an entry in the work item's history. If one of these reactions has a problem, it is retried and, if it still fails, set aside for a person to review, without affecting the change that was already made or the caller.

Authoritative boundaries and relationships: [System Context & Logical Components](system-context.md). Detailed behavior: [Process Flow](process-flow-work-item-creation-and-assignment.md).

## Architecture Drivers and Trade-offs

| Driver or concern | Why it matters | Material tension | Driver evidence | Design response or decision |
|---|---|---|---|---|
| D-1: Reuse across many applications | Value depends on teams adopting one service instead of building their own. | A shared service must stay simple to adopt while serving varied needs. | [Executive Summary](executive-summary.md) (Expected Outcomes and Value) | [Architecture Specifications](architecture-specifications.md) (components CMP-001 to CMP-004) |
| D-2: Responsive callers despite follow-on work | Callers should not wait for notifications or history. | Asynchronous reaction means reactions complete slightly later than the change. | [Process Flow](process-flow-work-item-creation-and-assignment.md) | [Architecture Specifications](architecture-specifications.md) (quality scenario Q-003, interactions INT-004 to INT-007) |
| D-3: Trustworthy history | People and auditors rely on an accurate record of changes. | Guaranteeing that every saved change is announced is an open decision. | [System Context & Logical Components](system-context.md) (LR-004) | [Architecture Specifications](architecture-specifications.md) (OBL-002, OBL-003, OI-002) |
| D-4: Fast, repeatable environments | Waiting two weeks for infrastructure delays development. | Generating infrastructure consistently requires a precise, reviewed specification. | [Executive Summary](executive-summary.md) (Expected Outcomes and Value) | [Infrastructure Architecture Guide](infrastructure-architecture-guide.md) (IG-017, IG-018) |
| D-5: Operable by a small team | A small platform team must run the service across environments. | Simplicity of operation is traded against network isolation (deferred). | [Executive Summary](executive-summary.md) (Business and Organizational Impact) | [Architecture Specifications](architecture-specifications.md) (OBL-007, OBL-009, OI-003) |

## Where to Go Next

| Reader question | Status | Authoritative document |
|---|---|---|
| What is the recommendation and current ask? | Available | [Executive Summary](executive-summary.md) |
| Where are the system boundaries and relationships? | Available | [System Context & Logical Components](system-context.md) |
| What are the components, interactions, and measurable quality requirements? | Available | [Architecture Specifications](architecture-specifications.md) |
| How does the service behave from request to reaction? | Available | [Process Flow](process-flow-work-item-creation-and-assignment.md) |
| How is the infrastructure designed and secured? | Available | [Infrastructure Architecture Guide](infrastructure-architecture-guide.md) |

## Reconciliation Record

| Phase | Check date | Source baseline | Sources checked | Material changes or linked disposition of deferred items | Architect |
|---|---|---|---|---|---|
| Phase 1 | 2026-09-14 | wis-arch-baseline-0.1 | [Executive Summary](executive-summary.md), [System Context & Logical Components](system-context.md) | Initial guide created | Lead Architect |
| Phase 2 | 2026-09-28 | wis-arch-baseline-0.9 | [Architecture Specifications](architecture-specifications.md), [Process Flow](process-flow-work-item-creation-and-assignment.md) | Added D-3 evidence link; no change to principles | Lead Architect |
| Phase 3 | 2026-10-09 | wis-arch-baseline-1.0 | [Infrastructure Architecture Guide](infrastructure-architecture-guide.md) | No material change. Network isolation deferral tracked as OI-003 in [Architecture Specifications](architecture-specifications.md) | Lead Architect |
| Phase 3 (change) | 2026-10-11 | wis-arch-baseline-1.1 | [System Context & Logical Components](system-context.md), [Architecture Specifications](architecture-specifications.md), [Infrastructure Architecture Guide](infrastructure-architecture-guide.md) | Work item data store brought inside the service. No change to purpose, principles, capabilities, or drivers | Lead Architect |
| Phase 4 | 2026-10-11 | wis-arch-baseline-1.1 | All architecture documents in this package | Approved for implementation and infrastructure delivery. No material change | Lead Architect |
