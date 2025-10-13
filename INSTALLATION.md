# New Relic Video Agent iOS - Installation Guide

This guide covers the two available installation methods for the New Relic Video Agent iOS.

## Method 1: CocoaPods (Recommended)

#### Steps:

1. **Add to your Podfile:**

   ```ruby
   platform :ios, '12.0'
   use_frameworks!

   target 'YourApp' do
     pod 'NewRelicVideoAgent'
     pod 'NRAVPlayerTracker'
     pod 'NRIMATracker'  # Optional for ads
   end
   ```

2. **Install:**
   ```bash
   pod install
   open YourApp.xcworkspace
   ```

## Method 2: XCFramework (Binary Distribution)

#### Steps:

1. **Build the XCFrameworks:**

   ```bash
   git clone -b stable https://github.com/newrelic/video-agent-iOS.git
   cd video-agent-iOS
   chmod +x build_xcframeworks.sh
   ./build_xcframeworks.sh
   ```

   This creates: `./XCFrameworks/NewRelicVideoCore.xcframework`, `./XCFrameworks/NRAVPlayerTracker.xcframework`, `./XCFrameworks/NRIMATracker.xcframework`

2. **Add frameworks to your Xcode project:**

   - Drag the 3 `.xcframework` files from `./XCFrameworks/` into your Xcode project
   - When prompted, choose "Copy items if needed" ✅
   - Make sure "Add to target" includes your app target ✅

3. **Configure embedding:**
   - Go to your app target → "General" tab → "Frameworks, Libraries, and Embedded Content"
   - Find the 3 frameworks you just added
   - Change each from "Do Not Embed" to **"Embed & Sign"**


## Next Steps

Continue with [ONBOARDING.md](ONBOARDING.md) for configuration and usage.
