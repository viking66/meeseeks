---
name: test-driven-development
description: Use when implementing any feature or bugfix in Haskell or PureScript, before writing implementation code. Applies to both backend (Haskell/hspec) and frontend (PureScript/purescript-spec) development.
---

# Test-Driven Development (TDD) for Haskell & PureScript

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

**Always:**
- New features
- Bug fixes
- Refactoring
- Behavior changes

**Exceptions (ask your human partner):**
- Throwaway prototypes
- Generated code
- Configuration files

Thinking "skip TDD just this once"? Stop. That's rationalization.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

## Red-Green-Refactor

### RED - Write Failing Test

Write one minimal test showing what should happen.

<Good>
```haskell
spec :: Spec
spec = do
    describe "retryOperation" $ do
        it "retries failed operations 3 times" $ do
            ref <- newIORef (0 :: Int)
            let operation = do
                    modifyIORef ref (+ 1)
                    n <- readIORef ref
                    if n < 3
                        then throwIO (userError "fail")
                        else pure "success"
            result <- retryOperation 3 operation
            result `shouldBe` "success"
            readIORef ref >>= (`shouldBe` 3)
```
Clear name, tests real behavior, one thing
</Good>

<Bad>
```haskell
it "retry works" $ do
    retryOperation 3 (pure "ok") >>= (`shouldBe` "ok")
```
Vague name, only tests the happy path, proves nothing about retry
</Bad>

**Requirements:**
- One behavior
- Clear name
- Test pure functions directly, IO only when necessary

### Verify RED - Watch It Fail

**MANDATORY. Never skip.**

```bash
just test-backend    # Haskell (hspec)
just test-frontend   # PureScript (purescript-spec)
just test            # both
```

Confirm:
- Test fails (not compilation errors)
- Failure message is expected
- Fails because feature missing (not typos)

**Test passes?** You're testing existing behavior. Fix test.

**Test errors?** Fix error, re-run until it fails correctly.

**Doesn't compile?** That's fine for RED — add minimal type signatures or stubs to make it compile, then watch it fail.

### GREEN - Minimal Code

Write simplest code to pass the test.

<Good>
```haskell
retryOperation :: Int -> IO a -> IO a
retryOperation maxRetries action = go 0
  where
    go n
        | n >= maxRetries = action
        | otherwise = catch action (\(_ :: SomeException) -> go (n + 1))
```
Just enough to pass
</Good>

<Bad>
```haskell
retryOperation
    :: Int
    -> Duration
    -> BackoffStrategy
    -> (Int -> IO ())
    -> IO a
    -> IO a
retryOperation maxRetries delay strategy onRetry action = ...
    -- YAGNI
```
Over-engineered
</Bad>

Don't add features, refactor other code, or "improve" beyond the test.

### Verify GREEN - Watch It Pass

**MANDATORY.**

```bash
just test-backend    # Haskell
just test-frontend   # PureScript
```

Confirm:
- Test passes
- Other tests still pass
- No warnings (`-Werror` catches these in Haskell)

**Test fails?** Fix code, not test.

**Other tests fail?** Fix now.

### REFACTOR - Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers
- Tighten type signatures

Keep tests green. Don't add behavior.

### Repeat

Next failing test for next feature.

## Testing Strategy

### Prefer Pure Functions

The best tests are pure — no IO/Effect needed. This applies equally to Haskell and PureScript.

<Good>
```haskell
-- Haskell (hspec)
describe "computePath" $ do
    it "returns single node for leaf" $ do
        let nodes = [entity 1 Nothing "Root"]
        computePath (toSqlKey 1) nodes `shouldBe` [PathNode 1 "Root" 0]

    it "follows highest-scored children" $ do
        let nodes =
                [ entity 1 Nothing "Root"
                , entity 2 (Just 1) "Low" & setScore 1
                , entity 3 (Just 1) "High" & setScore 10
                ]
        let path = computePath (toSqlKey 1) nodes
        map (.content) path `shouldBe` ["Root", "High"]
```

```purescript
-- PureScript (purescript-spec)
describe "formatScore" do
    it "formats positive scores with plus sign" do
        formatScore 42 `shouldEqual` "+42"

    it "formats zero without sign" do
        formatScore 0 `shouldEqual` "0"
```
Pure function, no IO/Effect, fast, deterministic
</Good>

<Bad>
```haskell
-- Haskell: database for pure logic
it "computes path" $ do
    pool <- createSqlitePool ":memory:"
    runDb pool $ insertMany_ testNodes
    result <- runDb pool $ getPathHandler (toSqlKey 1)
    length result `shouldSatisfy` (> 0)
```

```purescript
-- PureScript: Aff for pure logic
it "computes display name" do
    result <- fetchAndFormat userId
    result `shouldEqual` "Expected Name"
```
</Bad>

### Extract Pure Logic From Effects

When you find yourself needing IO/Effect/Aff in tests, that's a design signal:

```
Effect-heavy code → Extract pure function → Test the pure function
```

The handler does effects (database, HTTP). The logic is pure. Test the logic.

This applies to both Haskell (`IO` → pure) and PureScript (`Aff`/`Effect` → pure).

### The Capability Pattern Over Mocks

Neither Haskell nor PureScript uses mocks the way OOP does. Use the capability pattern:

<Good>
```purescript
-- PureScript: Production capability (real API calls)
mkApiCapability :: ApiCapability Aff
mkApiCapability = { fetchHello: realFetchHello }

-- PureScript: Test capability (pure test doubles)
mkTestCapability :: ApiCapability Aff
mkTestCapability = { fetchHello: pure (Right "Hello!") }
```

