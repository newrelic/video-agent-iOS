#
# Be sure to run `pod lib lint NRIMATracker.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NRIMATracker'
  s.version          = '2.0.2'
  s.summary          = 'New Relic Video Agent, Google IMA Ads Tracker.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  New Relic Video Agent, Google IMA Ads Tracker. Contains a trackers for the Google IMA Ads library.
                       DESC
  s.homepage         = 'https://github.com/newrelic/video-agent-iOS'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'Andreu Santarén Llop' => 'asantaren@newrelic.com' }
  s.source           = { :git => 'https://github.com/newrelic/video-agent-iOS', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'

  s.source_files = 'NRIMATracker/NRIMATracker/**/*.m', 'NRIMATracker/NRIMATracker/**/*.h'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'NewRelicVideoCore'
  s.ios.dependency 'GoogleAds-IMA-iOS-SDK'
  s.tvos.dependency 'GoogleAds-IMA-tvOS-SDK'
end
