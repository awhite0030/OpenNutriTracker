Wait, if it's not explicitly `_modelController.text = ''` that happens *after* the fetch fails...
Wait, look at `_loadModels`:
Could it be `DropdownButton` value mismatch?
```dart
                value: ids.contains(_modelController.text)
                    ? _modelController.text
                    : null,
                items: [
                  for (final id in ids)
                    // ...
                ],
                onChanged: (id) => id == null ? null : _pickModel(id),
```
Wait! What if `_loadModels` triggers a rebuild, and some widget clears it? No.
Let's re-read the issue.
"In Settings → AI meal assistance → Your own server, editing the server address silently empties the Model field a moment later, once the automatic model fetch fails. Tapping OK then refuses with 'Name the model this server should use.', but that error sits below the fold of the dialog, so with the keyboard up, OK appears to do nothing."

"once the automatic model fetch fails"
Wait... `_loadModels()` is called by `_endpointCommitted()`. But it is *also* called by the "Load models" button.
If the automatic fetch fails, it sets `_modelIds = null` and calls `setState`.
Wait, look at `_endpointChanged`:
```dart
  void _endpointChanged() {
    setState(() {
      _endpointError = null;
      _modelsGeneration++;
      _fetchingModels = false;
      _modelIds = null;
      _modelListFailure = null;
      _modelListHost = null;
    });
  }
```
If the user edits the server address, `_endpointChanged` fires *on every keystroke*.
But `_endpointCommitted` is fired by `onSubmitted` OR by focus leaving the address field!

Wait! `_endpointCommitted` has this guard:
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
If the user types the server address, `_endpointCommitted` is *not* called until they leave the field.
But what if the automatic model fetch *was already running*?
Wait, if they edit the server address and move to the Model field, they type a model name. BUT moving to the model field triggers `_endpointCommitted()` (because `_endpointFocus` lost focus).
`_endpointCommitted()` triggers `setState({ _modelController.text = ''; })`! That clears what they were about to type or just typed?
Wait, if they move focus to the model field, `_modelController.text = ''` is called immediately. Then `_loadModels()` is called, which is asynchronous.
Why does the issue say "silently empties the Model field a moment later, once the automatic model fetch fails"?
Is there another fetch? Wait! "once the automatic model fetch fails" - could it be that `_loadModels()` itself clears the model? No, I checked `_loadModels()` and it does not touch `_modelController`.

Wait. Let's look at `_save()`!
```dart
      final resolved = endpoint.isEmpty
          ? null
          : AiCredentialStorage.resolveEndpoint(endpoint);
```
Wait, if they tap OK, and it refuses, they might not see it.

Could the model be cleared because `_loadModels()` triggers a re-render and a bug in `TextEditingController`? No.

Wait. What if `_modelController.text` is changed by `_endpointCommitted` when the automatic model fetch *returns*?
No, `_endpointCommitted()` calls `setState` immediately.
But what if `_endpointCommitted` is called *delayed*? No.

Ah! What if they edit the server address and **leave it focused**, and then tap OK.
Tapping OK triggers `_save`.
`_save` calls:
```dart
      if (!await _agreedBeforeAnythingIsStored(provider)) return;

      if (await widget.storage.writeOwnServerConfiguration(...))
```
Wait, `_save` is `async`.
When they tap OK, the keyboard closes, which might trigger `_endpointFocus` to lose focus!
If `_endpointFocus` loses focus, `_endpointCommitted` runs!
If `_endpointCommitted` runs, it calls `setState(() { _modelController.text = ''; })` and then starts `_loadModels()`.
BUT `_save` is ALSO running!
`_save` reads:
```dart
      final endpoint = _endpointController.text.trim();
      final model = _modelController.text.trim();
```
If `_endpointFocus` lost focus *during* `_save`, or right before `_save` reads `_modelController.text`, wait.
If they tap OK, focus changes synchronously before the button's `onPressed`? Or during it?
Actually, the issue says:
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails. Tapping OK then refuses..."
This sequence implies:
1. User edits server address.
2. User does *something* that triggers the fetch (moves focus off the address, or taps "Load models", or hits "Done" on the keyboard).
3. The automatic model fetch starts. (A spinner appears).
4. The user types a model name *while* the fetch is running!
5. The automatic model fetch fails.
6. The Model field is silently emptied!
7. Tapping OK then refuses.

Wait... if they type a model name *while the fetch is running*, and then the fetch fails... why would the model field empty?
Let's look at `_loadModels` again!
```dart
    final result = await _modelList.list(
      url,
      apiKey: typedKey.isNotEmpty
          ? typedKey
          : await widget.storage.readApiKey(provider: provider),
    );

    // Dropping this one loses nothing: a newer request writes every field it
    // would have, and a provider switch has already cleared them.
    if (!mounted || generation != _modelsGeneration) return;
    setState(() {
      _fetchingModels = false;
      _modelIds = result.failure == null ? result.ids : null;
      _modelListFailure = result.failure;
    });
```
This does NOT clear `_modelController.text`.

Wait! Look at `_load`!
```dart
  Future<void> _load() async {
    final generation = ++_loadGeneration;
    // ...
    final summary = await widget.storage.readSummary(provider: provider);
    // ...
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      // ...
      _endpointController.text = summary.endpoint ?? '';
      _modelController.text = modelId ?? '';
```
Could `_load` be called again?
"once the automatic model fetch fails" -> Is `_load` called on failure? No.

Wait. Is it possible that `_endpointCommitted` is called *after* the fetch fails?
No, `_endpointCommitted` *starts* the fetch.

Let's read the issue again carefully:
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails. Tapping OK then refuses with 'Name the model this server should use.'"

Wait! If the fetch fails, maybe the widget rebuilds, and the `TextField` loses its state?
No, `_modelController` is a `TextEditingController` initialized in `initState` and held in the `State`.

Wait. Could it be `_pickModel` being called with `null`?
```dart
onChanged: (id) => id == null ? null : _pickModel(id),
```
No.

What if they edit the server address...
Wait, look at `_endpointChanged()`:
```dart
  void _endpointChanged() {
    setState(() {
      _endpointError = null;
      _modelsGeneration++;
      _fetchingModels = false;
      _modelIds = null;
      _modelListFailure = null;
      _modelListHost = null;
    });
  }
```
If they edit the address, they change it, which calls `_endpointChanged`. This kills any ongoing fetch (`generation != _modelsGeneration`).
Then they leave the field, which calls `_endpointCommitted()`.
```dart
  void _endpointCommitted() {
    if (!mounted || _provider != AiProvider.ownServer) return;
    // ...
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
Wait! If they edit the address, they tap on the Model field to type.
When they tap on the Model field, the address field LOSES FOCUS.
So `_endpointCommitted` is called.
`_endpointCommitted` does two things:
1. `_modelController.text = '';`
2. `_loadModels();`
At this point, the cursor is in the Model field, and the user starts typing.
BUT `_loadModels()` is `async`.
Is it possible that `_modelController.text = ''` is happening *after* they started typing?
No, focus loss happens immediately when they tap the Model field. So `_modelController.text = ''` happens before they can type.
Wait, if they hit "Done" on the keyboard for the address field, `onSubmitted` calls `_endpointCommitted()`.
Then the model fetch starts. The user taps the Model field and starts typing.
Then the fetch fails. Does `setState` in `_loadModels()` clear the text?
No! `setState` in `_loadModels()` just sets `_fetchingModels = false; _modelIds = null;`
Does a rebuild of the `TextField` with `controller` clear the text? NO.
