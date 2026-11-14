# PinkyLite for iPhone: unsigned build

This directory prepares an unsigned, arm64 iPhone IPA from DIYgod/pinky
v2026.1114.2. No Apple ID, password, device identifiers, provisioning profile,
or signing certificate is needed for the build. The output is not an official
release and will need development signing before it can run on an iPhone.

The workflow uses GitHub's standard xcode-27 runner. It verifies the SHA-256
of Pinky's official Xcode build kit and the WebDriverAgent file-tree hash
pinned by Pinky, then builds the Lite scheme and embeds the WebDriverAgent
test bundle according to Pinky's build recipe. The uploaded artifact contains
the IPA, its SHA-256, and the Xcode version. Artifacts expire after one day.

Review and run the workflow manually. On Windows, use a local sideload tool to
sign for the target iPhone and retain the embedded WebDriverAgent components.
Validate app launch and desktop Pinky's ability to start WebDriverAgent
separately; installing an app icon is not a test of phone control.

Sources:
- https://github.com/DIYgod/pinky/releases/tag/v2026.1114.2
- https://github.com/DIYgod/pinky/blob/v2026.1114.2/ios/README.md
- https://github.com/DIYgod/pinky/blob/v2026.1114.2/docs/notes/iphone-app.md
