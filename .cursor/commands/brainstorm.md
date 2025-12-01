# Brainstorm

Refine rough ideas into complete designs through collaborative dialogue. Question, explore alternatives, validate incrementally.

## Process

### Step 1: Understand the Idea

1. **Check project context first**
   - Review relevant files, documentation, and recent work
   - Understand the current project state before asking questions

2. **Ask questions one at a time**
   - Ask only ONE question per message
   - If a topic needs more exploration, break it into multiple questions
   - Prefer multiple choice questions (easier to answer), but open-ended is fine too
   - Focus on understanding: purpose, constraints, success criteria

**Good question patterns:**

- "What problem does this solve?"
- "Who/what is the user of this feature?"
- "What does success look like?"
- "Are there constraints I should know about?"

### Step 2: Explore Approaches

1. **Propose 2-3 different approaches with trade-offs**
   - Present options conversationally
   - Lead with your recommended option and explain why
   - Include trade-offs for each approach
   - Be honest about downsides

2. **Format for presenting approaches:**

   ```
   I see a few ways to approach this:

   **Option A: [Name]** (Recommended)
   [Description]
   - Pro: ...
   - Pro: ...
   - Con: ...

   **Option B: [Name]**
   [Description]
   - Pro: ...
   - Con: ...

   I'd recommend Option A because [reasoning]. What do you think?
   ```

3. **After user picks an approach, validate understanding**
   - Summarize the chosen approach
   - Confirm any remaining details

### Step 3: Present the Design

1. **Present the design in sections**
   - Break into chunks of 200-300 words each
   - After each section, ask: "Does this look right so far?"
   - Cover: architecture, components, data flow, key decisions
   - Be ready to go back and revise if something doesn't fit

## Key Principles

- **One question at a time** — Don't overwhelm with multiple questions
- **Multiple choice preferred** — Easier to answer than open-ended
- **Explore alternatives** — Always propose 2-3 approaches before settling
- **Incremental validation** — Present design in sections, validate each
- **YAGNI** — Remove unnecessary features from designs
- **Be flexible** — Go back and clarify when something doesn't make sense

## Example

User: "I want to add user authentication"

You: "Let me understand the project context first..."

[Check files, then ask one question at a time]

"First, what type of authentication do you need?
A) Simple username/password
B) OAuth (Google, GitHub, etc.)
C) Both options available
D) Something else"

[Continue with one question at a time until you understand, then explore approaches, then present design in sections]
