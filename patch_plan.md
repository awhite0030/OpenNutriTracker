1. **Remove `_modelController.text = '';`** in `_endpointCommitted` in `lib/features/settings/presentation/widgets/ai_assist_dialog.dart`.
2. **Add `GlobalKey`s** for the endpoint field and the model field in `AiAssistDialogState`.
3. **Attach the keys** to the respective `TextField` widgets (or their wrapping `Semantics`).
4. **Add scroll logic** in `_save` when validation fails.
5. **Update test** `changing the address fetches, and drops the model that belonged to the old one` in `test/features/settings/presentation/ai_assist_dialog_test.dart` to expect the model text to be RETAINED, and rename the test to something like `changing the address fetches, and retains the model the user typed`.
6. Run `fvm flutter test test/features/settings/presentation/ai_assist_dialog_test.dart`.
