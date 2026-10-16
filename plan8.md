So `_load()` is ONLY called in `initState`, `_selectProvider`, and `_remove`. None of these is "once the automatic model fetch fails".

Then WHY is the Model field "silently emptied"?
Wait! Look at `_loadModels` again. Does it call anything else?
```dart
    final result = await _modelList.list(
      url,
      apiKey: typedKey.isNotEmpty
          ? typedKey
          : await widget.storage.readApiKey(provider: provider),
    );
```
Wait! What if `result.ids` comes back empty or null, and the model that is CURRENTLY set in `_modelController.text` is rejected by the `DropdownButton`?
```dart
                value: ids.contains(_modelController.text)
                    ? _modelController.text
                    : null,
```
If `ids` does NOT contain `_modelController.text`, `value` is `null`.
But does that CLEAR `_modelController.text`?
No, `value: null` just means the Dropdown shows the `hint` ("Pick a model..."). It doesn't write back to the controller. The controller is only written back if `onChanged` fires.

Wait. Is it possible that `_endpointCommitted` is called a SECOND time?
1. User types in Endpoint field.
2. User taps "Load models" button. Focus does NOT leave Endpoint field.
3. Fetch starts.
4. Fetch fails.
5. User taps "OK" button.
6. When "OK" is tapped, `_save` is called.
BUT tapping "OK" makes the Endpoint field lose focus.
If it loses focus, `_endpointCommitted` fires!
Ah! If the user NEVER lost focus from the Endpoint field BEFORE they tapped "OK".
If the keyboard is open, and they tap OK:
When OK is tapped, the `TextButton` takes the hit. Focus might shift or the keyboard closes, causing `_endpointFocus.hasFocus` to become false.
`_endpointCommitted` fires!
`resolved != _lastEndpoint`?
Wait! In `_loadModels`, `_lastEndpoint = asking;` is set.
So `resolved == _lastEndpoint` IS TRUE!
So `_endpointCommitted` returns early!
```dart
    if (resolved == null || resolved == _lastEndpoint) return;
```
So it does NOT clear the model field.

Let's test this in a minimal script.
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails. Tapping OK then refuses with 'Name the model this server should use.'"

Wait, I think I see it!
When `_loadModels` sets `_lastEndpoint = asking`, what is `asking`?
```dart
    final typed = _endpointController.text.trim();
    final url = AiCredentialStorage.resolveModelsEndpoint(typed);
    if (url == null) {
      // ...
    }
    final asking = AiCredentialStorage.resolveEndpoint(typed);
```
And what is `resolved` in `_endpointCommitted`?
```dart
    final resolved = AiCredentialStorage.resolveEndpoint(
      _endpointController.text.trim(),
    );
    if (resolved == null || resolved == _lastEndpoint) return;
```

If `_endpointCommitted` clears the model, it means `resolved != _lastEndpoint`.
Why would `resolved != _lastEndpoint` be true after the fetch?
Wait, `_endpointCommitted` is called.
Is it possible that `_endpointCommitted` is called BEFORE the fetch finishes?
Yes! "editing the server address ... empties the Model field a moment later, once the automatic model fetch fails"
Wait!
"once the automatic model fetch fails" -> DOES the fetch failing DO something?
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
If the user edits the server address AFTER the fetch fails... no, the issue says "editing the server address silently empties the Model field a moment later, once the automatic model fetch fails."
Wait... The text "editing the server address silently empties the Model field a moment later"
If you edit the server address...
Wait! If `_loadModels` is called by `_endpointCommitted()`, it clears the model.
So editing the server address *and moving focus* (or hitting done) calls `_endpointCommitted()`, which clears the model field.
BUT `_modelController.text = ''` happens IMMEDIATELY in `_endpointCommitted()`.
Why does the user say it empties it "a moment later, once the automatic model fetch fails"?
Because `setState` in `_endpointCommitted()` triggers a rebuild, but the UI might not visibly update the TextField text until the keyboard settles, or maybe because the fetch starts and shows a spinner, and when the spinner stops, they notice the model field is empty?
OR maybe the user types the model name *while* the fetch is running, but they type it in the `_modelController`.
Wait! If they type the model name, `_modelController.text` is no longer empty.
If the fetch fails, `_loadModels` calls `setState`.
When `setState` is called, the widget rebuilds.
If the `TextField` loses its text on rebuild, why?
Because `_modelController.text` is empty? But they just typed in it!
Wait! Is `_modelController` being overwritten? No.
