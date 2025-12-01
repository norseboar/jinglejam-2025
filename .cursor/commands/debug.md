# Debug

Systematic debugging workflow for any bug, test failure, or unexpected behavior. Follows a four-phase framework (root cause investigation, pattern analysis, hypothesis testing, implementation) that ensures understanding before attempting solutions.

## When to Use

When the user reports:

- Bugs in the game
- Unexpected behavior
- Performance problems
- Crashes or errors
- Integration issues

**Use this ESPECIALLY when:**

- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- Multiple fixes have already been tried
- Previous fix didn't work
- You don't fully understand the issue

**Don't skip when:**

- Issue seems simple (simple bugs have root causes too)
- You're in a hurry (rushing guarantees rework)
- User wants it fixed NOW (systematic is faster than thrashing)

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

Follow the `.cursor/rules/superpowers/systematic-debugging.mdc` rule for automatic guidance on debugging principles.

## Process

You MUST complete each phase before proceeding to the next.

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read Error Messages Carefully**

   - Don't skip past errors or warnings
   - They often contain the exact solution
   - Read stack traces completely
   - Note line numbers, file paths, error codes

2. **Reproduce Consistently**

   - Can you trigger it reliably?
   - What are the exact steps?
   - Does it happen every time?
   - If not reproducible → gather more data, don't guess
   - **Stop and ask the user to reproduce the issue and provide the exact steps and error output**

3. **Check Recent Changes**

   - What changed that could cause this?
   - Review git diff, recent commits
   - Check for new dependencies, config changes
   - Look for environmental differences

4. **Gather Evidence in Multi-Component Systems**

   **WHEN system has multiple components:**

   **BEFORE proposing fixes, add diagnostic instrumentation:**

   ```
   For EACH component boundary:
     - Log what data enters component
     - Log what data exits component
     - Verify state at each layer

   Run once to gather evidence showing WHERE it breaks
   THEN analyze evidence to identify failing component
   THEN investigate that specific component
   ```

   **Stop and ask the user to add this instrumentation, run it, and provide the output**

5. **Trace Data Flow**

   **WHEN error is deep in call stack:**

   **REQUIRED:** Use the `.cursor/rules/superpowers/root-cause-tracing.mdc` rule for backward tracing technique

   **Quick version:**

   - Where does bad value originate?
   - What called this with bad value?
   - Keep tracing up until you find the source
   - Fix at source, not at symptom

### Phase 2: Pattern Analysis

**Find the pattern before fixing:**

1. **Find Working Examples**

   - Locate similar working code in same codebase
   - What works that's similar to what's broken?

2. **Compare Against References**

   - If implementing pattern, read reference implementation COMPLETELY
   - Don't skim - read every line
   - Understand the pattern fully before applying

3. **Identify Differences**

   - What's different between working and broken?
   - List every difference, however small
   - Don't assume "that can't matter"

4. **Understand Dependencies**
   - What other components does this need?
   - What settings, config, environment?
   - What assumptions does it make?

### Phase 3: Hypothesis and Testing Loop

**This is an iterative loop - repeat until hypothesis is verified:**

1. **Form Single Hypothesis**

   - State clearly: "I think X is the root cause because Y"
   - **Tell the user your hypothesis explicitly**
   - Write it down
   - Be specific, not vague

2. **Wait for User Confirmation Before Implementing**

   - **STOP and present your hypothesis to the user**
   - **DO NOT implement any code changes until user confirms the hypothesis is worth exploring**
   - **DO NOT make any fixes or test changes until user explicitly approves**
   - Wait for the user to respond
   - User may confirm the hypothesis is worth testing, suggest modifications, or indicate it's wrong

3. **Based on User Response:**

   **If user confirms hypothesis is worth testing:**

   - Make the SMALLEST possible change to test hypothesis
   - One variable at a time
   - Don't fix multiple things at once
   - **Stop immediately after making the change**
   - **Ask the user to verify manually and report the results**
   - **Wait for user to provide test results**

   **After receiving test results from user:**

   - **STOP and analyze the results**
   - **Explicitly ask the user: "Based on these test results, was the hypothesis verified? Should I proceed to implementation (Phase 4), or form a new hypothesis?"**
   - **You may form a new hypothesis, but DO NOT implement any code changes based on it until user confirms it's worth exploring**
   - **DO NOT proceed to Phase 4 without explicit user confirmation**
   - **Wait for user's explicit answer before taking any action**

   **If user indicates hypothesis is wrong or suggests modifications:**

   - Form a NEW hypothesis based on user feedback
   - Return to step 1 of this phase (present new hypothesis and wait for user confirmation before implementing)

   **If user confirms hypothesis is verified:**

   - Proceed to Phase 4 (Implementation)
   - **NEVER move to implementation until user has confirmed the hypothesis is verified**

4. **When You Don't Know**
   - Say "I don't understand X"
   - Don't pretend to know
   - Ask for help
   - Research more

