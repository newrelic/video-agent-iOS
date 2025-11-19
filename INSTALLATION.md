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

## Method 2: Manual Build of Frameworks

#### Steps:

1. Clone this repository.
2. Open each `.xcodeproj` in Xcode.
3. Select the scheme.
4. Build (Cmd+B).
5. Include the generated `.framework` in your project.


## Next Steps

Continue with [ONBOARDING.md](ONBOARDING.md) for configuration and usage.
