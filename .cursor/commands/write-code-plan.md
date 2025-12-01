# Write Code Plan

Create a detailed implementation plan for LLM execution. Step-by-step instructions that a junior engineer (or fast/cheap LLM) could follow.

## Output Format

```markdown
# [Feature] Implementation Plan

**Goal:** One sentence describing what this builds.

**Parent Project:** `docs/projects/[project-name]/plan.md` — Milestone X
_(Include this line if this plan is part of a larger project. Remove if standalone.)_

---

## Status

- [ ] Task 1: Short name
- [ ] Task 2: Short name
- [ ] Task 3: Short name

---

## Summary

**Task 1: [Name]** — One line describing what this task does.

**Task 2: [Name]** — One line describing what this task does.

---

## Tasks

### Task 1: [Name]

**Files:** `path/to/file.gd` (use snake_case for filenames)

- [ ] **Step 1:** Description of what to do

[Code example if needed]

- [ ] **Step 2:** Description of next step

**Verify:** How to confirm this task works.

---

### Task 2: [Name]

[Same structure]

---

## Exit Criteria

- [ ] Criterion 1
- [ ] Criterion 2
```

## Process

### Step 1: Understand the Goal

**Ask yourself:**

- What exactly needs to be built?
- What does "done" look like?
- Are there existing patterns in the codebase to follow?

**Check context:**

- Review relevant existing code
- Check `.cursor/rules/` for coding standards
- Look at similar features for patterns to follow

### Step 2: Analyze the Codebase

**Before writing the plan, understand:**

- What files will be created or modified?
- What existing patterns should be followed?
- What utilities, types, or components already exist?

**Checklist:**

- [ ] Identified all files that need changes
- [ ] Found similar existing code to use as reference
- [ ] Checked relevant rules in `.cursor/rules/`
- [ ] Understood the data flow
- [ ] Verified naming conventions: filenames use snake_case, class/node names use PascalCase

### Step 3: Break Into Tasks

**Each task should be a logical unit:**

- Create a new file
- Add a new component/node
- Modify an existing function
- Update types/data structures

**Tasks should be ordered by dependency.** If Task 2 needs something from Task 1, Task 1 comes first.

**Example task breakdown:**

```
Feature: Add unit targeting system

Task 1: Add target selection data
- Create TargetType enum
- Add target field to unit data

Task 2: Create TargetSelector component
- Create scene file
- Add targeting logic

Task 3: Integrate with combat system
- Connect selector to attack flow
- Handle target validation
```

**Avoid repetition across multiple files:**

If the same change needs to be made to multiple files, consolidate into a single task with one example, then apply to all files.

**Good (consolidated):**

````
Task 1: Add on_click handler to unit scenes

**Files:** `scenes/units/warrior.tscn`, `scenes/units/archer.tscn`, `scenes/units/mage.tscn` (note: snake_case filenames)

- [ ] **Step 1:** Add on_click handler to `scripts/warrior.gd` as an example (note: snake_case filename):

```gdscript
func _on_click():
    unit_clicked.emit(self)
````

- [ ] **Step 2:** Apply the same pattern to `scripts/archer.gd` and `scripts/mage.gd` (note: snake_case filenames)

```

**Bad (repetitive):**

```

Task 1: Add on_click handler to Warrior

- Add on_click handler to warrior.gd

Task 2: Add on_click handler to Archer

- Add on_click handler to archer.gd

Task 3: Add on_click handler to Mage

- Add on_click handler to mage.gd

`````

(Note: Even in bad examples, filenames should use snake_case for consistency.)

**Rule of thumb:** If the work is substantially duplicated across multiple files (same pattern, same change), create one task with an example and then say "apply to all these files" rather than creating separate tasks for each file.

### Step 4: Write Detailed Steps

**Each step should be one action (2-5 minutes of work).**

**Good steps:**

- ✅ "Create `scripts/targeting/target_selector.gd` with the following structure:" (note: snake_case filename)
- ✅ "Add `target_type` field to the `UnitData` resource"
- ✅ "**Godot Editor:** Link `scripts/combat_manager.gd` to the CombatManager node in `scenes/game.tscn`" (note: snake_case filename, PascalCase node name)

**Naming Conventions:**

