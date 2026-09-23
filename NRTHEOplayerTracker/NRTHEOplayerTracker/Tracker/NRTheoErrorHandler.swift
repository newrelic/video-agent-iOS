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
    /// iOS folds all of these into the one ERROR event, unlike Android's CONTENTPROTECTIONERROR. Exposed
    /// separately (not via asNSError's userInfo) because NRVideoTracker.m's sendError: only ever reads
    /// error.domain/.code/.localizedDescription off the NSError itself — never userInfo — so anything
    /// stuffed into userInfo silently never reaches NRDB. The caller (handleError) surfaces this via
    /// setAttribute(forAction: CONTENT_ERROR) instead, the same scoped-custom-attribute mechanism
    /// CONTENT_RENDITION_CHANGE's "shift" attribute uses.
    var category: String? {
        error.map { String(describing: $0.category) }
    }

    var cause: String? {
        error?.cause.map { "\($0.name): \($0.message)" }
    }

    /// code must be the NSError's real `.code` — THEOErrorCode is a real, meaningful Int32 enum (e.g.
    /// LICENSE_ERROR, NETWORK_ERROR), not a placeholder — because sendError: reads `.code` directly.
    /// A prior version hardcoded this to 0 and stashed the real value in userInfo, where it was silently
    /// discarded; every real error this shipped ever produced showed errorCode=0 in NRDB regardless of
    /// what actually went wrong.
    var asNSError: NSError {
        let code = error.map { Int($0.code.rawValue) } ?? 0
        // `error?.message ?? fallbackMessage` only substitutes fallbackMessage when error itself is
        // nil — but THEOError.message is a non-optional String, so a real error with an empty message
        // (a genuine possibility, not guaranteed non-empty by the SDK) would silently produce a blank
        // NSError.localizedDescription instead of falling back to the more useful fallbackMessage.
        let rawMessage = error?.message
        let message = (rawMessage?.isEmpty ?? true) ? fallbackMessage : rawMessage!
        return NSError(domain: "com.newrelic.theoplayer", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
