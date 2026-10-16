Ah, I missed it. Look at `_endpointChanged` AND `_endpointCommitted`:
Wait, what triggers `_endpointCommitted`?
If you edit the endpoint, `_endpointChanged` fires, but `_lastEndpoint` is NOT updated.
Then `_endpointCommitted` fires when it loses focus, and `_lastEndpoint` is updated... wait, `_lastEndpoint` is updated IN `_loadModels`!
```dart
    setState(() {
      _fetchingModels = true;
      _modelIds = null;
      _modelListFailure = null;
      _modelListHost = AiCredentialStorage.displayHost(typed);
      _lastEndpoint = asking;
    });
```
Wait!
If the user edits the address, then types a model, then taps OK.
1. `_endpointChanged` fires as they edit the address.
2. They move focus to the model field.
3. `_endpointFocus` loses focus -> `_endpointCommitted` fires!
4. `_endpointCommitted` checks `if (resolved == null || resolved == _lastEndpoint) return;`
5. `resolved` is not null and NOT equal to `_lastEndpoint` (because `_lastEndpoint` is only updated when `_loadModels` runs, which is about to happen).
6. So `_endpointCommitted` does:
```dart
    setState(() {
      _modelController.text = '';
      _modelError = null;
    });
    _loadModels();
```
This clears the model they *were* about to type? No, they haven't typed yet, because focus just arrived.
7. So `_modelController.text` is emptied. That's fine.
8. Then `_loadModels()` is called. It sets `_fetchingModels = true` and `_lastEndpoint = asking`.
9. The user starts typing a model name. `_modelController.text` becomes `my-model`.
10. The fetch returns (e.g. fails).
11. `_loadModels()` calls `setState`:
```dart
    setState(() {
      _fetchingModels = false;
      _modelIds = result.failure == null ? result.ids : null;
      _modelListFailure = result.failure;
    });
```

Wait, does `TextField(controller: _modelController)` reset its text if `_modelController` is replaced or modified?
No, the controller is the SAME instance (`final _modelController = TextEditingController()`).

Wait, look at how the `DropdownButton` is written:
```dart
          // A **dropdown**, not a row per model: an Ollama host with twenty
          // pulled models would otherwise push the disclosure and the OK
          // button off a phone screen, and this dialog has already overflowed
          // once for less. One entry is an ordinary list here rather than a
          // special case — llama.cpp serves exactly the one file it was
          // started with, so a single-element reply is the normal shape and
          // gets the ordinary picker.
          if (_modelIds case final ids? when ids.isNotEmpty)
            Semantics(
              identifier: 'ai-assist-model-picker',
              child: DropdownButton<String>(
```
Notice `if (_modelIds case final ids? when ids.isNotEmpty)`!
If the fetch FAILS, `_modelIds` is `null`.
Wait! If `_modelIds` is `null`, the DropdownButton is REMOVED from the widget tree!

But what about the TextField?
```dart
          Semantics(
            identifier: 'ai-assist-model-field',
            child: TextField(
              controller: _modelController,
```
It's ALWAYS in the widget tree, right above the "Load models" button.

So why would the Model field be silently emptied once the automatic model fetch fails?
Could it be `_pickModel`?
Is `DropdownButton` triggering `onChanged(null)` when it's removed?
No, `DropdownButton` doesn't trigger `onChanged` when unmounted.
Wait... what if `_modelIds` starts as `null`.
Then `_loadModels` is called. `_modelIds` becomes `null`.
But the issue says "once the automatic model fetch fails".
Is it because the server responds with a SUCCESS but an EMPTY list?
```dart
          if (_modelIds case final ids? when ids.isNotEmpty)
```

Wait, what if the fetch *fails*? The issue specifically says "once the automatic model fetch fails".
Let's see the error message below:
`Tapping OK then refuses with "Name the model this server should use."`
The error is literally `aiAssistModelRequiredLabel`.

Let's search for `_modelController.text` being cleared again.
Where else is `_modelController.text` assigned?
In `_load()`:
```dart
_modelController.text = modelId ?? '';
```
In `_endpointCommitted()`:
```dart
_modelController.text = '';
```
In `_pickModel()`:
```dart
_modelController.text = id;
```