```haskell
-- Haskell: Same pattern with records
data Capabilities m = Capabilities
    { fetchRoot :: m (Either String RootInfo)
    }

testCaps :: Capabilities IO
testCaps = Capabilities
    { fetchRoot = pure (Right testRoot)
    }
```
Swap implementations via records, no mocking framework needed
</Good>

<Bad>
```
-- Don't reach for a mocking library
-- Don't add test-only code paths to production modules
-- Don't use IORef/Ref flags to simulate behavior
```
</Bad>

### Type-Driven Testing

Both languages' type systems prevent many bugs. Focus tests on:

| Test This | Not This |
|-----------|----------|
| Business logic correctness | Type-level guarantees the compiler checks |
| Edge cases (empty lists, Nothing, boundaries) | That `Maybe` works correctly |
| Pure function behavior | Plumbing between components |
| Serialization round-trips (JSON encode/decode) | That the JSON library works |

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| **Minimal** | One thing. "and" in name? Split it. | `it "validates email and domain and whitespace"` |
| **Clear** | Name describes behavior | `it "test1"` |
| **Pure** | Tests pure function directly | Spins up database for pure logic |
| **Shows intent** | Demonstrates desired API | Obscures what code should do |

## Why Order Matters

**"I'll write tests after to verify it works"**

Tests written after code pass immediately. Passing immediately proves nothing:
- Might test wrong thing
- Might test implementation, not behavior
- Might miss edge cases you forgot
- You never saw it catch the bug

Test-first forces you to see the test fail, proving it actually tests something.

**"The type system catches bugs, I don't need tests"**

Types catch structural bugs. They don't catch logic bugs:
- `computePath` type-checks but returns nodes in wrong order
- `fromDomainNode` type-checks but swaps two `Text`/`String` fields
- Business rules compile but compute wrong results

Types + tests = confidence. Types alone = false confidence. This applies equally to Haskell and PureScript.

**"Deleting X hours of work is wasteful"**

Sunk cost fallacy. The time is already gone. Your choice now:
- Delete and rewrite with TDD (X more hours, high confidence)
- Keep it and add tests after (30 min, low confidence, likely bugs)

The "waste" is keeping code you can't trust.

**"TDD is dogmatic, being pragmatic means adapting"**

TDD IS pragmatic:
- Finds bugs before commit (faster than debugging after)
- Prevents regressions (tests catch breaks immediately)
- Documents behavior (tests show how to use code)
- Enables refactoring (change freely, tests catch breaks)

"Pragmatic" shortcuts = debugging in production = slower.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "The types guarantee it" | Types prevent structural bugs. Logic bugs slip through. |
| "Already manually tested in GHCi/PSCi" | Ad-hoc, no record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test hard = design unclear" | Listen to test. Hard to test = needs pure extraction. |
| "TDD will slow me down" | TDD faster than debugging. |

## Red Flags - STOP and Start Over

- Code before test
- Test after implementation
- Test passes immediately
- Can't explain why test failed
- Tests added "later"
- Rationalizing "just this once"
- "The types guarantee correctness"
- "I tested it in GHCi/PSCi"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"

**All of these mean: Delete code. Start over with TDD.**

## Example: Bug Fix

**Bug:** Empty content accepted for story nodes

**RED**
```haskell
describe "validateContent" $ do
    it "rejects empty content" $ do
        validateContent "" `shouldBe` Left "Content required"

    it "rejects whitespace-only content" $ do
        validateContent "   " `shouldBe` Left "Content required"
```

**Verify RED**
```bash
$ just test-backend
FAIL: expected Left "Content required", got Right ""
```

**GREEN**
```haskell
validateContent :: Text -> Either Text Text
validateContent t
    | T.null (T.strip t) = Left "Content required"
    | otherwise = Right t
```

**Verify GREEN**
```bash
$ just test-backend
PASS
```

**REFACTOR**
Extract validation for multiple fields if needed.

## Example: New Feature with Round-Trip Test

**Feature:** Serialize/deserialize domain types

**RED**
```haskell
describe "HelloResponse JSON" $ do
    it "round-trips through JSON" $ do
        let original = HelloResponse{message = "hello"}
        decode (encode original) `shouldBe` Just original
```

**Verify RED** — fails because `Eq` or `FromJSON` not derived yet.

**GREEN** — add minimal deriving clauses.

**Verify GREEN** — passes.

## Verification Checklist

Before marking work complete:

- [ ] Every new function has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for expected reason (feature missing, not typo)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass (`just test-backend`, `just test-frontend`, or `just test`)
- [ ] No warnings (`-Werror` enforces this in Haskell)
- [ ] Pure functions tested purely (no unnecessary IO)
- [ ] Edge cases covered (empty, Nothing, boundaries)

Can't check all boxes? You skipped TDD. Start over.

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write the assertion first. What should the result be? |
| Test too complicated | Extract pure logic from IO. Test the pure part. |
| Need IO in every test | Code too coupled. Push IO to the edges. |
| Can't test without database | Extract pure function, pass data as arguments. |

## Testing Anti-Patterns

When adding test utilities, read @testing-anti-patterns.md to avoid common pitfalls:
- Testing mock behavior instead of real behavior
- Adding test-only code paths to production modules
- Over-coupling tests to implementation details

## Final Rule

```
Production code → test exists and failed first
Otherwise → not TDD
```

No exceptions without your human partner's permission.
