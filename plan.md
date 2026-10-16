1. **Understand the problem**:
   - The user states that in "Settings -> AI meal assistance -> Your own server", editing the server address empties the Model field a moment later, after the automatic model fetch fails.
   - When the Model field is empty, tapping "OK" refuses with the error "Name the model this server should use."
   - The error is below the fold with the keyboard open, so "OK" appears dead.
   - We know that `_endpointCommitted` calls `setState(() { _modelController.text = ''; ... })` and then `_loadModels()`.

2. **Diagnose the cause**:
   - The method `_endpointCommitted` is triggered when the user finishes with the address field.
   - It checks if the address changed. If it did, it clears the model text field explicitly via `setState({ _modelController.text = ''; ... })`.
   - The logic says: "The model belonged to the address that just changed. ... drops the stored one on write for the same reason ... rule where the user can see it happen rather than discover it later."
   - However, if the user edits the address *and has typed a new model themselves*, or if the fetch fails and it clears the *newly typed* model, it is frustrating.
   - Wait, if `_endpointCommitted` is triggered because focus moves, and the user just typed an address and moves to type a model... actually `_endpointCommitted` clears it if the address changed. But what if the user types an address, then taps "OK" (which unfocuses the address field, triggering `_endpointCommitted`, which clears the model field right as the OK button is processing)?
   - Wait, in `_endpointCommitted`:
     ```dart
     if (ModalRoute.of(context)?.isCurrent == false) return;
     final resolved = AiCredentialStorage.resolveEndpoint(_endpointController.text.trim());
     if (resolved == null || resolved == _lastEndpoint) return;
     setState(() {
       _modelController.text = '';
       _modelError = null;
     });
     ```
     But if the user *typed* a model, `_modelController.text` is not empty. If they tap OK, `_endpointCommitted` fires and clears the model they typed?
     Actually, if they tap the model field to type a model, `_endpointCommitted` fires (because focus leaves the endpoint field) and clears the model field. That's *fine* because it clears the *old* model before they type a new one. But wait, if they *paste* a model, or if the model was already typed.
     Wait, the issue says: "...once the automatic model fetch fails...".

   - Let's read the issue again: "editing the server address silently **empties the Model field** a moment later, once the automatic model fetch fails."
   - Ah! Look at `_loadModels()`:
     ```dart
     final result = await _modelList.list(...);
     if (!mounted || generation != _modelsGeneration) return;
     setState(() {
       _fetchingModels = false;
       _modelIds = result.failure == null ? result.ids : null;
       _modelListFailure = result.failure;
     });
     ```
     Wait, where does it empty the model field?
     Ah, `_loadModels()` does not empty the model field when it fails.
     Wait, look at how `DropdownButton` value is handled:
     ```dart
                value: ids.contains(_modelController.text)
                    ? _modelController.text
                    : null,
     ```
     If the fetch succeeds, `ids` is populated. If the user's typed model isn't in `ids`, the dropdown shows `null`. But it doesn't *clear* `_modelController.text`.

     Let's look at `_loadModels` again. Wait, where does the issue say it empties the model field *once the fetch fails*?
     Wait, look at `_endpointChanged`:
     ```dart
     void _endpointChanged() {
       setState(() {
         // ...
         _modelIds = null;
       });
     }
     ```
     No, `_endpointCommitted` calls `setState(() { _modelController.text = ''; })`.
     Ah! If the user types an address and *then types a model* quickly, or types a model, then goes back and edits the address, then taps OK. If they edit the address, they haven't "committed" it until they leave the field. If they leave the field by tapping OK, `_endpointCommitted` fires, clears the model they typed, and then OK evaluates with an empty model!

     Wait, look at test:
     ```dart
      testWidgets('moving an already-configured server to a new address saves '
          'both fields', (tester) async {
        // ... OK must still commit what is on screen. If leaving
        // the address field cleared the model on the way to the button, this
        // would refuse with "name the model" over a name the user just typed.
        // ...
        await typeEndpoint(tester, 'http://192.168.1.9:11434');
        await tester.enterText(
          find.bySemanticsIdentifier('ai-assist-model-field'),
          'qwen3:8b',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsIdentifier('ai-assist-save-key'));
     ```
     In this test, `typeEndpoint` probably enters text without unfocusing. Wait, `typeEndpoint` in tests might unfocus? Let's check `typeEndpoint`.
