---
doc_id: "ES-WIS-001"
title: "Work Item Service Executive Summary"
project: "Work Item Service"
audience: "Digital Platform Steering Committee"
owner: "Architecture Team"
business_owner: "VP, Digital Products"
revision: "1.1"
status: Approved
decision_status: Approved
decision_owner: "Digital Platform Steering Committee"
decision_record: "DR-WIS-001"
approval_reference: "DR-WIS-001: ES-WIS-001 revision 1.1 at source-control tag wis-arch-baseline-1.1"
evidence_status: partially-validated
evidence_rationale: "Business figures are estimates carried locally in this document because no separate business case or benefits register exists for this service. Need, benefits, delivery, and organizational impact were validated at the Phase 4 readiness review; investment remains a range estimate."
source_baseline: "wis-arch-baseline-1.1"
reconciled_through_phase: 4
last_validated: "2026-10-11"
supporting_evidence: "This document, plus the Architecture Guide, Architecture Specifications, and Infrastructure Architecture Guide listed under Evidence and Status"
coverage:
  need: { approach: local, rationale: "No separate Business Case exists; need is summarized here", owner: "VP, Digital Products", maturity: validated, target_phase: 4, reference: "This document", baseline: "1.1", validator: "VP, Digital Products", validation_status: validated, validation_reference: "DR-WIS-001" }
  benefits: { approach: local, rationale: "No separate Benefits Register exists; headline outcomes are carried here", owner: "Director, Engineering", maturity: provisional, target_phase: 4, reference: "This document", baseline: "1.1", validator: "Director, Engineering", validation_status: partially-validated, validation_reference: "DR-WIS-001", disposition: conditioned, authority: "Digital Platform Steering Committee", authorization_reference: "DR-WIS-001" }
  investment: { approach: local, rationale: "No external financial record exists for this service; ranges are carried here", owner: "Finance Business Partner", maturity: provisional, target_phase: 4, reference: "This document", baseline: "1.1", validator: "Finance Business Partner", validation_status: partially-validated, validation_reference: "DR-WIS-001", disposition: conditioned, authority: "Digital Platform Steering Committee", authorization_reference: "DR-WIS-001" }
  delivery: { approach: local, rationale: "Headline milestones only; no separate delivery plan exists for this service", owner: "Delivery Lead", maturity: validated, target_phase: 4, reference: "This document", baseline: "1.1", validator: "Delivery Lead", validation_status: validated, validation_reference: "DR-WIS-001" }
  organizational_impact: { approach: local, rationale: "Material to operations and to product teams that adopt the service", owner: "Platform Engineering Lead", maturity: validated, target_phase: 4, reference: "This document", baseline: "1.1", validator: "Platform Engineering Lead", validation_status: validated, validation_reference: "DR-WIS-001" }
checks:
  - { phase: 3, date: "2026-10-09", source_baseline: "wis-arch-baseline-1.0", reviewer_roles: ["Lead Architect", "Platform Engineering Lead"], result: no-change, disposition: "Reconciled against Architecture Guide, Architecture Specifications, and Infrastructure Architecture Guide; no material change." }
  - { phase: 3, date: "2026-10-11", source_baseline: "wis-arch-baseline-1.1", reviewer_roles: ["Lead Architect", "Platform Engineering Lead"], result: updated, disposition: "Work item data store (Azure Cosmos DB) brought inside the service; build and run estimates updated; data store dependency removed from conditions and risks." }
  - { phase: 4, date: "2026-10-11", source_baseline: "wis-arch-baseline-1.1", reviewer_roles: ["Lead Architect", "Platform Engineering Lead"], result: no-change, disposition: "Phase 4 readiness review completed; approved for implementation and infrastructure delivery." }
unknowns: []
---

# Executive Summary - Work Item Service

## Decision / Sponsorship Needed

**Ask:** None. The Digital Platform Steering Committee approved the Work Item Service for Phase 5 build and infrastructure delivery on 2026-10-11, including a one-time funding envelope of $210K–$270K (decision record DR-WIS-001).

**Recommendation:** Build one shared Work Item Service that Momentum Rocket Skates' product applications call, instead of continuing to embed work tracking in each application.

