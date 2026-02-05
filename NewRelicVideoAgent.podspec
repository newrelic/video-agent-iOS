#
# Be sure to run `pod lib lint NewRelicVideoCore.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NewRelicVideoAgent'
  s.version          = '4.0.4'
  s.summary          = 'New Relic Video Agent for iOS'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  New Relic Video Agent for iOS with complete tracking functionality.
  Includes base classes, AVPlayer tracking, and IMA ad tracking for comprehensive video observability.
                       DESC
  s.homepage         = 'https://github.com/newrelic/video-agent-iOS'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'Andreu Santarén Llop' => 'asantaren@newrelic.com' }
  s.source           = { :git => 'https://github.com/newrelic/video-agent-iOS.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'

  # Ensure framework name stays as NewRelicVideoCore for backward compatibility
  s.module_name      = 'NewRelicVideoCore'

  s.source_files = 'NewRelicVideoCore/NewRelicVideoCore/**/*.m', 'NewRelicVideoCore/NewRelicVideoCore/**/*.h'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'NewRelicAgent'
end
