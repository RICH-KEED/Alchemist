---
name: Form Engine
description: Generate validated forms from a JSON schema — wired to Riverpod AsyncNotifier, Material 3, and AppTokens with per-field error UX and submit returning Result<T>
when_to_use: Building any data-entry screen — signup, settings, checkout, CRUD forms — where fields, validation rules, and submit flow should be derived from a declarative schema rather than hand-coded per screen
---

# Form Engine

Pipeline stage 55 — generates type-safe, validated Flutter forms from a declarative JSON schema. Uses a `FormSchema` freezed model to describe fields, a Riverpod `AsyncNotifier` for state and submission, and Material 3 widgets for rendering.

**Exit gate:** Every declared field renders with its correct widget type. Validation errors appear inline per-field with red border + helper text. The submit button is wired to a Riverpod controller that validates all fields and returns `Result<Map<String, dynamic>>` (see [CONVENTIONS.md](../../references/CONVENTIONS.md)).

## Why a Schema?

Hand-coding form UIs leads to:
- Inconsistent validation error UX across screens
- Duplicated field logic (label, validator, controller per field)
- Hard-to-test submit flows

A schema-based approach gives you one source of truth per form, one builder that renders all field types, and one Riverpod notifier that validates + submits.

## Schema Contract

The form is described by a `FormSchema` (see `templates/form_builder.dart`). Every field is a `FormFieldSchema`:

| Property    | Type                     | Notes                                    |
|-------------|--------------------------|------------------------------------------|
| `name`      | String                   | Key in the submitted map                 |
| `type`      | FormFieldType enum       | text, email, number, url, phone, dropdown, date, toggle, multiselect |
| `label`     | String                   | Shown above the field                    |
| `required`  | bool                     | Cannot be empty on submit                |
| `validators`| List<String>             | Named rules: "required", "min_length:3", "regex:pattern", "email", "url", "phone", "numeric", "min:0", "max:100", "date_after:today" |
| `options`   | List<String>?            | Dropdown / multiselect choices           |
| `placeholder`| String?                 | Shown when field is empty                |
| `hint`      | String?                  | Additional help text below label         |

### Example: Signup Schema

```json
{
  "fields": [
    { "name": "full_name", "type": "text", "label": "Full Name", "required": true, "validators": ["required", "min_length:2"] },
    { "name": "email", "type": "email", "label": "Email Address", "required": true, "validators": ["required", "email"] },
    { "name": "password", "type": "text", "label": "Password", "required": true, "validators": ["required", "min_length:8", "regex:^(?=.*[A-Z])(?=.*\\d)"] },
    { "name": "confirm_password", "type": "text", "label": "Confirm Password", "required": true, "validators": ["required", "matches:password"] },
    { "name": "country", "type": "dropdown", "label": "Country", "required": true, "validators": ["required"], "options": ["US", "Canada", "UK", "Australia", "Germany", "India", "Other"] },
    { "name": "agree_tos", "type": "toggle", "label": "I agree to the Terms of Service", "required": true, "validators": ["must_be_true"] },
    { "name": "bio", "type": "text", "label": "Short Bio", "required": false, "validators": ["max_length:500"], "placeholder": "Tell us about yourself..." }
  ]
}
```

## Field Type Mapping

Each `FormFieldType` maps to a Material 3 widget:

| Enum Value      | Widget                                      |
|-----------------|---------------------------------------------|
| `text`          | `TextFormField` (multiline if hint suggests)|
| `email`         | `TextFormField` + `keyboardType: TextInputType.emailAddress` |
| `number`        | `TextFormField` + `keyboardType: TextInputType.number` |
| `url`           | `TextFormField` + `keyboardType: TextInputType.url` |
| `phone`         | `TextFormField` + `keyboardType: TextInputType.phone` |
| `dropdown`      | `DropdownButtonFormField<T>`                |
| `date`          | `TextFormField` + tap→`showDatePicker`      |
| `toggle`        | `SwitchListTile` (or `CheckboxListTile`)    |
| `multiselect`   | `Wrap` of `FilterChip` widgets              |

## Validation Rules

Validators are strings parsed by `formFieldValidatorProvider`. Supported rules:

