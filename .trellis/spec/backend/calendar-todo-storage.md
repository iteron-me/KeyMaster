# Calendar Todo Storage

## 1. Scope / Trigger

Use this contract when changing the Calendar Todo model, local persistence, or
any UI mutation that writes Todo data.

Todo content is independent user data. It must remain separate from shortcut
rules, action history, and `KeyMasterConfiguration` import/export.

## 2. Signatures

The owning boundary is `@MainActor CalendarTodoStore`:

```swift
func add(title: String, notes: String = "", on day: CalendarTodoDay) -> Bool
func update(
    _ todo: CalendarTodo,
    title: String,
    notes: String,
    day: CalendarTodoDay
) -> Bool
func toggleCompletion(_ todo: CalendarTodo) -> Bool
func delete(_ todo: CalendarTodo) -> Bool
func archiveData() throws -> Data
func todos(fromArchiveData data: Data) throws -> [CalendarTodo]
func replace(with importedTodos: [CalendarTodo]) -> Bool
```

## 3. Contracts

The live file is `~/Library/Application Support/KeyMaster/todos.json` and uses
one versioned document:

```json
{
  "version": 1,
  "todos": [
    {
      "id": "UUID",
      "title": "Non-empty trimmed title",
      "notes": "Optional trimmed multi-line content",
      "day": { "year": 2026, "month": 7, "day": 27 },
      "isCompleted": false,
      "createdAt": "ISO-8601 with fractional seconds",
      "updatedAt": "ISO-8601 with fractional seconds"
    }
  ]
}
```

All-day dates use year/month/day fields instead of a timestamp so changing time
zones cannot move a Todo to another calendar date. Writes are atomic. A mutation
publishes its candidate array only after persistence succeeds.

`notes` is backward-compatible within version 1. Decoding a Todo written before
this field existed must produce `notes == ""`; do not reject the complete live
file because the key is absent.

The archive-named encoding helpers are internal serialization boundaries used
by persistence and focused tests. The Calendar Todo toolbar does not expose
import, export, backup, or restore actions.

## 4. Validation & Error Matrix

| Condition | Result |
|---|---|
| Empty or whitespace-only title | Reject with `invalidTitle` |
| Missing `notes` key | Decode as an empty string |
| Notes with leading/trailing whitespace | Trim before persistence |
| Impossible year/month/day | Reject with `invalidDate` |
| Duplicate UUID | Reject with `duplicateID` |
| Malformed JSON | Reject with `invalidArchive` |
| Unknown document version | Reject with `unsupportedVersion` |
| Corrupt live file | Block mutation until the file is fixed or removed and KeyMaster reopens |

## 5. Good / Base / Bad Cases

- Good: a title and multi-line content persist locally and reload unchanged.
- Base: no live file exists, so the store starts empty and creates the directory
  on the first successful mutation.
- Bad: a version 1 Todo without `notes` is treated as corrupt and blocks access
  to otherwise valid existing data. Missing notes must decode as empty content.

## 6. Tests Required

- Round-trip add, completion ordering, and process-reload persistence.
- Edit/reschedule removes the item from the old day; delete persists.
- Document round trip preserves typed fields and millisecond timestamp semantics.
- A version 1 document without `notes` decodes that field as an empty string.
- Invalid/unsupported document data leaves current items unchanged.
- A date-only value resolves to the same year/month/day in different time zones.
- Week grids contain 7 days; month grids contain 35 or 42 valid days.

## 7. Wrong vs Correct

Wrong: publish first and save afterward, which makes a failed write look
successful.

```swift
todos = candidate
try persist(candidate)
```

Correct: validate and persist the candidate before publishing it.

```swift
let candidate = try validated(candidate)
try persist(candidate)
todos = candidate
```

Wrong: make a newly added optional field mandatory during decoding.

```swift
notes = try container.decode(String.self, forKey: .notes)
```

Correct: preserve compatibility with existing version 1 files.

```swift
notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
```
