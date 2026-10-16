Ah wait, what about the fact that `DropdownButton` asserts on `value`?
If `_modelIds` is set, and it doesn't contain `_modelController.text`, it forces `null`.
Wait! `value: ids.contains(_modelController.text) ? _modelController.text : null,`
But does `_modelIds` being assigned `[]` or `null` clear the text field?
No, the text field is NOT controlled by the dropdown.

Let's look at the only lines assigning `_modelController.text`.
```dart
311:      _modelController.text = modelId ?? '';
454:      _modelController.text = '';
560:    _modelController.text = id;
```
If we can prove that `_endpointCommitted` is running AFTER `_loadModels` returns, then `_modelController.text = ''` is the culprit.
How could `_endpointCommitted` run "a moment later, once the automatic model fetch fails"?
Wait. Does `_loadModels` unfocus the endpoint field?
If the endpoint field was focused, and they tap "Load models", the text field does NOT lose focus automatically, unless the button explicitly removes it.
Wait! `_loadModels` is an `async` function.
What if `_loadModels` calls `setState` inside, and the UI rebuilds, and the text field LOSES FOCUS?
If the text field loses focus during the rebuild, `_endpointFocus.hasFocus` becomes `false`.
`_endpointCommitted` is called.
And it calls `_modelController.text = ''`.
Why would it lose focus on rebuild?
If the widget is rebuilt, and the text field is removed from the tree? No, it's not.
If the `_loadModels` sets `_fetchingModels = true`.
Look at the text field:
```dart
                        child: TextField(
                          controller: _endpointController,
                          focusNode: _endpointFocus,
```
Is `enabled: !_fetchingModels` set on the `TextField`?
Let's check if the text field is disabled during fetch!
If it is disabled, it LOSES FOCUS immediately!
