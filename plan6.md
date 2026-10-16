Let's trace EXACTLY what happens when a user:
1. Types an address in the endpoint field. Focus is still in the endpoint field.
2. Taps the Model field to type a model name.
When they tap the Model field, two things happen:
a) The Model field gains focus.
b) The Endpoint field loses focus!

When the Endpoint field loses focus:
`_endpointFocus.hasFocus` becomes `false`.
`_onEndpointFocusChanged()` runs.
It calls `_endpointCommitted()`.
Inside `_endpointCommitted()`:
```dart
  void _endpointCommitted() {
    if (!mounted || _provider != AiProvider.ownServer) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final resolved = AiCredentialStorage.resolveEndpoint(_endpointController.text.trim());
    if (resolved == null || resolved == _lastEndpoint) return;
    setState(() {
      _modelController.text = ''; // <--- THIS
      _modelError = null;
    });
    _loadModels();
  }
```
Wait, if they tapped the Model field, focus moves *immediately*.
Flutter processes pointer events. A tap on the Model field puts the cursor in it, AND it unfocuses the Endpoint field.
Does `_endpointCommitted` clear the model field BEFORE or AFTER the user starts typing?
The user *just* tapped it. They haven't typed anything yet!
So `_modelController.text` is emptied. That's fine! They haven't typed the new model yet.

Wait... but what if they edit the endpoint AFTER typing a model?
They typed a model: "my-model".
Then they realize the address is wrong. They tap the endpoint field.
They edit the endpoint field. "http://new-address".
Then they tap "OK"!
When they tap "OK", the `TextButton` is pressed.
Wait, if they tap "OK", `_endpointFocus.hasFocus` becomes false because "OK" removes focus? NO. Buttons in Flutter don't request focus by default, so tapping "OK" doesn't necessarily unfocus the text field. BUT wait, if they tap "OK", `_save()` is called.
```dart
  Future<void> _save() async {
    // ...
    if (provider == AiProvider.ownServer) {
      final endpoint = _endpointController.text.trim();
      final model = _modelController.text.trim();
      // ...
      if (await widget.storage.writeOwnServerConfiguration(
        endpoint: endpoint,
        model: model,
        provider: provider,
      )) {
        changed = true;
      }
      // ...
    }
    // ...
    Navigator.of(context).pop(changed);
  }
```
If tapping OK *does* unfocus the endpoint field, `_endpointCommitted` runs.
Does `Navigator.pop` run first?
`_save` is `async`. It does `await _agreedBeforeAnythingIsStored(provider)`.
During this `await`, the event loop runs.
If focus is lost because the keyboard is dismissed, `_onEndpointFocusChanged` fires.
It calls `_endpointCommitted`.
`_endpointCommitted` checks `ModalRoute.of(context)?.isCurrent == false`.
Wait, `isCurrent` is still `true` because `pop()` hasn't been called yet! (It's waiting on `_agreedBeforeAnythingIsStored`).
So `_endpointCommitted` CONTINUES.
It checks `resolved == _lastEndpoint`. If it's a NEW endpoint, it passes.
It calls `setState(() { _modelController.text = ''; })`.
Then `_save` resumes, reads `_modelController.text`? NO, `_save` ALREADY read `_modelController.text` at the top!
```dart
      final endpoint = _endpointController.text.trim();
      final model = _modelController.text.trim();
```
Ah! `_save` captures `model` at the very top.
If `_modelController.text` is cleared *after* it's captured, `_save` still tries to write the *old* model. But wait, `writeOwnServerConfiguration` will save it!
If it saves successfully, then `Navigator.pop` is called. The dialog closes.
But the issue says:
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails. Tapping OK then refuses with 'Name the model this server should use.'"

Wait! "once the automatic model fetch fails"
This implies the user was *waiting* for the fetch to fail, and THEN tapped OK!
Why would the model field empty "once the automatic model fetch fails"?
Let's reread `_loadModels` AGAIN.
```dart
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
This DOES NOT clear `_modelController.text`.

Wait! Look at `_loadModels` carefully. Does `result.ids` returning empty list cause a problem?
If `_modelIds` is set to `null` or `[]`.
If `_modelIds` is set, does the Dropdown change `_modelController.text`?
No.

Wait. Is it possible that `_modelController.text = ''` is happening in `_endpointCommitted` AFTER the user starts typing?
Imagine this sequence:
1. User types in `_endpointController`.
2. User taps on `_modelController` and starts typing.
When they tap, `_endpointFocus` loses focus.
So `_endpointCommitted` is called.
It does `_modelController.text = ''`.
AND it calls `_loadModels()`.
3. The user types "gemma" in the model field.
4. The fetch is running... running...
5. The fetch fails!
Does the model field empty "once the fetch fails"?
Wait. Is there a `FocusNode` on the Model field?
No.

What if the user edits the server address.
Then they tap "Load models".
"Load models" button is pressed. It calls `_loadModels()`.
`_loadModels()` checks if the address is valid, sets `_lastEndpoint = asking`, sets `_fetchingModels = true`, and starts the fetch.
Wait, "Load models" button does NOT unfocus the endpoint field!
If they tap "Load models", the keyboard might stay open, and the endpoint field might still be focused.
While the fetch is running, the user taps the Model field to start typing.
When they tap the Model field, the endpoint field LOSES FOCUS.
So `_endpointCommitted()` runs!
`_endpointCommitted()` checks:
```dart
    final resolved = AiCredentialStorage.resolveEndpoint(
      _endpointController.text.trim(),
    );
    if (resolved == null || resolved == _lastEndpoint) return;
