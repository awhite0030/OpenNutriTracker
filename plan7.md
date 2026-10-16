Wait, look at line 311:
`_modelController.text = modelId ?? '';`
This is in `_load()`.
When is `_load()` called?
```dart
  Future<void> _load() async {
    final generation = ++_loadGeneration;
```
It is called in:
1. `initState()`
2. `_selectProvider()`
```dart
  Future<void> _selectProvider(AiProvider provider) async {
    if (provider == _provider) return;
    await widget.storage.setActiveProvider(provider);
    _apiKeyController.clear();
    // ...
    _load();
  }
```
Is `_load()` called anywhere else?
Let's search for `_load()`.
