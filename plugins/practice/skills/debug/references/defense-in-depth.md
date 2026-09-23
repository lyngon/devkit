# Defense-in-depth validation

## Overview

When you fix a bug caused by invalid data, adding validation at one place feels sufficient.
But that single check can be bypassed by different code paths, refactoring or mocks.

**Core principle:** validate at every layer the data passes through.
Make the bug structurally impossible.

## Why multiple layers

Single validation: "we fixed the bug".
Multiple layers: "we made the bug impossible".

Different layers catch different cases:

- Entry validation catches most bugs
- Business logic catches edge cases
- Environment guards prevent context-specific dangers
- Debug logging helps when the other layers fail

## The four layers

### Layer 1: entry point validation

**Purpose:** reject obviously invalid input at the API boundary.

```typescript
function createProject(name: string, workingDirectory: string) {
  if (!workingDirectory || workingDirectory.trim() === '') {
    throw new Error('workingDirectory cannot be empty');
  }
  if (!existsSync(workingDirectory)) {
    throw new Error(`workingDirectory does not exist: ${workingDirectory}`);
  }
  if (!statSync(workingDirectory).isDirectory()) {
    throw new Error(`workingDirectory is not a directory: ${workingDirectory}`);
  }
  // ... proceed
}
```

### Layer 2: business logic validation

**Purpose:** ensure the data makes sense for this operation.

```typescript
function initializeWorkspace(projectDir: string, sessionId: string) {
  if (!projectDir) {
    throw new Error('projectDir required for workspace initialization');
  }
  // ... proceed
}
```

### Layer 3: environment guards

**Purpose:** prevent dangerous operations in specific contexts.

```typescript
async function gitInit(directory: string) {
  // In tests, refuse git init outside temp directories
  if (process.env.NODE_ENV === 'test') {
    const normalized = normalize(resolve(directory));
    const tmpDir = normalize(resolve(tmpdir()));

    if (!normalized.startsWith(tmpDir)) {
      throw new Error(
        `Refusing git init outside temp dir during tests: ${directory}`
      );
    }
  }
  // ... proceed
}
```

### Layer 4: debug instrumentation

**Purpose:** capture context for forensics.

```typescript
async function gitInit(directory: string) {
  const stack = new Error().stack;
  logger.debug('About to git init', {
    directory,
    cwd: process.cwd(),
    stack,
  });
  // ... proceed
}
```

## Applying the pattern

When you find a bug:

1. **Trace the data flow**: where does the bad value originate, and where is it used?
2. **Map all checkpoints**: list every point the data passes through.
3. **Add validation at each layer**: entry, business, environment, debug.
4. **Test each layer**: try to bypass layer 1 and verify that layer 2 catches it.

## Example

Bug: an empty `projectDir` caused `git init` in the source code directory.

**Data flow:**

1. Test setup produces an empty string
2. `Project.create(name, '')`
3. `WorkspaceManager.createWorkspace('')`
4. `git init` runs in `process.cwd()`

**Four layers added:**

- Layer 1: `Project.create()` validates not empty, exists, writable
- Layer 2: `WorkspaceManager` validates projectDir not empty
- Layer 3: `WorktreeManager` refuses git init outside the temp directory in tests
- Layer 4: stack trace logging before git init

**Result:** the whole suite passed and the bug became impossible to reproduce.

## Key insight

All four layers were necessary.
During testing, each layer caught bugs the others missed:

- Different code paths bypassed the entry validation
- Mocks bypassed the business logic checks
- Edge cases on different platforms needed the environment guards
- Debug logging identified structural misuse

**Do not stop at one validation point.**
Add checks at every layer.