```
But wait! `_loadModels()` ALREADY set `_lastEndpoint = asking`!
So `resolved == _lastEndpoint` is TRUE!
So `_endpointCommitted` RETURNS EARLY!
It does NOT clear the model field.

Wait, what if they don't tap "Load models"?
They edit the address. They just wait.
Wait, there is no timer. "never on a timer. #738."

How can the model field be emptied "once the automatic model fetch fails"?
Let's check if the issue reporter was confused about the cause and effect.
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails."
If the fetch fails, `setState` is called.
When `setState` is called, the widget rebuilds.
When the widget rebuilds, `_modelController` is used to build the `TextField`.
Is `_modelController.text` being overwritten?
Wait! Look at the `DropdownButton` again:
```dart
          if (_modelIds case final ids? when ids.isNotEmpty)
            Semantics(
              identifier: 'ai-assist-model-picker',
              child: DropdownButton<String>(
                // ...
                value: ids.contains(_modelController.text)
                    ? _modelController.text
                    : null,
                items: [
                  for (final id in ids)
                    DropdownMenuItem( ... )
                ],
                onChanged: (id) => id == null ? null : _pickModel(id),
              ),
            ),
```
If the fetch fails, `_modelIds` is `null`. So the `DropdownButton` is NOT built.
If the fetch succeeds, `_modelIds` is built.

Wait, is there any OTHER listener on `_endpointController`?
Look at `_endpointChanged()`:
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
This is hooked to `onChanged: (_) => _endpointChanged(),` of the Endpoint TextField.
Every time the user types a character in the endpoint field, `_endpointChanged` calls `setState`.

Wait! I see it!
When the user edits the server address...
Wait, "once the automatic model fetch fails"
What if the issue reporter is using the term "automatic model fetch" to refer to the probe? (#735's probe)
```dart
      // The other half of the supersede above, and easy to leave out: a
      // request abandoned across the reload no longer turns this off itself,
      // and left set it disables the button for the rest of the dialog's
      // life over an answer nobody wants any more.
      _fetchingModels = false;
      _probe = probe;
      _probing = running != null;
```
Wait, the probe happens when?
The probe happens when the dialog is opened, OR after `_save`!
```dart
        // **Started, never awaited.** #735: saving succeeds on syntax exactly
        // as it did before this existed, and the check runs behind it — so
        // someone configuring the app on a train, away from their server,
        // saves fine and the camera turns up later once a check has passed
        // against a reachable box.
        unawaited(_runProbe(provider, endpoint, model));
```
But `_runProbe` is only called AFTER OK is tapped!

Wait, let's re-read the issue:
"In Settings → AI meal assistance → Your own server, editing the server address silently empties the Model field a moment later, once the automatic model fetch fails. Tapping OK then refuses with "Name the model this server should use.", but that error sits below the fold of the dialog, so with the keyboard up, OK appears to do nothing."

This sequence happens BEFORE tapping OK!
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails. Tapping OK then refuses..."
This definitely happens BEFORE OK is tapped.
So "automatic model fetch" must be `_loadModels()`.

Why is it "automatic"?
Because `_endpointCommitted()` triggers it!
```dart
    setState(() {
      _modelController.text = '';
      _modelError = null;
    });
    _loadModels();
```
When they edit the server address and then MOVE FOCUS to the model field (e.g. to type the model), the `_endpointFocus.hasFocus` becomes false.
`_endpointCommitted` is called.
It clears `_modelController.text = ''`.
AND it calls `_loadModels()`.
At this exact moment, the user starts typing in the Model field!
So `_modelController.text` contains "my-model".
Then `_loadModels()` takes "a moment". It tries to connect. It times out or fails (e.g. 5 seconds later).
Then `_loadModels` calls:
```dart
    setState(() {
      _fetchingModels = false;
      _modelIds = result.failure == null ? result.ids : null;
      _modelListFailure = result.failure;
    });
```
Does `setState` empty the model field?
NO. `setState` just triggers a rebuild. The `TextField` keeps the state of `_modelController`.
Wait, does it?
Is `_modelController` re-created?
No, it's `final _modelController = TextEditingController();`.

Wait... is there ANY OTHER code that clears `_modelController` asynchronously?
Let's search for `_modelController.text =` in the ENTIRE file.
