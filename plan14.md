We can add GlobalKeys!
```dart
  final _endpointFieldKey = GlobalKey();
  final _modelFieldKey = GlobalKey();
```
Then wrap the `Semantics` or `TextField` with those keys.
```dart
                      Semantics(
                        key: _endpointFieldKey,
                        identifier: 'ai-assist-endpoint-field',
                        child: TextField(...)
```
And in `_save`:
```dart
      if (endpointError != null || modelError != null) {
        setState(() {
          _endpointError = endpointError;
          _modelError = modelError;
        });

        // Let the setState render the error first, then scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final targetContext = endpointError != null
              ? _endpointFieldKey.currentContext
              : _modelFieldKey.currentContext;
          if (targetContext != null) {
            Scrollable.ensureVisible(
              targetContext,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          }
        });
        return;
      }
```

Let's check the rest of `_save`.
```dart
    if (provider == AiProvider.ownServer) {
      final endpoint = _endpointController.text.trim();
      final model = _modelController.text.trim();

      final resolved = endpoint.isEmpty
          ? null
          : AiCredentialStorage.resolveEndpoint(endpoint);

      final endpointError = resolved == null
          ? s.aiAssistEndpointInvalidLabel
          : _refusedBeforeItLeaves(resolved)
          ? s.aiAssistEndpointPublicPlaintextLabel
          : null;
      final modelError = model.isEmpty ? s.aiAssistModelRequiredLabel : null;
      if (endpointError != null || modelError != null) {
        setState(() {
          _endpointError = endpointError;
          _modelError = modelError;
        });
        // add scroll logic here
        return;
      }
```

Wait, what if the error is on the API key?
```dart
    } else {
      final key = _apiKeyController.text.trim();
      if (key.isEmpty && _hasKey) {
        // ...
      } else if (key.isEmpty && !_hasKey) {
        // ...
      }
      // There is no validation error for the API key in _save, it just saves it or clears it.
    }
```
Yes, `endpointError` and `modelError` are the only validation errors in `_save`.

Wait, the issue also says:
"Changing the address doesn't clear a model the user typed."

If I just comment out `_modelController.text = '';` in `_endpointCommitted`:
```dart
    setState(() {
      // _modelController.text = '';
      _modelError = null;
    });
```
Will this keep the model the user typed? Yes.
Will this also keep the stored model if the user didn't type anything? Yes.
Is that acceptable? "Changing the address doesn't clear a model the user typed."
If they change the address, and the stored model is kept, and they submit, it writes the stored model to the new address. If that model exists on the new server, great. If not, it will fail later when they try to use it. This seems much better than silently clearing it and confusing the user.

Let's test this in code.
