# POPUP_FORM Filled Indicator Implementation Plan

## Scope

This document verifies the current implementation of the popup-form progress indicator and defines the production change required to make `(x/y filled)` accurate for create, edit, and detail flows.

No Dart source code was changed as part of this task.

## Verified Current Behavior

The popup-form button UI only renders whatever counts are passed into it.

- Source: [lib/widgets/dynamic_field_builder.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/widgets/dynamic_field_builder.dart#L911)
- It displays `popupFormFilledCount` and `popupFormTotalCount` without evaluating fill state itself.

The actual count logic is duplicated in multiple places and currently uses this pattern:

- `subFields.where((e) => e.value != null && e.value != '').length`

Verified call sites:

- [lib/views/farmer/farmer_form_view.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/views/farmer/farmer_form_view.dart#L494)
- [lib/views/farmer/farmer_form_view.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/views/farmer/farmer_form_view.dart#L882)
- [lib/views/farmer/edit_farmer_details_view.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/views/farmer/edit_farmer_details_view.dart#L369)
- [lib/views/farmer/edit_farmer_details_view.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/views/farmer/edit_farmer_details_view.dart#L663)
- [lib/views/farmer/farmer_detail_view.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/views/farmer/farmer_detail_view.dart#L319)
- [lib/views/farmer/farmer_detail_view.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/views/farmer/farmer_detail_view.dart#L496)

The model layer also initializes some field values eagerly:

- `POPUP_FORM` is initialized with a non-null `List<DynamicFieldModel>`
- `CHECKBOX` is initialized with `false`

Verified here:

- [lib/models/api/api_models.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/models/api/api_models.dart#L286)

## Root Cause

The bug is real and the prompt matches the codebase.

### 1. Non-null is being treated as filled

The current logic only checks:

- `value != null`
- `value != ''`

That produces false positives because many unfilled states are still non-null.

Examples from the current model behavior:

- A `POPUP_FORM` always starts with a non-null list of child `DynamicFieldModel`s.
- A nested `POPUP_FORM` therefore gets counted as filled immediately, even if every child inside it is empty.
- A checkbox defaulting to `false` is also non-null and would be counted as filled by the same pattern.

### 2. Nested popup forms are counted by container existence, not child content

For popup forms, `value` is a list of child field models, not user-entered content. Counting that list as filled is the main reason deeply nested structures can show `(5/5 filled)` on first render.

### 3. Fill-state logic is duplicated

The same flawed count logic appears in create, edit, nested popup sheets, and detail mode. Even if one location is fixed, the others can still drift.

### 4. Visibility is not part of the count contract

The current popup count uses raw child lists. It does not define whether hidden conditional fields should contribute to the numerator or denominator. This is a source of inconsistency unless the implementation chooses one rule and uses it everywhere.

## Required Design

Introduce a single shared utility for fill evaluation and make all popup count displays read from it.

Recommended utility location:

- `lib/utils/field_fill_state.dart`

Required public API:

- `bool isFieldFilled(DynamicFieldModel field, {List<DynamicFieldModel>? siblings})`
- `int getFilledCount(List<DynamicFieldModel> fields)`
- `int getTotalCount(List<DynamicFieldModel> fields)`

If the team prefers to keep helpers closer to form models, the same API can live beside `DynamicFieldModel`, but it should still be shared and imported from one place only.

## Fill Rules

These rules align with the prompt and with the existing data model.

### TEXT and NUMBER and DATE

Count as filled only when the stored value is a non-empty string after trimming, or a non-string scalar that is meaningfully present.

Practical rule:

- `null` -> not filled
- `String` with only whitespace -> not filled
- parsed numeric values like `0` or `0.0` -> filled if they were actually stored as values

### DROPDOWN

Count as filled only when a real selection exists.

Practical rule:

- `null` -> not filled
- empty string -> not filled
- temporary values such as `"no_data"` or placeholder text -> not filled
- any resolved option id/string that maps to a real selection -> filled

### ARRAY-like values

Count as filled only when the list contains at least one meaningful item.

Practical rule:

- empty list -> not filled
- list of empty strings / null-like items only -> not filled
- list containing at least one meaningful scalar/map/item -> filled

### POPUP_FORM

This is the critical rule.

Count a popup form as filled only when at least one child field inside it is filled after recursive evaluation.

Practical rule:

- child list exists but all children are empty -> not filled
- one nested text/dropdown/array child has meaningful value -> filled
- one nested popup child is filled recursively -> filled

### Optional visibility rule

Recommended behavior for counts inside popup forms:

- `getFilledCount` should count only visible child fields
- `getTotalCount` should also count only visible child fields

Reason:

- Hidden conditional fields are not actionable for the user and should not penalize the progress indicator.
- This matches how the create, edit, and detail screens already filter top-level visible fields before rendering.

If product wants total to remain based on all configured children instead, that should be explicitly documented and applied everywhere. The important part is to choose one rule and centralize it.

## Production-Grade Implementation Strategy

### 1. Centralize recursive fill evaluation

Implement a shared evaluator that works off `DynamicFieldModel`, because the live form state already exists there.

The evaluator should:

- switch on `field.field.fieldStyle`
- inspect `field.value`
- recurse into `List<DynamicFieldModel>` when the style is `popupForm`
- treat initialized container objects as empty unless they contain meaningful descendant data
- avoid counting empty strings, whitespace-only strings, empty lists, or placeholder dropdown states

### 2. Add a small visibility-aware field selector

For popup child lists, compute a local list of relevant fields before counting.

Recommended helper:

- `Iterable<DynamicFieldModel> getCountableFields(List<DynamicFieldModel> fields)`

Behavior:

- include only visible fields via `shouldShowField(field, fields)`

This keeps counts aligned with the actual popup sheet content.

### 3. Replace duplicated inline counting

All six current count sites should stop doing local `where((e) => e.value != null && e.value != '')`.

Instead:

- `popupFormTotal = getTotalCount(subFields)`
- `popupFormFilled = getFilledCount(subFields)`

### 4. Keep the widget layer dumb

`DynamicFieldBuilder` should continue receiving already-computed counts.

That is a good separation:

- shared utility decides correctness
- view decides which fields to count
- widget just renders the summary

### 5. Reuse the same evaluator for validation follow-up

Not required for the first pass, but recommended:

- required popup-form validation in create/edit sheets should eventually use the same fill evaluator
- this avoids one definition of "filled" for the badge and another for submit validation

## File-by-File Implementation Plan

### 1. Add shared utility

Create:

- `lib/utils/field_fill_state.dart`

Responsibilities:

- recursive fill evaluation
- meaningful scalar/list checks
- popup-form count helpers
- short inline comments explaining recursion and false-positive prevention

### 2. Refactor create flow

Update:

- [lib/views/farmer/farmer_form_view.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/views/farmer/farmer_form_view.dart)

Replace both popup summary blocks:

- top-level `_buildDynamicField`
- nested `_buildSubField` inside `_PopupFormSheetState`

### 3. Refactor edit flow

Update:

- [lib/views/farmer/edit_farmer_details_view.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/views/farmer/edit_farmer_details_view.dart)

Replace both popup summary blocks:

- top-level `_buildField`
- nested `_buildSubField` inside `_EditPopupFormSheetState`

### 4. Verify read-only consistency

Check and align:

- [lib/views/farmer/farmer_detail_view.dart](/Users/zoondia/Documents/Jackson-Personal/Project/Flutter/greenated-app/lib/views/farmer/farmer_detail_view.dart)

Replace both popup summary blocks:

- top-level `_buildField`
- nested `_buildSubField` inside `_ViewOnlyPopupSheetState`

No behavior change should be introduced beyond using the same shared evaluator.

## Suggested Evaluation Matrix

These are the cases the implementation should explicitly satisfy.

### Case 1. Empty popup on initial load

- popup contains 5 children
- all child values are `null`, empty strings, empty lists, or default-initialized popup children
- expected result: `0/5 filled`

### Case 2. Nested popup with empty descendants

- popup contains 2 nested popup forms and 3 scalar fields
- both nested popup forms contain only empty children
- expected result: nested popup items count as unfilled

### Case 3. Nested popup with one filled grandchild

- child popup contains one text field with non-empty value
- expected result: child popup counts as filled
- parent popup numerator increments by exactly 1 for that child popup item

### Case 4. Dropdown placeholder state

- dropdown has no real selection yet
- expected result: unfilled

### Case 5. Array with empty content

- array is empty or contains only empty/blank items
- expected result: unfilled

### Case 6. Conditional hidden field

- child field exists in config but is currently hidden by `showWhen`
- recommended expected result: excluded from both numerator and denominator

## Performance Notes

The prompt asks to avoid heavy recalculation on every build. Based on the current code structure:

- popup counts are only needed for currently rendered popup buttons
- each count walks that popup subtree once
- subtree sizes are likely modest compared with the full form

That means a shared recursive traversal is acceptable as a first production fix.

If profiling later shows pressure in very large forms, use one of these follow-ups:

- memoize per `DynamicFieldModel` subtree during a single build pass
- compute summary objects when a popup field changes and store them on the popup model
- expose a small cached summary from the view model

Do not optimize before centralizing correctness.

## Recommended Acceptance Criteria

- Empty popup forms never show as filled on initial render.
- Nested popup forms do not count as filled unless at least one descendant field has meaningful data.
- Create, edit, and detail flows display the same filled counts for the same data.
- Conditional hidden fields follow one consistent count rule.
- The popup summary updates immediately after save/change without flicker or stale values.

## Notes For The Implementation PR

Keep inline comments focused on:

- why popup forms recurse instead of checking `value != null`
- why default-initialized containers are not considered filled
- whether hidden fields are excluded from totals

Good optional additions:

- unit tests for the utility if a test harness already exists
- at minimum, helper examples in comments or docstrings covering nested popup cases
