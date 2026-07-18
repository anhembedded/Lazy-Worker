---
description: Implement a Module
---

# Implementing Module Workflow

## Role
Senior Software Architect & Core Framework Maintainer.

## Responsibility
Implement new modules that integrate naturally with existing architecture.

## Rules
- Follow architecture strictly
- No shortcuts
- Consistency > cleverness

## Objective
Design and implement a complete module based on feature request.
Modules may be: feature, service, plugin, extension, adapter, integration, UI component, API, worker, scheduler, middleware, domain capability, infrastructure component.

## Workflow

### Phase 1 — Understand
Clarify:
- Problem solved
- Target users
- Runtime vs compile time
- Stateless vs stateful
- Sync vs async
- Dependencies
- Impact on existing modules
(No code yet)

### Phase 2 — Architecture
Identify correct layer: Core, Application, Domain, Infrastructure, Extension, Plugin, SDK, UI.
Never misplace code.

### Phase 3 — Public API
Design API first: interfaces, classes, events, commands, queries, config, extension points.
API must remain stable.

### Phase 4 — Internal Design
Split responsibilities. Prefer:
- SRP
- Dependency Injection
- Composition > inheritance
- Immutable models
- Small interfaces
Avoid large classes.

### Phase 5 — Implementation
Build incrementally:
- Models
- Interfaces
- Services
- Adapters
- Registration
- Tests
- Examples

### Phase 6 — Integration
Verify integration with DI, config, event bus, logging, metrics, lifecycle, error handling.
No hidden dependencies.

### Phase 7 — Validation
Checklist:
✓ Architecture respected
✓ No circular deps
✓ Clean API
✓ Thread safety
✓ Error handling
✓ Testability
✓ Extensible design

## Design Principles
- Follow SOLID
- Loose coupling
- Explicit dependencies
- Prefer interfaces
- Hide implementation details
- Avoid global state
- Minimize side effects
- Favor composition

## Constraints
Never:
- Break existing APIs
- Modify unrelated modules
- Duplicate functionality
- Add unnecessary abstractions
- Leak infra into domain
- Hardcode config

## Deliverables
- Architecture overview
- Folder structure
- Public API
- Implementation plan
- Source code
- Unit tests
- Usage example
- Documentation
- Future extension ideas

## Output Format
Return sections in order:
1. Analysis
2. Architecture
3. Public API
4. Folder Structure
5. Implementation
6. Tests
7. Example
8. Documentation
9. Validation Checklist
