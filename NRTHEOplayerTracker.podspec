#
# Be sure to run `pod lib lint NRTHEOplayerTracker.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NRTHEOplayerTracker'
  s.version          = '4.3.0'
  s.summary          = 'New Relic Video Agent, THEOplayer Tracker.'

  s.description      = <<-DESC
  New Relic Video Agent, THEOplayer Tracker. Contains a tracker for THEOplayer (Dolby OptiView Player).
                       DESC
  s.homepage         = 'https://github.com/newrelic/video-agent-iOS'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'New Relic' => 'video-agent@newrelic.com' }
  s.source           = { :git => 'https://github.com/newrelic/video-agent-iOS.git', :tag => "v#{s.version}" }

  # iOS-only by scope, not by SDK limitation — THEOplayerSDK-core 10.14.0 does ship a tvOS 13.0 xcframework
  # slice too (confirmed against its own real podspec: platforms = {ios: '13.0', tvos: '13.0'}), so a
  # future NRTHEOplayerTracker for tvOS is possible; just not part of this work.
  #
  # 13.0 (one major above NRAVPlayerTracker's 12.0) is not an arbitrary choice or a follow-up-PR Swift
  # feature dependency — it's THEOplayerSDK-core 10.14.0's own real minimum, confirmed directly against
  # its podspec (platforms.ios = '13.0'), not something this pod could lower to 12.0 while depending on
  # this SDK version.
  s.ios.deployment_target = '13.0'

  s.swift_version = '5.0'

  s.source_files = 'NRTHEOplayerTracker/NRTHEOplayerTracker/**/*.swift'

  s.dependency 'NewRelicVideoAgent'
  s.ios.dependency 'THEOplayerSDK-core', '~> 10.14'
end
