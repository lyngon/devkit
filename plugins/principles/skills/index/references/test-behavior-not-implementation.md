# Test behavior, not implementation

A test calls the code the way its users do and asserts the result they observe against a literal expected value.
A test that asserts which calls the code made, or restates a constant the code contains, does neither.

The check: before you keep a test, ask whether it would still pass if every function it imports returned `undefined`.
If yes, it observes no behavior and cannot fail for a defect.
Rewrite the assertion or delete the test.

**Why:** A test that cannot fail for a defect costs CI time and review attention and catches nothing.
A constant pin also fails when someone edits the constant or the prompt it restates, so it prevents that edit.

**Five shapes that still pass when every imported function returns `undefined`:**

- **Weak or no assertion.** No `expect`, or only `toBeDefined`, `toBeTruthy`, `not.toThrow`, `toBeInstanceOf`, `toBeGreaterThan(0)`.
- **Mock or absence only.** Only `toHaveBeenCalled`, `not.toHaveBeenCalled`, `toBeUndefined`, `toEqual([])`, `toHaveLength(0)`, `not.toBe(wrongValue)`.
- **Self-referential.** The expected value comes from the code under test: `expect(f(a)).toBe(f(a))`, `expect(parsed.url).toBe(buildUrl(...))`.
- **Constant pin.** The assertion restates a hand-maintained constant, config default, table row, or prompt string: `expect(LIMITS.maxTools).toBe(8)`, `expect(PROMPT).toContain("You are")`.
- **Fixture asserts fixture.** The assertion reads data the test built or a value computed in `beforeEach`, and the subject never runs inside the body.

**The fix:** call the subject inside the test body with one concrete input and assert the literal output or the observable effect, `expect(slugify("Hello, World!")).toBe("hello-world")`.
For an absence, assert the presence on the other input in the same test.
For a constant, test the mechanism that reads it with one input instead of restating the value.
For a mock, assert the payload it received or the state after the call, not that it was called.
When no such assertion exists, delete the test.

**Collaborators:** prefer real collaborators and fakes over mocks of your own code, and mock only what crosses the process boundary.
A mock of your own code asserts how the code is built, and a fake still runs the behavior.
A flaky test is a bug: fix it or delete it, never retry it.

**Keep** a test of a relation across a table's rows (a key present in two tables, a parent that exists), and a compile-time check in a `*.test-d.ts` file.
