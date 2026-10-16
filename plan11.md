Wait, `enabled` is NOT set to false on the endpoint field.
What about the Model field?
```dart
          Semantics(
            identifier: 'ai-assist-model-field',
            child: TextField(
              controller: _modelController,
              autocorrect: false,
```
Also not disabled.

Wait, if they hit "Done" on the keyboard.
```dart
onSubmitted: (_) => _endpointCommitted(),
```
If they hit "Done", `_endpointCommitted` runs.
It sets `_modelController.text = ''`.
Then it runs `_loadModels()`.
At this point the user sees the model field empty.
Then they tap it, and type the model name.
Then the fetch fails.
Does the fetch failing clear the field?
Wait, if `onSubmitted` ran, did `_endpointFocus` lose focus?
"the keyboard's own done key, which never moves focus anywhere."
Wait! If it never moves focus, `_endpointFocus.hasFocus` is still `true`!
If the user hits "Done" on the keyboard:
1. `_endpointCommitted` fires.
2. It sets `_modelController.text = ''`.
3. It starts `_loadModels`.
4. The user's focus is STILL in the endpoint field!
5. The user waits. The fetch is running.
6. The user decides to type a model name. They tap the Model field.
7. Tapping the Model field makes the endpoint field LOSE FOCUS!
8. `_endpointFocus.hasFocus` becomes `false`.
9. `_onEndpointFocusChanged()` fires, which calls `_endpointCommitted()` AGAIN!
10. `_endpointCommitted` checks `resolved == _lastEndpoint`.
Wait! `_loadModels` ALREADY set `_lastEndpoint = asking`.
So `resolved == _lastEndpoint` IS TRUE.
So it RETURNS EARLY.
It does NOT clear the model field!

Wait! What if `_loadModels` FAILS?
```dart
    setState(() {
      _fetchingModels = false;
      _modelIds = result.failure == null ? result.ids : null;
      _modelListFailure = result.failure;
    });
```
It does NOT reset `_lastEndpoint`.
So `_lastEndpoint` is STILL `asking`.
If they lose focus *after* it fails, `_endpointCommitted` STILL returns early!

Wait... Look at the issue description again:
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails. Tapping OK then refuses with 'Name the model this server should use.'"

"once the automatic model fetch fails"
Could the fetch failure somehow reset `_lastEndpoint`?
No, it does not.

Wait! Look at `_loadModels` again.
```dart
    final url = AiCredentialStorage.resolveModelsEndpoint(typed);
    if (url == null) {
      // The same refusal OK gives, on the same field, for the same text.
      setState(() => _endpointError = s.aiAssistEndpointInvalidLabel);
      return;
    }
    final asking = AiCredentialStorage.resolveEndpoint(typed);

    // **One request per address, not one at a time.** Finishing with the
    // address field and pressing the button can land in the same gesture —
    // tapping a control moves focus off the field — and two requests to
    // somebody's server for one act is one too many. That is a statement
    // about *this* address, though, and reading it as "busy" swallowed the
    // next one: typing a second address while the first was still out
    // cleared the model field, sent nothing, and then filled the picker with
    // the first server's models under the second server's address.
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
```
Wait! What if they TYPE a NEW address?
They type "192.168.1.9".
Then they immediately tap the Model field.
Focus changes!
1. `_endpointCommitted` fires.
2. `resolved != _lastEndpoint`. (Because `_lastEndpoint` is `192.168.1.5`).
3. `setState({_modelController.text = ''})`.
4. `_loadModels` is called.
5. `_loadModels` sets `_fetchingModels = true` and `_lastEndpoint = 192.168.1.9`.
At this point, the user is IN the Model field. They type "my-model".
`_modelController.text` is "my-model".
Then the fetch fails.
No clearing happens here!

Wait... what if they TYPE a new address, and they DO NOT leave the address field?
They are just typing.
`_endpointChanged` fires on every keystroke.
`_modelsGeneration` increments. `_fetchingModels = false`. `_lastEndpoint` is untouched.
Then the fetch... WAIT. There is NO automatic fetch on keystrokes.
"editing the server address silently empties the Model field a moment later, once the automatic model fetch fails."

If there is no automatic fetch on keystrokes, what triggers the "automatic model fetch"?
"once the automatic model fetch fails"
What is the "automatic model fetch"?
Could the fetch be initiated by `_load()`?
No, `_load()` doesn't fetch models.

Could it be that they tap OK?
1. They type a new address.
2. They tap OK.
3. Tapping OK unfocuses the address field.
4. `_endpointCommitted` runs!
5. It clears the Model field!
6. It calls `_loadModels()`!
7. Meanwhile, `_save` is executing!
8. `_save` reads the EMPTY Model field!
9. `_save` says "Name the model this server should use"!
10. The dialog stays open!
11. `_loadModels` is STILL RUNNING!
12. "a moment later", `_loadModels` fails, the spinner stops.
13. The user sees the spinner stop, sees the model field empty, and assumes "once the fetch failed, it emptied the field".
YES! THIS IS EXACTLY IT!

The user tapped OK!
When they tap OK, `_endpointCommitted` is triggered because focus left the endpoint field!
`_endpointCommitted` clears the model field, and starts the fetch!
`_save` runs concurrently, reads the EMPTY model field, and refuses!
Then "a moment later", the fetch fails (spinner stops).
The user thinks: "Ah, the fetch failed, and THAT'S what emptied the field!"
But actually, the field was emptied IMMEDIATELY when they tapped OK, because tapping OK triggered `_endpointCommitted`!
And because the field was emptied, OK failed!
And because OK failed, it looks like "OK did nothing" (because the error is below the fold).
Then the fetch fails a moment later, completing the illusion!

Let me verify this theory:
1. User edits the address. They DO NOT change focus. The address is now "http://new-address".
2. The user taps OK.
3. Tapping OK takes focus off the address field (if the keyboard dismisses, or if the button takes focus, though Flutter text buttons usually don't). BUT wait! Does tapping OK dismiss the keyboard?
YES, if `_save` has `FocusScope.of(context).unfocus()`?
Wait, does `_save` dismiss the keyboard?
Let's check `_save`.
