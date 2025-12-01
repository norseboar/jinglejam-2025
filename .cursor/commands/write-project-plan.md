# Write Project Plan

Create a high-level orchestration plan for a project or milestone. For human coordination, not LLM execution.

## Output Format

```markdown
# [Project Name] Plan

**Goal:** One sentence describing the outcome.

**Status:** Not Started | In Progress | Complete

---

## Status

- [ ] Milestone 1: Short name
- [ ] Milestone 2: Short name
- [ ] Milestone 3: Short name

---

## Summary

**Milestone 1: [Name]** — What this delivers in one sentence.

**Milestone 2: [Name]** — What this delivers in one sentence.

---

## Milestones

### Milestone 1: [Name]

**Key Deliverables:**

- Deliverable 1
- Deliverable 2

**Scope Boundaries:**

- What's included
- What's explicitly NOT included

---

### Milestone 2: [Name]

[Same structure]
```

## Process

### Step 1: Understand the Goal

**Ask yourself:**

- What is the user trying to accomplish overall?
- What does "done" look like for this project?
- Are there external constraints (timeline, dependencies, tech choices)?

**Check context:**

- Review existing docs in `docs/projects/` and `docs/long-term/`
- Look at related code to understand current state
- Note any existing patterns or conventions
- Verify naming conventions: filenames use snake_case, class/node names use PascalCase

### Step 2: Break Into Milestones

**Each milestone should:**

- Deliver working, testable functionality
- Be completable in a reasonable timeframe (days to a week, not months)
- Have clear boundaries — you know when it's done

**Questions to answer for each milestone:**

- What will exist when this is done?
- How will we know it works?
- What's explicitly NOT in this milestone?

**Example milestone breakdown:**

```
Project: Add user authentication

Milestone 1: Basic login flow
- User can log in with email/password
- Session persists across page refreshes
- NOT included: registration, password reset

Milestone 2: Registration
- User can create account
- Email validation
- NOT included: OAuth, password reset

Milestone 3: Password reset
- User can request reset email
- User can set new password
```

### Step 3: Define Deliverables

**Good deliverables are concrete:**

- ✅ "User model with email and password fields"
- ✅ "Login API endpoint that returns JWT"
- ✅ "Login form component with validation"
- ❌ "Authentication system" (too vague)
- ❌ "Make it secure" (not concrete)

**For each milestone, list 3-7 deliverables.**

### Step 4: Set Scope Boundaries

**Explicitly state what's NOT included.** This prevents scope creep.

```
**Scope Boundaries:**
- Included: Email/password login
- Included: Session persistence
- NOT included: OAuth providers (future milestone)
- NOT included: Two-factor auth (future milestone)
- NOT included: Admin user management
```

### Step 5: Write and Save

- Use the output format above
- Save to `docs/projects/[project-name]/plan.md` (use kebab-case for project-name)
- If updating an existing project, update the existing plan file

**Note on naming conventions:**

When referencing code files in deliverables or scope boundaries:
- Use snake_case for filenames (e.g., `unit.gd`, `combat_manager.gd`)
- Use PascalCase for class and node names (e.g., `Unit`, `CombatManager`)

## Key Principles

- **Deliverables, not tasks** — Focus on what will exist, not how to build it
- **Testable increments** — Each milestone should be independently verifiable
- **Clear boundaries** — Explicit scope prevents creep
- **No code examples** — This is coordination, not implementation
- **Naming conventions** — When referencing code files, use snake_case for filenames (e.g., `unit.gd`) and PascalCase for class/node names (e.g., `Unit`)
