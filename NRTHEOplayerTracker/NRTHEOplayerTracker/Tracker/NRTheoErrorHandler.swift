//
//  NRTheoErrorHandler.swift
//  NRTHEOplayerTracker
//
//  Wraps THEOplayer's THEOError (code/category/cause — richer than a plain error string) into a plain
//  NSError, since NRVideoTracker.sendError: only ever accepts one.
//
import Foundation
import THEOplayerSDK

final class NRTheoErrorHandler {
    private let error: THEOError?
    private let fallbackMessage: String

    init(error: THEOError?, fallbackMessage: String) {
        self.error = error
        self.fallbackMessage = fallbackMessage
    }

    /// `category` distinguishes DRM/config/network failures without a separate error-event constant —
    /// iOS folds all of these into the one ERROR event, unlike Android's CONTENTPROTECTIONERROR.
    var asNSError: NSError {
        let errorCode = error.map { String(describing: $0.code) } ?? "UNKNOWN"
        let errorMessage = error?.message ?? fallbackMessage

        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: errorMessage,
            "errorCode": errorCode,
        ]
        if let error {
            userInfo["category"] = String(describing: error.category)
            if let cause = error.cause {
                userInfo["cause"] = "\(cause.name): \(cause.message)"
            }
        }
        return NSError(domain: "com.newrelic.theoplayer", code: 0, userInfo: userInfo)
    }
}
