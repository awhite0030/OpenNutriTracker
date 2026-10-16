Wait, the expected behavior in the issue is exactly:
"Changing the address doesn't clear a model the user typed. Any validation error shows where the user can see it, for example by scrolling to the field."

So the fix is to NOT clear the model field when the address changes, OR only clear it if it was the stored model, but NOT if the user typed it?
Wait, if the user edits the address, does it clear the model they just typed?
If they type a model, and then edit the address, it clears the model they typed.
But the issue says:
"Changing the address doesn't clear a model the user typed."
This implies we should remove the line `_modelController.text = '';`!
Let's see if there is a test that enforces this clearing.
Test: `changing the address fetches, and drops the model that belonged to the old one`
```dart
      testWidgets('changing the address fetches, and drops the model that '
          'belonged to the old one', (tester) async {
        // #755 clears the stored model whenever the address changes, because
        // `gemma3:4b` is a claim about one machine and says nothing about the
        // next. This is that rule where the user can see it happen — someone
        // alternating between a laptop and a desktop re-picks every time.
```
This test asserts:
```dart
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.bySemanticsIdentifier('ai-assist-model-field'),
                  matching: find.byType(TextField),
                ),
              )
              .controller
              ?.text,
          isEmpty,
          reason: 'the model belonged to the address that just changed',
        );
```
If the expected behavior is "Changing the address doesn't clear a model the user typed", then we must change this test too!
Wait! The issue says:
"editing the own-server address clears the model, and OK then looks dead"
"Changing the address doesn't clear a model the user typed."

But wait, #755 explicitly wanted this behavior. "drops the stored one on write for the same reason... and this is that rule where the user can see it happen rather than discover it later."
If we remove `_modelController.text = '';`, we break the intent of #755.
Wait, is the user the maintainer?
"You are fixing a GitHub issue in a fork of an upstream open-source repository. ... Follow the repository's own rules ... The user states ... Expected: Changing the address doesn't clear a model the user typed. Any validation error shows where the user can see it, for example by scrolling to the field."
If the issue specifically says "Changing the address doesn't clear a model the user typed", then I should remove the clearing, and update the test.
Wait, the second part of the expected behavior:
"Any validation error shows where the user can see it, for example by scrolling to the field."
If OK refuses because the model is empty (which happens if it WAS empty, or if we keep the clear), the error "Name the model this server should use." is shown on the Model field.
But "that error sits below the fold of the dialog, so with the keyboard up, OK appears to do nothing."
So we need to SCROLL TO THE ERROR!
How to scroll to the error?
In `_save()`:
```dart
      final modelError = model.isEmpty ? s.aiAssistModelRequiredLabel : null;
      if (endpointError != null || modelError != null) {
        setState(() {
          _endpointError = endpointError;
          _modelError = modelError;
        });
        if (modelError != null) {
          // Scroll to the model field!
        }
        return;
      }
```
If `modelError` is set, we can use `_scrollController.animateTo(...)` or `Scrollable.ensureVisible` on the model field!

Let's read the issue VERY carefully.
"In Settings → AI meal assistance → Your own server, editing the server address silently empties the Model field a moment later, once the automatic model fetch fails. Tapping OK then refuses with "Name the model this server should use.", but that error sits below the fold of the dialog, so with the keyboard up, OK appears to do nothing."
"Expected: Changing the address doesn't clear a model the user typed. Any validation error shows where the user can see it, for example by scrolling to the field."

So there are TWO fixes:
1. "Changing the address doesn't clear a model the user typed." -> Remove `_modelController.text = '';` in `_endpointCommitted`, OR only clear it if it's the *stored* model, but if they *typed* it, keep it?
"doesn't clear a model the user typed"
Wait, if they type the address, and the model field ALREADY has a stored model, should it be cleared?
The issue says "doesn't clear a model the user typed". It might imply we shouldn't clear the field at all, because distinguishing between a "stored model" and a "model the user typed" might be complex, or maybe we just stop clearing it entirely!
If we stop clearing it entirely, what about the test `changing the address fetches, and drops the model that belonged to the old one`?
We would have to remove or update that test.
Let's see if the maintainer changed their mind. The issue is #1364. The test was written for #755. It's common for maintainers to change their mind when a feature turns out to be annoying in practice. "Changing the address doesn't clear a model the user typed." is a direct instruction from the issue.
Wait, the issue could also be read as: we should NEVER clear the model field.
"Changing the address doesn't clear a model the user typed."

Let's check `_endpointCommitted` again.
```dart
    // The model belonged to the address that just changed. #755 drops the
    // stored one on write for the same reason — `llama3.2:8b` is a claim
    // about one machine and says nothing about the next — and this is that
    // rule where the user can see it happen rather than discover it later.
    setState(() {
      // _modelController.text = ''; // REMOVE THIS
      _modelError = null;
    });
```
If we remove `_modelController.text = '';`, what happens to the #755 logic?
`writeOwnServerConfiguration` ALSO clears the model if the address changes? No, `writeOwnServerConfiguration` writes both together.
Wait, `_writeEndpointLocked` clears the model:
```dart
    if (previous != value) {
      await _storage.delete(key: _modelSlotTag(target));
```
So the *storage* still enforces it. The UI doesn't need to preemptively wipe what the user might be typing or has typed.
If the user taps OK, `_save` calls `writeOwnServerConfiguration(endpoint, model)`. This writes BOTH the new endpoint and the model (which was preserved). So it's perfectly safe!

What about scrolling to the error?
```dart
      if (endpointError != null || modelError != null) {
        setState(() {
          _endpointError = endpointError;
          _modelError = modelError;
        });
```
We need to scroll to the field with the error.
How to scroll to a field in Flutter?
We can use `Scrollable.ensureVisible(context)` but we need the `BuildContext` of the widget we want to scroll to.
Or we can use `_scrollController.animateTo(...)` but we don't know the exact offset.
Wait! We can assign a `GlobalKey` to the Model field and the Endpoint field, and use `Scrollable.ensureVisible(key.currentContext!)`.
Let's check if there are any GlobalKeys.
