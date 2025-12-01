# Update Execution Workflow

Update execution workflow documentation to ensure consistency across planning and execution docs.

## Files to Review

**Commands:**

- `.cursor/commands/write-project-plan.md` — How to write orchestration plans
- `.cursor/commands/write-code-plan.md` — How to write execution plans (includes verification templates)
- `.cursor/commands/execute-plan.md` — How to execute plans

**Rules:**

- `.cursor/rules/core-rules.mdc` — The three non-negotiable rules
- `.cursor/rules/docs-workflow.mdc` — Plan format and testing guidance

## Process

### Step 1: Identify What's Changing

**Ask yourself:**

- What guidance is being updated?
- Which files contain related content?
- Are there templates or examples that need updating?

### Step 2: Review Each File for Consistency

**Check each file for:**

1. **Core rules alignment**

   - Does the file reinforce: follow plan exactly, stop after steps, don't guess?
   - Are there conflicting instructions?

2. **Verification workflow**

   - Is the process consistent (what agent does vs what user verifies)?
   - Are verification steps clearly defined?

3. **Plan format**

   - Does it match the Status → Summary → Tasks → Exit Criteria structure?
   - Are examples using the correct format?

4. **Cross-references**
   - If files reference each other, are they aligned?
   - Are file paths still correct?

### Step 3: Update Documentation

**For each file that needs updates:**

1. **Update guidance:**

   - Add explicit guidance about what to do
   - Add explicit guidance about what NOT to do
   - Include reasoning when it's not obvious

2. **Update templates and examples:**

   - Ensure examples use correct patterns
   - Remove outdated examples
   - Add examples showing correct workflow

3. **Update cross-references:**
   - If one doc references another, ensure they're aligned
   - Update file paths if they've changed

### Step 4: Verify Updates

**After making updates:**

- [ ] Cross-references between docs are accurate
- [ ] Examples in all docs reflect updated guidance
- [ ] All docs tell the same story about execution workflow
- [ ] Plan format is consistent across all docs

## Common Patterns to Look For

**Patterns that might need updating:**

- Outdated file paths
- Verification steps that don't match current workflow
- Plan format that doesn't match Status → Summary → Tasks structure
- Missing reminders about the three core rules
- Inconsistent guidance about stopping after steps

## Example Update Pattern

**Before (outdated):**

```markdown
**After this step:** Run tests and verify
```

**After (current):**

```markdown
**After this task:** STOP and ask user to verify manually before continuing.

**Verify:**

- Run the game
- Test [specific functionality]
- Report results before proceeding
```

## Key Principles

- **Consistency** — All docs should agree on workflow
- **Explicit** — State what to do AND what not to do
- **Reasoning** — Explain why when it's not obvious
- **Cross-reference alignment** — When docs reference each other, keep them in sync
