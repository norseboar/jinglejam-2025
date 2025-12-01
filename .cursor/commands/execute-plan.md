# Execute Plan

Execute a code plan step-by-step. Follow the plan exactly, stop after each task, never guess.

## Before Starting

1. Read `.cursor/rules/core-rules.mdc` — The three rules are non-negotiable
2. Read the plan thoroughly — Note the Status, Summary, Tasks, and Exit Criteria sections
3. Check if the plan references a parent project plan — You'll need to update that when done
4. Raise any concerns BEFORE starting — If anything is unclear or seems wrong, STOP and ask

## Step 1: Read and Review

**Read the entire plan and understand:**

- What is the goal?
- What tasks need to be completed?
- What are the exit criteria?
- Is there a parent project plan referenced?

**If anything is unclear:** STOP and ask. Don't start with uncertainty.

**If the plan looks good:** Proceed to Step 2.

## Step 2: Execute Tasks

**For each task, follow this cycle:**

### 2a. Start the Task

- Mark the task as in-progress (use `todo_write` or note it)
- Read all the steps in the task before starting

### 2b. Execute Each Step

- Follow each step exactly as written
- Don't skip steps
- Don't combine steps
- Don't "improve" on the plan

**STOP if:**

- You don't understand an instruction
- Something seems wrong
- You hit a blocker (missing file, unexpected error)
- You're about to make an assumption about product behavior
- You need to guess about anything
- **The step requires Godot editor actions** (see Godot Editor Actions section below)

**When blocked:** Ask for help. Don't force through.

### Godot Editor Actions

**IMPORTANT:** If a step requires any action in the Godot editor, STOP and ask the user to perform it. Do not attempt to do it yourself.

**Examples of Godot editor actions that require user assistance:**

- Creating a new scene file (`.tscn`)
- Linking a script to a node in a scene
- Adding nodes to a scene
- Connecting signals in the editor
- Setting node properties in the inspector
- Creating resources (`.tres` files)
- Configuring scene tree structure
- Setting up export variables in the inspector
- Any visual/editor-based configuration

**What to do:**

1. **STOP immediately** when you encounter a step requiring Godot editor actions
2. **Clearly state** what needs to be done in the Godot editor
3. **Provide specific instructions** (which scene, which node, what to connect, etc.)
4. **Wait for user confirmation** that the editor action is complete
5. **Continue** only after the user confirms the editor work is done

**Example:**

```
Step requires Godot editor action:

I need you to link the script `scripts/Unit.gd` to the Unit node in `scenes/Unit.tscn`:
1. Open `scenes/Unit.tscn` in the Godot editor
2. Select the Unit node (root node)
3. In the Inspector, click the script icon next to the node name
4. Select `scripts/Unit.gd` from the file dialog

Please confirm when this is done, and I'll continue with the next step.
```

### 2c. After Completing the Task

1. **Go back to the plan document**
2. **Check off all completed steps** in this task (`- [ ]` → `- [x]`)
3. **Check off the task** in the Status section at the top (`- [ ]` → `- [x]`)
4. **Add ✅ to the task heading:** `### Task 1: Name` → `### ✅ Task 1: Name`
5. **STOP and report to the user:**
   - What you implemented
   - Any issues encountered
   - Ask user to verify manually before continuing
6. **Wait for user confirmation** — Do not continue automatically

### 2d. Continue or Stop

- **If user confirms:** Move to the next task, repeat from 2a
- **If user has feedback:** Address it before moving on
- **If verification fails:** Debug with user before continuing

**Batch size:** Default is one task at a time. If user requests larger batches, complete the requested number before stopping.

## Step 3: Verify Exit Criteria

**After all tasks are complete:**

1. Go through each exit criterion in the plan
2. For each criterion, confirm how it was met
3. Report to user:
   ```
   Exit Criteria:
   ✓ [Criterion 1] — Met by [how]
   ✓ [Criterion 2] — Met by [how]
   ```
4. Ask user for final verification

## Step 4: Complete the Plan

**After user confirms everything works:**

1. **Mark the plan as complete:**

   - Add ✅ to the plan title: `# Feature Plan` → `# ✅ Feature Plan`
   - Ensure all task checkboxes and headings have ✅

2. **Update the parent project plan (if referenced):**

   - Open the referenced project plan (e.g., `docs/projects/[project]/plan.md`)
   - Check off the milestone or task that this code plan fulfilled
   - Add a note with the completion date if helpful

3. **Commit the changes** (if user approves)

---

## The Three Rules (Reminder)

**1. Follow the plan exactly.** Don't deviate. Don't improve. Don't "fix" things.

**2. Stop after each task.** Report. Wait. Don't continue automatically.

**3. Don't guess.** If uncertain about anything—especially product behavior—ask.

---

## Note for Code Plans

Code plans that are part of a larger project should reference the parent project plan at the top:

```markdown
# [Feature] Implementation Plan

**Goal:** ...

**Parent Project:** `docs/projects/[project-name]/plan.md` — Milestone X

---
```

This makes it easy to update the project plan when the code plan is complete.
