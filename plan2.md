Wait, if `typeEndpoint` just uses `enterText`, it *does* unfocus the field implicitly if you later tap somewhere else? Actually `enterText` might not change focus.

Let's read the issue carefully:
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails."

Wait, how could it empty the field *once the fetch fails*?
Look at `_loadModels`:
```dart
    final result = await _modelList.list(...);

    // Dropping this one loses nothing: a newer request writes every field it
    // would have, and a provider switch has already cleared them.
    if (!mounted || generation != _modelsGeneration) return;
    setState(() {
      _fetchingModels = false;
      _modelIds = result.failure == null ? result.ids : null;
      _modelListFailure = result.failure;
    });
```
Wait, if `_modelIds` is updated to `null`, what happens in the build method?
Look at `_ownedModelsSection(BuildContext context, ThemeData theme, S s)`:
```dart
          // A **dropdown**, not a row per model ...
          if (_modelIds case final ids? when ids.isNotEmpty)
            Semantics(
              identifier: 'ai-assist-model-picker',
              child: DropdownButton<String>(
                // ...
                value: ids.contains(_modelController.text)
                    ? _modelController.text
                    : null,
                items: [ ... ],
                onChanged: (id) => id == null ? null : _pickModel(id),
              ),
            ),
```
Wait, if `_modelIds` is `null`, the Dropdown is NOT SHOWN. But the Model field is *always* shown:
```dart
          Semantics(
            identifier: 'ai-assist-model-field',
            child: TextField(
              controller: _modelController,
```

Wait, if it's always shown, what empties `_modelController`?
Ah, if the user edits the server address, `_endpointCommitted` is called *when they leave the field*. If they don't leave the field, but they tap OK... OK is a button, tapping it removes focus from the text field, triggering `_endpointCommitted`!
Let's see OK button:
```dart
        TextButton(
          onPressed: _save,
          child: Text(s.dialogOKLabel),
        ),
```
Tapping OK triggers `_save`. Wait, tapping OK also unfocuses the text field, which triggers the `FocusNode` listener:
```dart
  void _onEndpointFocusChanged() {
    if (!_endpointFocus.hasFocus) _endpointCommitted();
  }
```
If `_onEndpointFocusChanged` fires and calls `_endpointCommitted`, it sets `_modelController.text = ''`.
BUT it is synchronous? `_onEndpointFocusChanged` happens as focus changes. Tapping OK might change focus *before* or *during* `_save`?
No, the issue says: "editing the server address silently **empties the Model field** a moment later, once the automatic model fetch fails."
Wait... "once the automatic model fetch fails" implies that the clear happens asynchronously!

Why would the model field clear *asynchronously*?
Let's check if there's any other place `_modelController.text` is changed.
Search for `_modelController.text` assignments.
