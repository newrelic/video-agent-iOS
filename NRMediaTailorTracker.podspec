#
# Be sure to run `pod lib lint NRMediaTailorTracker.podspec' to ensure this is a
# valid spec before submitting.
#

Pod::Spec.new do |s|
  s.name             = 'NRMediaTailorTracker'
  s.version          = '4.2.0'
  s.summary          = 'New Relic Video Agent, AWS MediaTailor Ads Tracker.'

  s.description      = <<-DESC
  New Relic Video Agent, AWS MediaTailor Ads Tracker. Detects MediaTailor
  server-side-stitched ads inside an AVPlayer stream and emits ad telemetry
  events in parity with NRIMATracker. HLS only for first release.
                       DESC
  s.homepage         = 'https://github.com/newrelic/video-agent-iOS'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'New Relic' => 'support@newrelic.com' }
  s.source           = { :git => 'https://github.com/newrelic/video-agent-iOS.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '13.0'

  s.swift_versions = ['5.0']

  s.source_files = 'NRMediaTailorTracker/NRMediaTailorTracker/**/*.{swift,h,m}'
  s.public_header_files = 'NRMediaTailorTracker/NRMediaTailorTracker/**/*.h'

  s.resource_bundles = {
    'NRMediaTailorTracker_Privacy' => ['NRMediaTailorTracker/PrivacyInfo.xcprivacy']
  }

  s.dependency 'NewRelicVideoAgent'
end
