# Testing Anti-Patterns

**Load this reference when:** writing or changing tests, considering test doubles, or tempted to add test-only code to production modules.

## Overview

Tests must verify real behavior. Haskell and PureScript's strength is pure functions — lean into it.

**Core principle:** Test what the code does, not what your test setup does.

**Following strict TDD prevents these anti-patterns.**

## The Iron Laws

```
1. NEVER test test-double behavior instead of real behavior
2. NEVER add test-only functions to production modules
3. NEVER use IO/Effect/Aff when pure testing is possible
```

## Anti-Pattern 1: Testing in IO/Effect When Pure Is Possible

**The violation:**
```haskell
-- BAD: IO for logic that's pure
it "computes total score" $ do
    pool <- createSqlitePool ":memory:"
    runDb pool $ insertMany_ testNodes
    result <- runDb pool $ computeTotalScore (toSqlKey 1)
    result `shouldBe` 42
```

**Why this is wrong:**
- Slow: database setup for every test
- Non-deterministic: pool creation, file I/O
- Testing database + logic when you only care about logic
- Harder to write, harder to debug

**The fix:**
```haskell
-- GOOD: Pure function, pure test
it "computes total score" $ do
    let nodes =
            [ mkNode 1 Nothing 10
            , mkNode 2 (Just 1) 15
            , mkNode 3 (Just 1) 17
            ]
    computeTotalScore nodes `shouldBe` 42
```

### Gate Function

```
BEFORE writing an IO/Effect/Aff test:
  Ask: "Does this logic REQUIRE effects, or can I extract a pure function?"

  IF pure extraction possible:
    Extract pure function from handler
    Test the pure function
    Handler becomes thin effect wrapper (no logic to test)

  IF effects truly required (database, network, DOM):
    Proceed with effectful test, but minimize setup
```

## Anti-Pattern 2: Test-Only Exports

**The violation:**
```haskell
-- BAD: Exporting internals just for tests
module Aludrog.Api (
    -- * Public API
    Api, server, runServer,
    -- * Internal (exported for testing)
    _internalHelper,    -- only used in tests!
    _parseState,        -- only used in tests!
) where
```

**Why this is wrong:**
- Pollutes module's public API
- Consumers might depend on internals
- If you need internals for testing, your API is wrong

**The fix:**
```haskell
-- GOOD: Export the behavior, test through the public API
module Aludrog.Api (
    Api, server, runServer,
    -- Pure functions worth testing directly
    computePath,
    RootInfo (..),
) where
```

If a pure function is worth testing, it's worth exporting. If it's not worth exporting, test it through the functions that use it.

### Gate Function

```
BEFORE exporting a function for testing:
  Ask: "Is this function useful to consumers of this module?"

  IF yes:
    Export it — it's part of the public API, testing is a bonus

  IF no:
    STOP — Test through the public API instead
    OR move it to its own module where it IS the public API
```

## Anti-Pattern 3: Over-Specified Tests

**The violation:**
```haskell
-- BAD: Testing implementation details
it "uses Map.fromList for node lookup" $ do
    let nodes = [entity 1 Nothing "Root"]
    -- Testing that it internally uses a Map
    let nodeMap = buildNodeMap nodes
    Map.size nodeMap `shouldBe` 1
```

**Why this is wrong:**
- Tests break when you refactor internals
- Doesn't test the behavior users care about
- Locks you into an implementation

**The fix:**
```haskell
-- GOOD: Test the behavior, not the implementation
it "finds node by id" $ do
    let nodes = [entity 1 Nothing "Root", entity 2 Nothing "Other"]
    let path = computePath (toSqlKey 1) nodes
    map (.content) path `shouldBe` ["Root"]
```

### Gate Function

```
BEFORE writing an assertion:
  Ask: "Would this assertion still make sense if I completely rewrote the internals?"

  IF yes: Good assertion — tests behavior
  IF no:  Bad assertion — tests implementation, delete it
```

## Anti-Pattern 4: Vague Assertions

**The violation:**
```haskell
-- BAD: Proves almost nothing
it "returns something" $ do
    let result = computePath (toSqlKey 1) testNodes
    result `shouldSatisfy` (not . null)
```

**Why this is wrong:**
- `shouldSatisfy (not . null)` passes for ANY non-empty result
- Wrong results pass as long as they're non-empty
- No indication of expected behavior

**The fix:**
```haskell
-- GOOD: Exact expected values
it "returns path from root to highest-scored leaf" $ do
    let result = computePath (toSqlKey 1) testNodes
    map (.content) result `shouldBe` ["Root", "Chapter 1", "Best ending"]
```

### Gate Function

```
BEFORE using shouldSatisfy, shouldNotBe, or other vague matchers:
  Ask: "Do I know what the exact result should be?"

  IF yes: Use shouldBe with the exact value
  IF no:  You don't understand the behavior well enough to test it yet
```

## Anti-Pattern 5: Capability Pattern Misuse

**The violation:**
```haskell
-- BAD: Testing that the capability record was called
it "calls fetchActiveRoot" $ do
    ref <- newIORef False
    let cap = mkApiCapability
            { fetchActiveRoot = do
                writeIORef ref True
                pure (Right testRoot)
            }
    runComponent cap
    readIORef ref `shouldBe` True  -- Testing the test setup!
```

**Why this is wrong:**
- You're testing that your test double was called, not that the component works
- This is the Haskell/PureScript equivalent of "testing mock behavior"

**The fix:**
```haskell
-- GOOD: Test the outcome, not the mechanism
it "displays the story title" $ do
    let cap = mkTestCapability
            { fetchActiveRoot = pure (Right RootInfo{rootNodeId = 1, storyTitle = "My Story"})
            }
    result <- runComponent cap
    result.title `shouldBe` "My Story"
```

## Anti-Pattern 6: Incomplete Round-Trip Tests

**The violation:**
```haskell
-- BAD: Only testing one direction
it "serializes to JSON" $ do
    encode testNode `shouldBe` "{\"id\":1,\"content\":\"hello\"}"
```

**Why this is wrong:**
- JSON string comparison is brittle (field order, whitespace)
- Doesn't test deserialization
- Breaks when you add fields

**The fix:**
```haskell
-- GOOD: Round-trip test
it "round-trips through JSON" $ do
    let original = PathNode{id = 1, content = "hello", totalScore = 5}
    decode (encode original) `shouldBe` Just original
```

## Quick Reference

| Anti-Pattern | Fix |
|--------------|-----|
| IO/Effect test for pure logic | Extract pure function, test purely |
| Test-only exports | Export if useful, otherwise test through public API |
| Testing implementation | Test behavior and outcomes |
| Vague assertions | Use exact expected values |
| Testing test doubles | Test outcomes, not mechanisms |
| One-direction serialization | Round-trip tests |

## Red Flags

- `shouldSatisfy` where `shouldBe` would work
- IORef/Ref used to track "was this called?"
- Test setup longer than the assertion
- Functions exported with `_` prefix "for testing"
- Database in a test for pure logic
- JSON string comparison instead of round-trip

## The Bottom Line

Haskell and PureScript make testing easy: pure functions are trivially testable. If testing is hard, push effects to the edges and extract pure logic.

If TDD reveals you need IO/Effect everywhere, your design needs refactoring, not more test infrastructure.
