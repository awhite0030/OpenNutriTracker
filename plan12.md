Wait, if `_save` doesn't explicitly unfocus, does tapping `TextButton` cause focus to leave the `TextField`?
Let's see where the issue says "with the keyboard up, OK appears to do nothing."
If the keyboard is UP, tapping OK might not close the keyboard if the dialog doesn't pop.
Wait! If the keyboard is up, and they tap OK, DOES focus change?
Yes, in Flutter, tapping outside a `TextField` might shift focus if there is a `TapRegion` or if the `TextButton` gets focus.
But wait, if tapping OK DOES NOT shift focus, then `_endpointFocus.hasFocus` is STILL true!
If `_endpointFocus.hasFocus` is still true, then `_endpointCommitted` is NOT called!
If `_endpointCommitted` is not called, then `_modelController.text` is NOT cleared!
If `_modelController.text` is not cleared, why is it empty?

Wait! Look at `_save` again.
```dart
      final endpoint = _endpointController.text.trim();
      final model = _modelController.text.trim();

      final resolved = endpoint.isEmpty
          ? null
          : AiCredentialStorage.resolveEndpoint(endpoint);

      final modelError = model.isEmpty ? s.aiAssistModelRequiredLabel : null;
      if (endpointError != null || modelError != null) {
        setState(() {
          _endpointError = endpointError;
          _modelError = modelError;
        });
        return;
      }
```
If `model` is ALREADY empty, OK will refuse.
Why would `model` be ALREADY empty?
If they edited the address, they DID NOT type a model.
"editing the own-server address clears the model, and OK then looks dead"
Wait! If they edited the address, and DID NOT leave the field, the model field is NOT cleared.
But what if they typed the address, then hit "Done" on the keyboard?
Hitting "Done" on the keyboard calls `onSubmitted`!
```dart
onSubmitted: (_) => _endpointCommitted(),
```
If they hit "Done" on the keyboard:
1. `_endpointCommitted` is called.
2. It sets `_modelController.text = ''`.
3. It starts `_loadModels()`.
4. The keyboard might stay open (or close depending on Flutter's behavior, but it says "with the keyboard up, OK appears to do nothing", so maybe they didn't hit Done, or maybe they hit Done but the keyboard stayed up because the text field didn't lose focus, which matches `// covers the keyboard's own done key, which never moves focus anywhere.`).
5. Now the model field is EMPTY.
6. The fetch is running.
7. They tap OK.
8. `_save` runs. `model` is empty. It fails with `modelError`.
9. The fetch fails "a moment later".
10. The user thinks "the model field was emptied a moment later, once the fetch failed".
Actually, it was emptied IMMEDIATELY when they hit Done, but they didn't notice, or they thought the fetch failing caused it.

Wait, the issue title: "Editing the own-server address clears the model, and OK then looks dead".
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails."
Wait, if it empties it IMMEDIATELY, why would they say "a moment later"?
Perhaps they edited the address, tapped the "Load models" button!
If they tap "Load models", it calls `_loadModels()`.
Does `_loadModels` empty the model field?
No.
But wait! If they tap "Load models", DOES THAT UNFOCUS the endpoint field?
If it DOES unfocus the endpoint field, `_endpointCommitted` runs!
And `_endpointCommitted` clears the model field!
And `_endpointCommitted` calls `_loadModels()`!
So they tap "Load models" (or just tap outside), the model field is cleared, and the fetch starts.

What if the fix is simply:
```dart
<<<<<<< SEARCH
    setState(() {
      _modelController.text = '';
      _modelError = null;
    });
=======
    // Do not clear the model field when the endpoint is committed.
    // The user might have typed a model name, or might be about to type one.
    // If the endpoint changes, we shouldn't wipe the model they typed.
    setState(() {
      _modelError = null;
    });
>>>>>>> REPLACE
```
But wait! The comment says:
```dart
    // The model belonged to the address that just changed. #755 drops the
    // stored one on write for the same reason — `llama3.2:8b` is a claim
    // about one machine and says nothing about the next — and this is that
    // rule where the user can see it happen rather than discover it later.
    setState(() {
      _modelController.text = '';
      _modelError = null;
    });
```
So clearing it is INTENTIONAL to enforce #755!
"The model belonged to the address that just changed. ... `llama3.2:8b` is a claim about one machine and says nothing about the next".
So if the user changes the address, the OLD model is cleared, because it probably doesn't exist on the NEW server.
But wait! If the user TYPE a new model name, and THEN changes the address...
Or if the user changes the address, and the model field is cleared, they have to TYPE the new model name!
But wait!
If they edit the address, the model is cleared.
Then they type the model name.
Then they tap OK.
Why does OK fail with "Name the model"?
Because they DID NOT type a model name!
They edited the address, and expected the OLD model name to STILL WORK!
"Changing the address doesn't clear a model the user typed. Any validation error shows where the user can see it, for example by scrolling to the field."
Ah!!!
"Expected: Changing the address doesn't clear a model the user typed."
