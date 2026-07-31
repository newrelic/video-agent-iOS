#
# Vendors the KMP shared-core xcframework (video-agent-shared-core) as its own pod.
#
# Why a separate pod rather than vendoring directly inside NewRelicVideoAgent.podspec: CocoaPods
# cannot let a pod import its own vendored framework's generated header at compile time (a known
# CocoaPods self-import limitation, hit during the original PoC). Vendoring here and having
# NewRelicVideoAgent declare `s.dependency 'NRSharedCore'` makes the framework a build dependency
# of NewRelicVideoCore's sources instead of a sibling inside the same pod, so NRVideoTracker.m can
# actually `#import <NRSharedCore/NRSharedCore.h>` and call the Kotlin aggregator directly —
# this is what lets Milestone 1 wire a real shadow into the tracker instead of an example-app spike.
#
Pod::Spec.new do |s|
  s.name             = 'NRSharedCore'
  s.version          = '0.2.0'
  s.summary          = 'New Relic Video Agent — Kotlin Multiplatform shared core (QoE aggregator + model), vendored as a native framework.'

  s.description      = <<-DESC
  Vendored Kotlin/Native xcframework built from video-agent-shared-core. Currently exposes the QoE
  aggregator and model classes ported from the Android core, compiled to run natively on iOS. Used
  in shadow mode by NewRelicVideoCore: it runs alongside the existing Objective-C implementation
  with its output compared for parity, not (yet) fed into what's sent to the collector.
                       DESC
  s.homepage         = 'https://github.com/newrelic/video-agent-iOS'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'Andreu Santarén Llop' => 'asantaren@newrelic.com' }
  s.source           = { :git => 'https://github.com/newrelic/video-agent-iOS.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '12.0'

  s.vendored_frameworks = 'NRSharedCore/NRSharedCore.xcframework'
end