### Phase 4: Implementation

**Fix the root cause, not the symptom:**

1. **Create Failing Test Case (if applicable)**

   - Simplest possible reproduction
   - One-off test script if helpful
   - MUST have before fixing
   - **Stop and ask the user to create a failing test case that reproduces the issue, then provide the output**

2. **Implement Single Fix**

   - Address the root cause identified
   - ONE change at a time
   - No "while I'm here" improvements
   - No bundled refactoring
   - **If fix requires Godot editor actions:** STOP and ask user to perform them (see Godot Editor Actions note below)

3. **Verify Fix**

   - **Stop immediately after making the change**
   - **Ask the user to verify manually:**
     - Does the original issue still occur?
     - Is the issue actually resolved?
     - Does it work as expected?
   - **Wait for user confirmation before proceeding**
   - **Do NOT make additional changes until user confirms this fix works**

4. **If Fix Doesn't Work**

   - STOP
   - Count: How many fixes have you tried?
   - If < 3: Return to Phase 1, re-analyze with new information
   - **If ≥ 3: STOP and question the architecture (step 5 below)**
   - DON'T attempt Fix #4 without architectural discussion

5. **If 3+ Fixes Failed: Question Architecture**

   **Pattern indicating architectural problem:**

   - Each fix reveals new shared state/coupling/problem in different place
   - Fixes require "massive refactoring" to implement
   - Each fix creates new symptoms elsewhere

   **STOP and question fundamentals:**

   - Is this pattern fundamentally sound?
   - Are we "sticking with it through sheer inertia"?
   - Should we refactor architecture vs. continue fixing symptoms?

   **Discuss with the user before attempting more fixes**

   This is NOT a failed hypothesis - this is a wrong architecture.

## Red Flags - STOP and Follow Process

If you catch yourself thinking:

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run tests"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Pattern says X but I'll adapt it differently"
- "Here are the main problems: [lists fixes without investigation]"
- Proposing solutions before tracing data flow
- **"One more fix attempt" (when already tried 2+)**
- **Each fix reveals new problem in different place**
- **Implementing code changes or fixes before user confirms hypothesis is worth exploring**
- **Making test changes or fixes based on a hypothesis without waiting for user approval**

**ALL of these mean: STOP. Return to Phase 1.**

**If 3+ fixes failed:** Question the architecture (see Phase 4.5)

## User Signals You're Doing It Wrong

**Watch for these redirections:**

- "Is that not happening?" - You assumed without verifying
- "Will it show us...?" - You should have added evidence gathering
- "Stop guessing" - You're proposing fixes without understanding
- "Ultrathink this" - Question fundamentals, not just symptoms
- "We're stuck?" (frustrated) - Your approach isn't working

**When you see these:** STOP. Return to Phase 1.

## Common Rationalizations

| Excuse                                         | Reality                                                                                     |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------- |
| "Issue is simple, don't need process"          | Simple issues have root causes too. Process is fast for simple bugs.                        |
| "Emergency, no time for process"               | Systematic debugging is FASTER than guess-and-check thrashing.                              |
| "Just try this first, then investigate"        | First fix sets the pattern. Do it right from the start.                                     |
| "I'll write test after confirming fix works"   | Untested fixes don't stick. Test first proves it.                                           |
| "Multiple fixes at once saves time"            | Can't isolate what worked. Causes new bugs.                                                 |
| "Reference too long, I'll adapt the pattern"   | Partial understanding guarantees bugs. Read it completely.                                  |
| "I see the problem, let me fix it"             | Seeing symptoms ≠ understanding root cause.                                                 |
| "One more fix attempt" (after 2+ failures)     | 3+ failures = architectural problem. Question pattern, don't fix again.                     |
| "I'll implement a fix to test this hypothesis" | Always wait for user to confirm hypothesis is worth exploring before implementing any code. |

## When Process Reveals "No Root Cause"

If systematic investigation reveals issue is truly environmental, timing-dependent, or external:

1. You've completed the process
2. Document what you investigated
3. Implement appropriate handling (retry, timeout, error message)
4. Add logging for future investigation

**But:** 95% of "no root cause" cases are incomplete investigation.

## Integration with Other Skills

**This command requires using:**

- **root-cause-tracing** - REQUIRED when error is deep in call stack (see Phase 1, Step 5). Follow the `.cursor/rules/superpowers/root-cause-tracing.mdc` rule.

**Complementary skills:**

- **defense-in-depth** - Add validation at multiple layers after finding root cause

## Godot Editor Actions

**IMPORTANT:** If a fix requires any action in the Godot editor, STOP and ask the user to perform it. Do not attempt to do it yourself.

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

1. **STOP immediately** when a fix requires Godot editor actions
2. **Clearly state** what needs to be done in the Godot editor
3. **Provide specific instructions** (which scene, which node, what to connect, etc.)
4. **Wait for user confirmation** that the editor action is complete
5. **Continue** only after the user confirms the editor work is done