**Decision owner:** Digital Platform Steering Committee

**Decision status:** Approved

**Conditions:** Network isolation for production is dispositioned before production go-live (see [Architecture Specifications](architecture-specifications.md), item OI-003).

Without the shared service, two planned applications would build their own, separate work tracking. The most important uncertainty is how quickly product teams adopt the service, which this initiative does not control.

## Why This Matters Now

Four Momentum Rocket Skates product applications each contain their own work tracking logic: how to create, assign, and complete a task. The implementations differ, so users see inconsistent behavior and each team maintains the same kind of code separately. Two more applications are planned for FY27, which would raise the count to six.

A second problem is infrastructure lead time. Standing up the infrastructure for a new service has historically taken about two weeks, and development cannot start until it exists. This service is the first to provision its infrastructure from its approved architecture documents.

## Expected Outcomes and Value

Figures are estimates until measured, and are labeled as such.

| Outcome | Current baseline | Proposed target | Benefit owner | Realization window | Confidence |
|---|---|---|---|---|---|
| Fewer duplicate work tracking implementations | 4 in production | 1 shared service, with applications migrating | Director, Engineering | Two quarters after production go-live | Medium |
| Effort for an application to add work tracking | About 6 engineer-weeks | About 1 engineer-week | Director, Engineering | First new application after go-live | Medium |
| Infrastructure lead time for this service | About 2 weeks | 2 working days to a ready development environment | Platform Engineering Lead | At Phase 5 start | Medium |

Actual results are measured separately after delivery.

## Recommended Direction and Alternatives

The recommended direction is a shared, event-driven service with a single API for creating and managing work items, and asynchronous reactions (notifications and audit history) that do not slow down the caller. The architecture is described in the [Architecture Guide](architecture-guide.md) and [Architecture Specifications](architecture-specifications.md).

- **Business as usual:** each team keeps its own implementation. This avoids upfront cost but keeps the duplication and inconsistency described above.
- **Buy a work management product:** not evaluated in depth. It is listed so the option is visible, not because it has been ruled out.
- **Build the shared service (recommended):** consolidates the logic once and lets teams integrate through one API.

## Investment, Capacity, and Timing

- **One-time build:** $210K–$270K estimate, provisional maturity. It includes provisioning the work item data store.
- **Run cost:** $4K–$7K per month across development, qa, and production (estimate, provisional).
- **Funding state:** approved from the FY27 platform budget by the Digital Platform Steering Committee on 2026-10-11 (DR-WIS-001).
- **First milestone:** a ready development environment within 2 working days of the approved Infrastructure Architecture Guide.
- **Value window:** begins after production go-live and is separate from the delivery milestones above.

## Business and Organizational Impact

Platform Engineering operates the service, including its data store and the review of messages that fail processing. Product teams change their applications to call the shared API, which is planned over two quarters after go-live. A Service Operator role is introduced to monitor health and handle failed messages.

## Leadership Risks, Trade-offs, and Confidence

- **Data store cost and capacity:** the data store is billed by usage in this design, so cost follows adoption. Its capacity mode is revisited before production go-live (see [Architecture Specifications](architecture-specifications.md), OI-005).
- **Adoption pace:** value depends on product teams migrating. Migration timing is not controlled by this initiative.
- **Reliability of event publication:** how the service guarantees that a saved change is always announced is an open design decision (OI-002). The current design accepts rare delays that are detected and repaired.
- **Network isolation:** the baseline relies on identity controls, not private networking. Production hardening is a tracked decision (OI-003).

Confidence is medium. The architecture is stable, while business figures are provisional.

## Evidence and Status

Baseline `wis-arch-baseline-1.1`; business estimates partially validated, approved 2026-10-11 (DR-WIS-001); last validated 2026-10-11; supporting documents: [Architecture Guide](architecture-guide.md), [System Context & Logical Components](system-context.md), [Architecture Specifications](architecture-specifications.md), [Infrastructure Architecture Guide](infrastructure-architecture-guide.md), [Process Flow](process-flow-work-item-creation-and-assignment.md).
