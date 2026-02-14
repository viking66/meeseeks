---
name: total-depravity
description: Defensive typing — encode invariants in the type system instead of trusting programmers to remember them. Use when designing data types in Haskell or PureScript, choosing between newtype vs raw type, deciding whether to use Bool/String/Int for domain concepts, working with resource cleanup, handling IDs that could be mixed up, or reviewing code that relies on conventions rather than compiler enforcement. Applies to both backend (Haskell) and frontend (PureScript) code. Based on Justin Le's "Five-Point Haskell" series.
---

# Total Depravity: Defensive Typing

## Core Principle

**If correctness depends on keeping invariants in your head, failure is inevitable.**

Don't be a "brilliant programmer" who holds the whole system mentally. Encode invariants in types and let the compiler enforce them. This frees mental bandwidth for actual design decisions.

## The Techniques

### 1. Newtype-Tag Distinct IDs

Raw `Int` or `Text` for IDs invites mix-ups that compile fine and explode at runtime.

<Bad>
```haskell
-- Haskell
deleteUser :: Int64 -> IO ()
deleteProject :: Int64 -> IO ()

-- PureScript
deleteUser :: Int -> Effect Unit
deleteProject :: Int -> Effect Unit

-- Compiles in both. Deletes the wrong thing.
deleteProject userId
```
</Bad>

<Good>
```haskell
-- Haskell
newtype UserId = UserId Int64
newtype ProjectId = ProjectId Int64
deleteUser :: UserId -> IO ()
deleteProject :: ProjectId -> IO ()

-- PureScript
newtype UserId = UserId Int
newtype ProjectId = ProjectId Int
deleteUser :: UserId -> Effect Unit
deleteProject :: ProjectId -> Effect Unit

-- Compile error in both: expected ProjectId, got UserId
deleteProject userId
```
</Good>

**Rule:** If two values share a representation but mean different things, they need distinct newtypes.

### 2. Phantom Types for Closed Universes

Use type parameters as markers that restrict operations.

```haskell
-- Haskell (using DataKinds)
type data Env = Prod | Test
newtype DbConnection (env :: Env) = DbConnection Connection
clearTestData :: DbConnection Test -> IO ()
reportMetrics :: DbConnection Prod -> IO ()

-- PureScript (phantom type parameter)
data Prod
data Test
newtype DbConnection env = DbConnection Connection
clearTestData :: DbConnection Test -> Effect Unit
reportMetrics :: DbConnection Prod -> Effect Unit
```

A `DbConnection Prod` can never satisfy `DbConnection Test` — the compiler prevents running `clearTestData` against production. In Haskell, `DataKinds` restricts the phantom to a closed set. In PureScript, empty data declarations achieve the same effect.

### 3. Eliminate Sentinel Values

Sentinel values (`-1`, `""`, `null`) bypass the type system. The compiler can't distinguish "not found" from "found at index -1".

<Bad>
```haskell
findIndex :: Eq a => a -> [a] -> Int
-- Returns -1 if not found. Caller must remember to check.
```
</Bad>

<Good>
```haskell
findIndex :: Eq a => a -> [a] -> Maybe Int
-- Caller MUST handle Nothing. Compiler enforces it.
```
</Good>

**Rule:** If a value has a "special" meaning, it belongs in a sum type (`Maybe`, `Either`, custom ADT), not encoded as a magic number or empty string.

### 4. Defeat Boolean Blindness

A `Bool` return discards *what* was true. Callers must remember which branch is which.

<Bad>
```haskell
isAdmin :: User -> Bool

-- Which branch is the admin? Reader must check the function.
if isAdmin user then ... else ...

-- Filter: does True mean "keep" or "discard"?
filter :: (a -> Bool) -> [a] -> [a]
```
</Bad>

<Good>
```haskell
data Role = Admin | Member

userRole :: User -> Role

case userRole user of
    Admin -> ...
    Member -> ...

-- mapMaybe: Just keeps, Nothing discards — unambiguous
mapMaybe :: (a -> Maybe b) -> [a] -> [b]
```
</Good>

**Rule:** If a `Bool` controls branching on *what kind* of thing something is, replace it with a sum type that names the cases.

### 5. Smart Constructors for Invariants

When the type system can't directly express a constraint, hide the constructor and expose a parser.

```haskell
module Domain.Port (Port, mkPort, portNumber) where

newtype Port = Port Int

mkPort :: Int -> Maybe Port
mkPort n
    | n >= 1 && n <= 65535 = Just (Port n)
    | otherwise = Nothing

portNumber :: Port -> Int
portNumber (Port n) = n
```

Internal code receives `Port` and never checks bounds — the invariant is guaranteed by construction.

**Rule:** If you see a comment like `-- must be between 1 and 65535`, that's a type waiting to be born.

### 6. Resource Cleanup Guarantees

Don't trust callers to close handles. Use continuation-passing or `bracket` to make cleanup automatic.

<Bad>
```haskell
-- Haskell
openFile :: FilePath -> IO Handle
-- PureScript
openConnection :: Effect Connection
-- Caller must remember to close. Exception = leak.
```
</Bad>

<Good>
```haskell
-- Haskell: continuation-passing or bracket
withFile :: FilePath -> (Handle -> IO r) -> IO r

-- PureScript: Aff.bracket
bracket (openConnection) closeConnection \conn ->
    doWork conn
```
</Good>

In Haskell, nest `with*` functions or use `ResourceT` for multiple resources. In PureScript, use `Aff.bracket` for the same guarantee.

**Rule:** If a resource needs cleanup, the API should make leaking it impossible, not merely discouraged.

## Decision Gate

```
Is this a raw Int/Text that represents a domain concept?
  → Newtype it

Are two values the same type but semantically distinct?
  → Separate newtypes (UserId vs ProjectId)

Does an operation only make sense in certain contexts?
  → Phantom type (DbConnection Test vs Prod)

Is there a "special" return value (-1, "", null)?
  → Use Maybe, Either, or a sum type

Is a Bool controlling which *kind* of thing something is?
  → Replace with a named sum type

Does a comment explain an invariant the type doesn't express?
  → Smart constructor

Can a caller forget to clean up a resource?
  → Continuation-passing (withX pattern)
```

## Relationship to Parse, Don't Validate

This skill is the broader mindset; "Parse, Don't Validate" is one specific application of it. Total Depravity says *don't trust your brain* — encode everything in types. Parse Don't Validate says *when you check input, preserve the proof in a type*. They reinforce each other.