| Rule                | Description                                    |
|---------------------|------------------------------------------------|
| `required`          | Non-empty value; toggle must be true           |
| `email`             | Regex match for email format                   |
| `url`               | Regex match for URL format                     |
| `phone`             | Regex match for phone number                   |
| `numeric`           | Value must parse as a number                   |
| `min:N`             | Numeric minimum value                          |
| `max:N`             | Numeric maximum value                          |
| `min_length:N`      | String minimum length                          |
| `max_length:N`      | String maximum length                          |
| `regex:pattern`     | Custom regex match                             |
| `matches:fieldName` | Value must equal another field (confirm password) |
| `date_after:today`  | Date must be in the future                     |
| `date_before:today` | Date must be in the past                       |
| `must_be_true`      | Toggle must be checked                         |
| `min_selection:N`   | Multiselect minimum selected items             |
| `max_selection:N`   | Multiselect maximum selected items             |

## Error UX

Errors are surfaced at two levels, following Material 3 conventions:

1. **Per-field (inline):** `TextFormField` uses the `validator` callback. The field border turns red (`errorBorder`), and the error message appears as `helperText` in `errorColor`. For non-TextFormField widgets (toggle, dropdown, chips), a `Text` widget with `Theme.of(context).colorScheme.error` is rendered below the widget.

2. **Form-level:** If any field fails validation on submit, the form scrolls to the first error field via `Scrollable.ensureVisible`. A `SnackBar` shows "Please fix X errors" with `SnackBarAction` labelled "Show first".

## Riverpod Wiring

Three providers compose the form engine:

```
formSchemaProvider(formId)         → FutureProvider<FormSchema>  (loads JSON)
formFieldControllerProvider(formId)→ AsyncNotifier<FormBuilderNotifier, FormBuilderState>
formFieldValidatorProvider         → Provider (pure, no state)
```

### State

```dart
@freezed
class FormBuilderState with _$FormBuilderState {
  const factory FormBuilderState({
    required FormSchema schema,
    required Map<String, TextEditingController> controllers,
    required Map<String, String?> fieldErrors,
    @Default(FormSubmissionStatus.idle) FormSubmissionStatus status,
    String? formError,
  }) = _FormBuilderState;
}

enum FormSubmissionStatus { idle, validating, submitting, success, failure }
```

### Submit Flow

1. User taps submit button
2. Controller sets `status: FormSubmissionStatus.validating`
3. Every field's `formFieldValidatorProvider` runs against current controller values
4. If errors found → `status: idle`, populate `fieldErrors` map, scroll to first error, show SnackBar
5. If valid → `status: submitting`, call `onSubmit(Map<String, dynamic>)` callback (injected)
6. Callback returns `Result<T>`. On `Success` → `status: success`. On `Failure` → `status: failure` with `formError` set
7. Success clears form; failure shows form-level error banner

## Testing Patterns

Reference [CONVENTIONS.md test conventions](../../references/CONVENTIONS.md).

- **Unit:** `formFieldValidatorProvider` — test each rule in isolation. Pass a field schema + value, expect error or null.
- **Unit:** `FormBuilderNotifier` — verify state transitions: idle→validating→submitting→success. Verify field errors populate correctly.
- **Widget:** Pump an actual form with `pumpWidget`, enter values, tap submit. Assert error text appears, success callback fires.
- **Integration:** Full signup flow from schema JSON → rendered form → fill → submit → navigation to next screen.

## Dependencies

- `flutter_riverpod` / `riverpod_annotation` for providers
- `freezed` / `freezed_annotation` for models
- `json_serializable` / `json_annotation` for schema deserialization
- Material 3 (built-in — no extra package)
- [Skill 08 — Riverpod](../08_Riverpod/SKILL.md) for AsyncNotifier patterns
- [Skill 15 — Error Handling](../15_Error_Handling/SKILL.md) for `Result<T>`, `Failure` sealed types

## Scripts

Generate the form builder from templates:

```bash
cp ${CLAUDE_SKILL_DIR}/templates/form_builder.dart lib/features/form_engine/
cp ${CLAUDE_SKILL_DIR}/templates/form_schema.example.json assets/forms/
```

## Schema-driven vs. Hand-coded

This engine is best for data-entry forms where fields vary per screen. For a single static form (e.g., login with 2 fields), hand-coding may be simpler — but you still get free validation and consistent error UX by using `formFieldValidatorProvider` directly.

For complex conditional fields (field B appears only if field A = "X"), extend `FormSchema` with a `dependsOn` map, or handle visibility logic in the screen widget via `ref.watch(formFieldControllerProvider).select((s) => s.fieldValues)`.

## See Also

- [Skill 08 — Riverpod Notifiers](../08_Riverpod/SKILL.md)
- [Skill 15 — Error Handling & Result Types](../15_Error_Handling/SKILL.md)
- [Skill 19 — Form Generation (legacy/simple)](../19_Form_Generation/SKILL.md)
- [CONVENTIONS.md](../../references/CONVENTIONS.md)
