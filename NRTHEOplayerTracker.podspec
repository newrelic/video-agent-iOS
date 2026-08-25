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

  s.ios.deployment_target = '13.0'

  s.swift_version = '5.0'

  s.source_files = 'NRTHEOplayerTracker/NRTHEOplayerTracker/**/*.swift'

  s.dependency 'NewRelicVideoAgent'
  s.ios.dependency 'THEOplayerSDK-core', '~> 10.14'
end
