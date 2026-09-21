# Installation Guide

## Method 1: CocoaPods (Recommended)

Add to your `Podfile`:

```ruby
platform :ios, '12.0'  # Use '13.0' instead if you add NRTHEOplayerTracker below
use_frameworks!

target 'YourApp' do
  pod 'NewRelicVideoAgent'
  pod 'NRAVPlayerTracker'
  pod 'NRIMATracker'         # Optional, for Google IMA ads
  pod 'NRTHEOplayerTracker'  # Optional, for THEOplayer (Dolby OptiView Player)
end
```

Install:
```bash
pod install
open YourApp.xcworkspace
```

> **Note:** THEOplayer support also requires a valid THEOplayer license from Dolby, picked up automatically from a `THEOplayerLicense` key in your app's `Info.plist` (see THEOplayer's own setup docs). This is separate from your New Relic application token.

## Method 2: Manual Build

### Prerequisites
- Xcode 14.0+
- iOS 12.0+

### Build Order

**1. Build NewRelicVideoCore** (required by all trackers)

```bash
# Device
xcodebuild -project NewRelicVideoCore/NewRelicVideoCore.xcodeproj \
  -scheme "iOS NewRelicVideoCore" \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  build

# Simulator
xcodebuild -project NewRelicVideoCore/NewRelicVideoCore.xcodeproj \
  -scheme "iOS NewRelicVideoCore" \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**2. Build NRAVPlayerTracker** (for AVPlayer)

```bash
# Device
xcodebuild -project NRAVPlayerTracker/NRAVPlayerTracker.xcodeproj \
  -scheme "iOS NRAVPlayerTracker" \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  build

# Simulator
xcodebuild -project NRAVPlayerTracker/NRAVPlayerTracker.xcodeproj \
  -scheme "iOS NRAVPlayerTracker" \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**3. Build NRIMATracker** (optional, for Google IMA ads)

First, download Google IMA SDK:
```bash
cd NRIMATracker
curl -L "https://imasdk.googleapis.com/downloads/ima/ios/GoogleInteractiveMediaAds-ios-v3.27.4.zip" -o GoogleIMA.zip
unzip -o GoogleIMA.zip && rm GoogleIMA.zip
cd ..
```

Then build:
```bash
# Device
xcodebuild -project NRIMATracker/NRIMATracker.xcodeproj \
  -scheme "NRIMATracker" \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  build

# Simulator
xcodebuild -project NRIMATracker/NRIMATracker.xcodeproj \
  -scheme "NRIMATracker" \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**4. Build NRTHEOplayerTracker** (optional, for THEOplayer — requires iOS 13.0+, per THEOplayerSDK-core's own minimum)

First, download THEOplayerSDK-core (a plain public xcframework zip — confirmed against its own real podspec, no CocoaPods roundtrip needed):
```bash
cd NRTHEOplayerTracker
curl -L "https://cdn.theoplayer.com/build/sdk-apple/10.14.0/THEOplayerSDK.xcframework.zip" -o THEOplayerSDK.zip
unzip -o THEOplayerSDK.zip && rm THEOplayerSDK.zip
cd ..
```

Then build:
```bash
# Device
xcodebuild -project NRTHEOplayerTracker/NRTHEOplayerTracker.xcodeproj \
  -scheme "NRTHEOplayerTracker-iOS" \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  build

# Simulator
xcodebuild -project NRTHEOplayerTracker/NRTHEOplayerTracker.xcodeproj \
  -scheme "NRTHEOplayerTracker-iOS" \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

You'll also need to add THEOplayerSDK.xcframework itself (from the zip above) to your project, plus a valid THEOplayer license from Dolby — same shape as the Google IMA requirement in step 3, just for THEOplayer.

### Framework Locations

Built frameworks are in `~/Library/Developer/Xcode/DerivedData/[ProjectName]-*/Build/Products/Release-[platform]/`

### Add to Your Project

**1. Copy frameworks to your project directory:**

```bash
cd /path/to/your/project
mkdir -p Frameworks

# Copy the frameworks you need
cp -R ~/Library/Developer/Xcode/DerivedData/NewRelicVideoCore-*/Build/Products/Release-iphonesimulator/NewRelicVideoCore.framework Frameworks/
cp -R ~/Library/Developer/Xcode/DerivedData/NRAVPlayerTracker-*/Build/Products/Release-iphonesimulator/NRAVPlayerTracker.framework Frameworks/
cp -R ~/Library/Developer/Xcode/DerivedData/NRIMATracker-*/Build/Products/Release-iphonesimulator/NRIMATracker.framework Frameworks/
```

**Note:** Replace `Release-iphonesimulator` with `Release-iphoneos` if building for device. For production, consider creating XCFrameworks that support both architectures.

**2. Add frameworks to Xcode:**

1. In Xcode, select your app target
2. Go to "General" tab → "Frameworks, Libraries, and Embedded Content"
3. Click "+" and then "Add Other..." → "Add Files..."
4. Navigate to your project's `Frameworks` folder
5. Select the `.framework` files
6. **Important:** Check "Copy items if needed"
7. Click "Add"
8. Set each framework to "Embed & Sign"

## Next Steps

See [ONBOARDING.md](ONBOARDING.md) for usage instructions.
