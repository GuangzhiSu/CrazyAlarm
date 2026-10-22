# CrazyAlarm

A native SwiftUI alarm app for iPhone, targeting iOS 26+ and iPhone 17 Pro Max. The interface features a dark background, cyan mission cards, and a red save button.

## Version 1.1.1: Permission Checks and Reliable Alarm Updates

- Editing only missions or quiz answers preserves an existing system alarm instead of scheduling the same ID again. Time, recurrence, title, and sound changes replace that alarm, with rollback if scheduling or saving fails.
- Before enabling an alarm, the app requests and verifies only the permissions required by its selected missions. Camera tasks require camera access; speech requires microphone and speech recognition access; step counting requires Motion & Fitness access. Shaking checks raw motion sensor availability and does not request step-history access.
- Alarm editing, mission configuration, and app settings show permission status. Previously denied permissions link to iOS Settings. Runtime checks remain in place if access changes later.
- Quiz, typing, math, symbol, and color tasks do not request sensor permissions. Reference photos stay in the app's storage and do not require Photo Library access.

## Version 1.1: Combine Your Wake-Up Missions

Choose and reorder missions for each alarm. Complete every selected mission in order to stop the music playing inside the app. The original two-question quiz remains available, and existing alarms and unfinished quiz progress migrate to the new version.

- **Custom Quiz:** Answer two questions you define. Incorrect answers do not advance progress.
- **Household Item Hunt:** Photograph a specified cup, bottle, book, keyboard, chair, or shoe. Apple Vision classifies the image on-device and checks a confidence threshold.
- **Say the Word on Beat:** On-device Mandarin or English speech recognition checks both the word and its audio timestamp. Includes three preparation beats, adjustable tempo and repetitions, and a maximum of one accepted response per beat.
- **Find Color Tiles:** Find the tile with a different color. Randomized layouts support 3×3, 4×4, and 5×5 difficulty levels.
- **Typing:** Type a custom sentence, with a configurable number of repetitions.
- **Math:** Solve randomly generated arithmetic questions across three difficulty levels. Division questions always have integer answers.
- **Missing Symbol:** Choose the correct addition, subtraction, multiplication, or division symbol. Generated questions have one correct answer.
- **Steps:** Count new steps after the mission starts. Requires Motion & Fitness permission and saves accumulated progress.
- **QR / Barcode:** Bind a code by scanning it or entering its contents during setup, then scan the exact same code when the alarm rings.
- **Shake:** Count distinct shakes using acceleration with gravity removed, a return-to-rest threshold, and debouncing.
- **Photo Match:** Capture a reference photo, then photograph the same object when the alarm rings. Vision compares image feature distances, with adjustable matching strictness.
- **Squat:** The front camera detects hips, knees, and ankles on-device. A repetition requires a complete standing → crouching → standing cycle with multiple stable frames. Tracking resets after prolonged occlusion.

Mission progress and the current random question persist between launches. Camera and speech permissions are requested when needed. Photos stay on the device; speech audio is neither saved nor uploaded. No paid AI service is required. Recognition depends on lighting, viewing angle, posture, and available system speech resources, so test each mission on your own phone before relying on it.

## Alarms and Music

AlarmKit provides Lock Screen alerts. Tap the alert's mission button to open the app. Both weekly recurring and one-time alarms are supported. The app includes an original Morning Spark ringtone and can import unencrypted audio from Files. System alerts use the first 28 seconds; the full track loops during missions. Speech missions lower the music volume and use echo processing while recording; music continues during the other missions.

The app cannot control the iOS system stop button, device volume, phone calls, force-quitting, shutdown, permission changes, or signing expiration. Mission screens do not open automatically from the background; tap the Lock Screen alert's mission button. Camera, speech, and motion verification require the app to remain in the foreground.

QQ Music account integration is still pending. It requires application credentials issued by QQ Music's OpenID / OpenAPI platform; a personal QQ account or music subscription cannot replace those credentials. This version clearly marks the integration as awaiting official access.

## Free Installation and Updates

See the [Windows / SideStore installation and update guide](docs/WINDOWS-INSTALL.md). If SideStore is already installed, import the new IPA to update CrazyAlarm in place without uninstalling the previous version. Use the same Apple Account and Bundle ID to preserve alarms, questions, and music.

Free signing is valid for seven days. Connect your phone to Wi-Fi and LocalDevVPN, then use **SideStore → My Apps → Refresh All** to refresh both SideStore and CrazyAlarm. Refreshing every five to six days is recommended. The computer does not need to stay on. An iOS update or an invalid pairing file may require pairing again with a computer.

## Build and Validation

Open `CrazyAlarm.xcodeproj` in Xcode 26.1 or later. No CocoaPods, paid SDKs, or additional model downloads are required. GitHub Actions runs tests on a standard macOS runner and produces an unsigned IPA. SideStore signs the IPA with your personal Apple Account during installation.

```sh
swift test
xcodebuild -project CrazyAlarm.xcodeproj -scheme CrazyAlarm -sdk iphoneos \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

The Swift package contains 40 logic tests covering mission ordering, migration of existing data, restoration of progress and random questions, exact barcode matching, question correctness, shake and squat debouncing, speech timing, quizzes, scheduling, daylight saving time, alarm replacement and rollback, and permission preflight. Camera, microphone, and motion recognition accuracy require testing on a physical device; logic tests cannot replace that validation.

Version 1.0 installation, Lock Screen ringing, stopping music after two correct answers, and wireless refreshing were verified by the user on an iPhone 17 Pro Max. The new sensor-based missions in version 1.1 still require individual validation after updating.

## Physical Device Checklist

1. After updating in place, confirm that existing alarms, quiz answers, and local music remain available. Test individual missions before testing a sequence of mixed missions.
2. Preview each new mission and grant its required permissions. Incorrect answers, unrelated codes, and mismatched photos must not advance progress. Denied permissions should produce a recoverable error.
3. For speech, test incorrect words, correct words spoken off-beat, and repeated recognition results. Step counting should only accept new steps, and shaking should only count distinct movements.
4. For squats, test standing still, occlusion, and crouching without standing back up. Camera capture should stop when leaving the camera view or backgrounding the app.
5. Test photo matching with different angles of the same object and with unrelated objects. Adjust matching strictness as needed.
6. Set a one-time alarm for approximately two minutes later, lock the phone, and wait. Open the app using the alert's mission button and confirm that music stops only after every mission is complete.
7. Switch apps or restart mid-mission, then return and confirm that accumulated progress and the current random question are preserved. Check that music volume recovers after recording ends.
8. Refresh wirelessly through SideStore and reopen the app.

## Official References

- [AlarmKit](https://developer.apple.com/documentation/alarmkit)
- [Vision image classification](https://developer.apple.com/documentation/vision/vnclassifyimagerequest)
- [Vision body pose detection](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- [Speech on-device recognition](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
- [SideStore installation guide](https://docs.sidestore.io/docs/installation/install)
- [Apple's free Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account)
