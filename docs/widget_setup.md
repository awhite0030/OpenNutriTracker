# iOS Widget Setup

This guide explains how the iOS Calorie Progress Widget is set up and how to run it locally.

## Development

The iOS widget is built using SwiftUI and WidgetKit. It requires App Groups to share data (like consumed calories and calorie goal) between the Flutter app (Runner) and the widget extension.

### Setting up App Groups
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the `Runner` target, go to **Signing & Capabilities**.
3. Click `+ Capability` and add **App Groups**.
4. Create or select an App Group. The bundle id is expected to be `group.com.opennutritracker`. Ensure this matches the `_appGroupId` in `lib/core/utils/home_widget_service.dart`.
5. Repeat the same for the `WidgetExtension` target.

### Release Signing
When releasing the app, ensure that both the `Runner` and `WidgetExtension` use an explicit provisioning profile that has App Groups enabled.

The data mapping between Flutter and iOS is verified in `test/unit_test/home_widget_service_test.dart`.
## Note to Developers
If you plan to modify or add additional widgets, remember that all flutter side persistence relies on the `home_widget` package. Ensure `App Groups` are configured properly for data propagation.