What if `_loadGeneration` race condition?
```dart
  Future<void> _load() async {
    // ...
    final summary = await widget.storage.readSummary(provider: provider);
    // ...
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _endpointController.text = summary.endpoint ?? '';
      _modelController.text = modelId ?? '';
```
When does `_load()` get called?
Only in `initState()` and `_selectProvider()`.
It is NOT called during fetch.

What about `_endpointCommitted` being called TWICE?
When focus is lost, `_endpointFocus.hasFocus` becomes `false`, so `_endpointCommitted` is called.
If the fetch is running, the user taps "OK".
Tapping "OK" removes focus from the MODEL field, NOT the address field! The address field already lost focus.
BUT wait! If the user edits the address field, and DOES NOT change focus, but directly taps "OK"!
If they type the address, the address field is FOCUSED.
They do NOT type a model. The model field is empty.
They tap "OK".
Tapping "OK" triggers focus to leave the address field!
So `_endpointFocus.hasFocus` becomes `false`.
`_onEndpointFocusChanged()` fires and calls `_endpointCommitted()`.
`_endpointCommitted` sees the address changed. It calls `_modelController.text = '';` and then `_loadModels()`.
BUT WAIT. The model field is ALREADY empty.
Why would the issue say "editing the server address silently **empties the Model field** a moment later"?
"A moment later" - meaning they edited the server address, they moved to the model field (which triggered `_endpointCommitted`), they typed a model... and then it was emptied?
Wait. If they moved to the model field, focus is lost, `_endpointCommitted` fires synchronously.
BUT `_endpointCommitted` checks `_lastEndpoint`.
What if `_lastEndpoint` is updated asynchronously?
```dart
    final resolved = AiCredentialStorage.resolveEndpoint(
      _endpointController.text.trim(),
    );
    if (resolved == null || resolved == _lastEndpoint) return;
```
If they type an address, and then tap "Load models".
"Load models" button is tapped. Focus is lost from the address field!
Wait, tapping a TextButton does NOT remove focus from a TextField in Flutter, unless it's explicitly done!
Wait, Flutter desktop/web vs mobile. On mobile, tapping outside might not remove focus unless there's a TapRegion.
Does `_loadModels` remove focus?
`_loadModels` does not explicitly remove focus.
But wait. "The **only** control that starts a fetch, alongside finishing with the address field. Never on open, never on a provider switch, never on a timer. #738."
If they hit "Done" on the keyboard:
```dart
onSubmitted: (_) => _endpointCommitted(),
```
This explicitly calls `_endpointCommitted()`.
If they hit "Done", `_endpointCommitted()` fires. It sets `_modelController.text = ''` and calls `_loadModels()`.
Then, while it is fetching, they type a model name.
Then `_loadModels` finishes. It fails.
Does it clear the model?
Wait... let's read `_loadModels` VERY carefully.
```dart
    final url = AiCredentialStorage.resolveModelsEndpoint(typed);
    if (url == null) {
      setState(() => _endpointError = s.aiAssistEndpointInvalidLabel);
      return;
    }
    final asking = AiCredentialStorage.resolveEndpoint(typed);

    if (_fetchingModels && asking == _lastEndpoint) return;

    final generation = ++_modelsGeneration;
    final provider = _provider;

    setState(() {
      _fetchingModels = true;
      _modelIds = null;
      _modelListFailure = null;
      _modelListHost = AiCredentialStorage.displayHost(typed);
      _lastEndpoint = asking;
    });

    final typedKey = _apiKeyController.text.trim();
    final result = await _modelList.list(
      url,
      apiKey: typedKey.isNotEmpty
          ? typedKey
          : await widget.storage.readApiKey(provider: provider),
    );

    if (!mounted || generation != _modelsGeneration) return;
    setState(() {
      _fetchingModels = false;
      _modelIds = result.failure == null ? result.ids : null;
      _modelListFailure = result.failure;
    });
```
