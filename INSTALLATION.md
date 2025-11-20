# Installation Guide

## Method 1: CocoaPods (Recommended)

Add to your `Podfile`:

```ruby
platform :ios, '12.0'
use_frameworks!

target 'YourApp' do
  pod 'NewRelicVideoAgent'
  pod 'NRAVPlayerTracker'
  pod 'NRIMATracker'  # Optional, for Google IMA ads
end
```

Install:
```bash
pod install
open YourApp.xcworkspace
```

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
unzip GoogleIMA.zip && rm GoogleIMA.zip
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

### Framework Locations

Built frameworks are in `~/Library/Developer/Xcode/DerivedData/[ProjectName]-*/Build/Products/Release-[platform]/`

### Add to Your Project

Drag the `.framework` files into your Xcode project and embed them in your app target.

## Next Steps

See [ONBOARDING.md](ONBOARDING.md) for usage instructions.
