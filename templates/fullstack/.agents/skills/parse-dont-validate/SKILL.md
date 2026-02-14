---
name: parse-dont-validate
description: Apply the "Parse, Don't Validate" principle when designing types, writing functions, or reviewing code in Haskell or PureScript. Use when defining data types, writing validation logic, handling user input, designing APIs, or when tempted to use partial functions, boolean flags, or stringly-typed data. Applies to both backend (Haskell) and frontend (PureScript) code. Based on Alexis King's blog post.
---

# Parse, Don't Validate

## Core Principle

**Parsing** preserves information in types. **Validation** discards it.

A parser is a function that consumes less-structured input and produces more-structured output — or rejects it with an error. A validator checks a predicate and throws it away.

```
Parser:    Text -> Either Error Email        -- preserves the proof
Validator: Text -> Either Error ()           -- discards it, caller still has raw Text
```

If you validate, every downstream function must re-check or trust blindly. If you parse, the type carries the proof.

## The Rules

### 1. Strengthen Argument Types, Don't Weaken Return Types

<Good>
```haskell
-- Caller must prove the list is non-empty
head :: NonEmpty a -> a
```
</Good>

<Bad>
```haskell
-- Burden on every caller to handle Nothing
head :: [a] -> Maybe a
```
</Bad>

`Maybe` in the return type means every caller must handle a case that might be impossible in context. `NonEmpty` in the argument type eliminates the impossible case at the call site.

### 2. Make Illegal States Unrepresentable

<Good>
```haskell
-- Exactly one of these, enforced by the type
data ContactInfo
    = EmailOnly Email
    | PhoneOnly Phone
    | EmailAndPhone Email Phone
```
</Good>

<Bad>
```haskell
-- Can represent (Nothing, Nothing) — illegal but possible
data ContactInfo = ContactInfo
    { email :: Maybe Email
    , phone :: Maybe Phone
    }
```
</Bad>

### 3. Parse at the Boundary, Use Strong Types Internally

```
External input (Text, JSON, form data)
    │
    ▼
  Parse (boundary) ──→ reject with error
    │
    ▼
Strong types (NonEmpty, Email, ValidatedOrder)
    │
    ▼
Pure logic — no Maybe, no validation, no partial functions
```

Parse once at the system boundary. Internal functions receive already-parsed types and never re-validate.

### 4. Scrutinize `m ()` Return Types

A function returning `m ()` is a red flag — it validates but discards the result.

<Bad>
```haskell
-- Haskell
validateEmail :: Text -> Either String ()
processUser :: Text -> IO ()
processUser rawEmail = do
    validateEmail rawEmail  -- proof discarded!
    sendEmail rawEmail      -- using unchecked Text

-- PureScript
validateEmail :: String -> Either String Unit
processUser :: String -> Effect Unit
processUser rawEmail = do
    validateEmail rawEmail  -- proof discarded!
    sendEmail rawEmail      -- using unchecked String
```
</Bad>

<Good>
```haskell
-- Haskell
parseEmail :: Text -> Either String Email
processUser :: Text -> IO ()
processUser rawEmail = do
    email <- parseEmail rawEmail  -- proof preserved in type
    sendEmail email               -- using Email, not Text

-- PureScript
parseEmail :: String -> Either String Email
processUser :: String -> Effect Unit
processUser rawEmail = do
    email <- parseEmail rawEmail  -- proof preserved in type
    sendEmail email               -- using Email, not String
```
</Good>

### 5. Avoid Denormalized Representations

Denormalized data has multiple valid representations for the same value, forcing consumers to handle redundant cases.

<Bad>
```haskell
-- A list of unique elements... but the type allows duplicates
uniqueUsers :: [User]
```
</Bad>

<Good>
```haskell
-- The type guarantees uniqueness
uniqueUsers :: Set User
```
</Good>

### 6. Use Smart Constructors for Invariants

When a type has invariants the type system can't directly express, hide the constructor and expose a parser.

```haskell
module Domain.Email (Email, parseEmail, emailToText) where

-- Constructor not exported
newtype Email = Email Text

parseEmail :: Text -> Either String Email
parseEmail t
    | isValidEmail t = Right (Email t)
    | otherwise = Left "Invalid email format"

emailToText :: Email -> Text
emailToText (Email t) = t
```

Consumers can only create `Email` through `parseEmail` — the invariant is enforced by the module boundary.

## Shotgun Parsing — The Anti-Pattern

**Shotgun parsing**: validation and processing interleaved throughout the codebase instead of concentrated at the boundary.

Symptoms:
- Validation checks scattered across multiple modules
- `fromJust`, `head`, or other partial functions on "already validated" data
- Comments like `-- safe because we checked above`
- Boolean flags like `isValidated :: Bool` carried alongside raw data

Fix: parse at entry, push strong types through the rest.

## Quick Reference (Haskell & PureScript)

These apply equally to both languages:

| Instead of | Use |
|-----------|-----|
| `[a]` when non-empty is required | `NonEmpty a` |
| `Text`/`String` for structured strings | Newtype with smart constructor (`Email`, `Username`) |
| `Maybe a` return for impossible cases | Stronger argument type |
| `Int` for constrained numbers | Newtype with smart constructor (`Port`, `Age`) |
| `(Maybe a, Maybe b)` for "at least one" | Sum type or dedicated ADT |
| `Map k v` when every key must exist | Total function or custom type |
| Boolean flags (`isActive :: Bool`) | Separate types (`Active`, `Inactive`) |
| `validate :: a -> Either e ()` | `parse :: raw -> Either e a` |

## Decision Gate

Before writing a function:

```
Does this function VALIDATE (check + discard)?
  → Rewrite as a PARSER (check + preserve in type)

Does the return type contain Maybe/Either for cases the caller can't cause?
  → Strengthen the argument type instead

Does this function use a partial function on "already validated" data?
  → The validation proof was lost — add a parsing step that produces a stronger type

Is there a `Bool` or `String` that represents a finite set of states?
  → Replace with a sum type
```