- **Filenames:** Always use snake_case (e.g., `unit.gd`, `combat_manager.gd`, `target_selector.gd`)
- **Class names:** Always use PascalCase (e.g., `class_name Unit`, `class_name CombatManager`, `class_name TargetSelector`)
- **Node names:** Always use PascalCase (e.g., `Unit`, `CombatManager`, `TargetSelector`)

When writing steps, ensure file paths use snake_case and class/node names use PascalCase.

**Bad steps:**

- ❌ "Implement the targeting system" (too vague)
- ❌ "Add targeting" (no specifics)
- ❌ "Update the files" (which files?)
- ❌ "Create the scene" (unclear if this is code or editor work)

**Godot Editor Actions:**

When a step requires work in the Godot editor, clearly mark it with **"Godot Editor:"** prefix and provide specific instructions. The executor will stop and ask the user to perform these actions.

**Examples of steps requiring Godot editor actions:**

- Creating new scene files (`.tscn`)
- Linking scripts to nodes
- Adding nodes to scenes
- Connecting signals in the editor
- Setting node properties in the inspector
- Creating resources (`.tres` files)
- Configuring scene tree structure
- Setting up export variables in the inspector

**Format for Godot editor steps:**

```markdown
- [ ] **Step X:** **Godot Editor:** [Clear instruction of what to do]

Example: Link `scripts/unit.gd` (snake_case filename) to the Unit node (PascalCase node name) in `scenes/unit.tscn` (snake_case filename):
1. Open `scenes/unit.tscn` in the Godot editor
2. Select the Unit node (root node)
3. In the Inspector, click the script icon next to the node name
4. Select `scripts/unit.gd` from the file dialog
```

### Step 5: Add Code Examples

**Include code examples when:**

- The pattern is complex or unfamiliar
- There are specific conventions to follow
- The executor might not know the right approach

**Code example format:**

````markdown
- [ ] **Step 1:** Create the target type enum in `scripts/data/enums.gd` (note: snake_case filename)

Add this after the existing enums:

```gdscript
enum TargetType {
    SELF,
    SINGLE_ENEMY,
    ALL_ENEMIES,
    SINGLE_ALLY,
    ALL_ALLIES
}
`````

**Naming in code examples:**

- File paths in steps: Use snake_case (e.g., `scripts/target_selector.gd`)
- Class names in code: Use PascalCase (e.g., `class_name TargetSelector`)
- Node names in steps: Use PascalCase (e.g., "the TargetSelector node")

````

**Skip code examples when:**

- The change is trivial (renaming, simple additions)
- The pattern is well-established in the codebase

### Step 6: Add Verification Steps

**Every task needs a way to confirm it works.**

**Good verification:**

```
**Verify:**
- Ask user to:
  - Run the game
  - Click on a unit
  - Verify the targeting UI appears
  - Select a target and confirm the action executes
```

**The executor will STOP after each task and ask the user to verify manually.**

### Step 7: Write Exit Criteria

**Exit criteria are the final checks before the feature is complete.**

```markdown
## Exit Criteria

- [ ] Targeting UI appears when selecting an ability
- [ ] Valid targets are highlighted
- [ ] Invalid targets cannot be selected
- [ ] Selected target receives the ability effect
- [ ] No errors in the console
```

### Step 8: Save the Plan

- For existing projects: `docs/projects/[project-name]/[feature]-plan.md`
- For standalone work: `docs/plans/YYYY-MM-DD-[feature].md`

## Reminders for the Executor

**Include these reminders in the plan for the executing LLM:**

At the top of the plan:

```markdown
> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.
```

After each task's steps:

```markdown
**After this task:** STOP and ask user to verify manually before continuing.
```

## Key Principles

- **Junior-engineer level** — Someone with no context should be able to follow this
- **One step = one action** — Don't bundle multiple changes
- **Exact file paths** — Never use vague references like "the script file"
- **Verification is mandatory** — Every task needs a way to confirm it works
- **Follow existing patterns** — Check `.cursor/rules/` for coding standards
- **Include reminders** — The executor needs to be reminded to stop and verify
- **Mark Godot editor actions** — Clearly identify steps that require Godot editor work so the executor knows to ask the user
- **Naming conventions** — Filenames must be snake_case (e.g., `unit.gd`), class and node names must be PascalCase (e.g., `class_name Unit`)
````
