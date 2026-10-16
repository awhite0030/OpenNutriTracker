Wait, look at `_endpointCommitted` AGAIN.
```dart
  void _endpointCommitted() {
    if (!mounted || _provider != AiProvider.ownServer) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final resolved = AiCredentialStorage.resolveEndpoint(
      _endpointController.text.trim(),
    );
    if (resolved == null || resolved == _lastEndpoint) return;
    setState(() {
      _modelController.text = '';
      _modelError = null;
    });
    _loadModels();
  }
```
If the user edits the server address.
Then they tap "OK".
"OK" removes focus. `_endpointCommitted` fires.
It clears `_modelController.text`.
Then it starts `_loadModels()`.
At the same time, `_save()` is executing!
`_save()` reads `final model = _modelController.text.trim()`.
Wait, if `_save()` reads it BEFORE `_endpointCommitted` clears it?
If they tap "OK", the onTap of OK runs. The focus loss might run *before* `onTap` or *after*.
If focus loss runs *before* `_save()`, then `_endpointCommitted` clears `_modelController.text` and sets `_modelError = null`.
Then `_save()` runs. It reads `_modelController.text` as EMPTY.
It sets `modelError = s.aiAssistModelRequiredLabel`.
It calls `setState(() { _modelError = modelError; })`.
So the dialog stays open, with `_modelError` set!
But `_loadModels()` is STILL RUNNING!
When `_loadModels()` fails (a moment later), it calls `setState({_fetchingModels = false})`.
The user sees the spinner stop, and they notice the model field is empty, and if they scroll down, they see the error!

Ah!!!
This perfectly matches the issue:
1. User types in `_endpointController`.
2. User types in `_modelController`?
Wait, if they type in `_modelController`, the endpoint field LOSES FOCUS.
If the endpoint field loses focus, `_endpointCommitted` runs.
It clears the model field (`_modelController.text = ''`).
It starts `_loadModels()`.
Then the user is in the model field. They type a model name!
Now `_modelController.text` has what they typed.
Then `_loadModels()` fails.
It calls `setState`.
Wait, if they already typed a model name, `_modelController.text` is NOT empty.
So tapping "OK" should succeed!

Wait, what if they DID NOT type a model name? What if it was ALREADY filled in from before?
"editing the own-server address clears the model, and OK then looks dead"
Issue: "editing the server address silently empties the Model field a moment later, once the automatic model fetch fails."

Wait! If `_endpointCommitted` clears the model field IMMEDIATELY, why did the issue author say "a moment later, once the automatic model fetch fails"?
Because the UI is rendering the `DropdownButton` while fetching?!
No! `if (_modelIds case final ids? when ids.isNotEmpty)`
While fetching, `_modelIds` is `null` (cleared by `_endpointChanged`), so the Dropdown is NOT SHOWN. Only the TextField is shown.
If the model field is emptied IMMEDIATELY by `_endpointCommitted`, it's not "once the automatic fetch fails".

Wait... look at the issue's link!
`https://github.com/simonoppowa/OpenNutriTracker/blob/research/settings-pixel-test/docs/settings-test/run-2026-10-11/results.md`
Let's fetch that file to see the evidence!
