---
name: linear-implementer
description: Implements a feature based on a Linear ticket specification. Use when a Linear ticket contains a comprehensive specification (Goal, Context, Implementation Steps, Acceptance Criteria) and you need to autonomously implement the feature. Assumes project context is already understood.
---

# Linear Implementer

## Overview

Autonomously implement features based on comprehensive Linear ticket specifications. This skill reads a specification from Linear, implements each step systematically, runs tests, and updates the ticket status upon completion.

**Prerequisites**: The Linear ticket must contain a comprehensive specification with Goal, Context, Implementation Steps, and Acceptance Criteria (typically created by the linear-spec skill).

## Workflow

### 1. Read the Specification

**Infer ticket from branch name**: The current git branch name should be the Linear ticket ID (e.g., `ABC-123`). Use `git branch --show-current` to get it.

Use linearis CLI to read the ticket:
- `linearis issues read <branch-name>` to get issue details using the branch name as ticket ID
- Parse the specification sections: Goal, Context, Implementation Steps, Acceptance Criteria
- Verify specification completeness before proceeding

**IMPORTANT**: If the specification is incomplete, vague, or missing critical details, STOP and inform the user. Do not proceed with implementation. Suggest using the linear-spec skill first.

### 2. Plan the Implementation

Before writing code:
- Review the Context section for relevant files and patterns
- Identify all files that need modification
- Understand dependencies and architecture patterns
- Create a mental model of the changes

**DO NOT skip this step.** Rushing into implementation without understanding the full scope leads to errors.

### 3. Implement Systematically

Follow the Implementation Steps from the specification exactly:

1. **Work through steps sequentially** - Do not skip ahead or reorder
2. **For each step**:
   - Read the relevant file(s) mentioned
   - Understand existing code structure
   - Make the specified changes
   - Verify the change matches the step description
3. **Follow project patterns** - Use existing code as reference
4. **Handle errors** - Implement error handling as specified

### 4. Verify Implementation

After completing all implementation steps:

1. **Review changes** - Ensure all steps were completed
2. **Run tests** - Execute relevant test suites
3. **Check acceptance criteria** - Verify each criterion is met
4. **Test edge cases** - Validate error handling and edge cases
5. **Build/compile** - Ensure the project builds successfully (if applicable)

### 5. Update Linear Ticket

Once implementation is complete and verified:

1. **Update ticket status** using `linearis issues update <issueId> -s <state>`:
   - Change status to "In Review" or "Done" (based on project workflow)
   - Or move to appropriate next state

2. **Add implementation comment** using `linearis comments create <issueId> --body <body>`:
   - Summarize what was implemented
   - Note any deviations from the spec (if any)
   - Link to relevant commits or PRs (if applicable)
   - Mention test results

## Implementation Guidelines

### Reading Specifications

**Expected specification format:**
```
## Goal
[What needs to be achieved and why]

## Context
- Relevant Files: [file paths]
- Related Code: [functions/classes to reference]
- Architecture Patterns: [patterns to follow]
- Dependencies: [libraries/modules to use]

## Implementation Steps
1. [Action] in path/to/file
   - [Specific details]
2. [Action] in path/to/another-file
   - [Specific details]

## Acceptance Criteria
- Functional: [user-facing behavior]
- Technical: [code requirements]
- Testing: [test requirements]
- Edge Cases: [error handling]
```

**If specification is missing any section**, ask the user whether to:
- Proceed with best judgment
- Request specification update
- Use linear-spec skill to enhance the ticket

### Working with Files

**Read before writing:**
- Always read files before modifying them
- Understand the existing structure and patterns
- Identify where to add new code

**Make targeted changes:**
- Edit existing files rather than rewriting
- Preserve existing code style and formatting
- Follow established patterns in the codebase

**Verify changes:**
- Re-read modified files to confirm changes
- Ensure no syntax errors introduced
- Check imports and dependencies are correct

### Testing Approach

**Run tests at appropriate checkpoints:**
- After completing related implementation steps
- After completing all implementation
- Before marking the ticket as done

**Test execution:**
- Run unit tests for modified components
- Run integration tests if specified
- Run full test suite if changes are significant
- Report any test failures immediately

**If tests fail:**
- Analyze the failure
- Fix the implementation
- Re-run tests
- Do not proceed to next steps until tests pass

## Linearis CLI Usage

**Reading tickets:**
- `linearis issues read <issueId>` - Get issue details (supports UUID and identifiers like ABC-123)
- `linearis issues search <query>` - Search issues by text
  - Options: `--team`, `--project`, `--states`, `--limit`
- Read description for specification
- Read comments for additional context

**Updating tickets:**
- `linearis issues update <issueId>` - Update issue fields
  - `-s, --state <stateId>` - New state name or ID
  - `-p, --priority <priority>` - New priority (1-4)
  - `-d, --description <desc>` - New description
- Common status transitions: "In Progress" → "In Review" → "Done"

**Adding comments:**
- `linearis comments create <issueId> --body <body>` - Document implementation progress
- Use for: completion notes, deviation explanations, test results
- Supports markdown formatting

## Best Practices

**Understand before implementing:**
- Read the entire specification first
- Identify all affected files
- Understand the dependencies
- Don't start coding immediately

**Follow the specification exactly:**
- Implement steps in the specified order
- Use specified file paths, function names, and data types
- Don't deviate without good reason
- If you must deviate, document why in Linear comments

**Maintain code quality:**
- Follow existing code style and conventions
- Add appropriate error handling
- Write clear, self-documenting code
- Don't introduce technical debt

**Test thoroughly:**
- Run tests before marking as complete
- Test both happy path and edge cases
- Verify all acceptance criteria are met
- Don't skip testing to save time

**Communicate progress:**
- Update Linear ticket status as you progress
- Add comments for significant milestones
- Note any blockers or issues encountered
- Keep stakeholders informed

**Handle ambiguity:**
- If specification is unclear, ask the user
- Don't make assumptions about critical details
- Suggest specification improvements for future tickets
- Document any interpretation decisions made

## Error Handling

**If specification is incomplete:**
- List what's missing
- Ask user whether to proceed or update spec
- Suggest using linear-spec skill

**If implementation encounters issues:**
- Document the issue in Linear comments
- Explain what was attempted
- Ask user for guidance if blocked
- Don't silently work around problems

**If tests fail:**
- Report the failure details
- Analyze root cause
- Fix the implementation
- Don't mark ticket as done with failing tests

**If acceptance criteria can't be met:**
- Explain which criteria can't be met and why
- Propose alternatives or spec amendments
- Get user approval before proceeding differently
- Update the ticket with outcomes
