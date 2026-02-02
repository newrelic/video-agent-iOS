Pod::Spec.new do |s|
  s.name             = 'NRMediaTailorTracker'
  s.version          = '4.0.0'
  s.summary          = 'New Relic AWS MediaTailor SSAI Tracker'

  s.description      = <<-DESC
AWS MediaTailor Server-Side Ad Insertion (SSAI) tracker for New Relic Video Agent.

This tracker automatically detects and tracks server-side inserted ads in MediaTailor HLS streams by:
- Parsing HLS manifests for SCTE-35 ad markers (CUE-OUT/CUE-IN tags)
- Querying the MediaTailor Tracking API for enriched metadata
- Tracking ad breaks, individual ad pods, and quartile milestones
- Supporting both VOD (Video On Demand) and LIVE streams
- Providing seamless integration with New Relic analytics platform
                       DESC

  s.homepage         = 'https://github.com/newrelic/video-agent-iOS'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'New Relic' => 'support@newrelic.com' }
  s.source           = { :git => 'https://github.com/newrelic/video-agent-iOS.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'

  s.source_files = 'NRMediaTailorTracker/NRMediaTailorTracker/**/*.{h,m}'

  s.public_header_files = [
    'NRMediaTailorTracker/NRMediaTailorTracker/NRMediaTailorTracker.h',
    'NRMediaTailorTracker/NRMediaTailorTracker/Tracker/NRTrackerMediaTailor.h',
    'NRMediaTailorTracker/NRMediaTailorTracker/Utils/NRMediaTailorConstants.h'
  ]

  s.frameworks = 'AVFoundation'
  s.dependency 'NewRelicVideoAgent', '~> 4.0'
  s.requires_arc = true
end
