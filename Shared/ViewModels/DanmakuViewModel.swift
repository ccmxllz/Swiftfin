//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import Factory
import Foundation
import JellyfinAPI
import Logging

// MARK: - DanmakuViewModel

final class DanmakuViewModel: ViewModel, Stateful {

    // MARK: - Action

    enum Action: Equatable {
        case setEnabled(Bool)
        case setMedia(BaseItemDto, SeriesDanmakuParams?)
        case setMediaWithKeyword(String, SeriesDanmakuParams?)
        case updateCurrentTime(Double)
        case loadSegment(Int, Int)
        case clearDanmakus
        case reloadDanmakus
        case pauseDanmaku
        case resumeDanmaku
        case error(JellyfinAPIError)

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case let (.setEnabled(lhsValue), .setEnabled(rhsValue)):
                return lhsValue == rhsValue
            case let (.setMedia(lhsItem, _), .setMedia(rhsItem, _)):
                return lhsItem.id == rhsItem.id
            case let (.setMediaWithKeyword(lhsKeyword, _), .setMediaWithKeyword(rhsKeyword, _)):
                return lhsKeyword == rhsKeyword
            case let (.updateCurrentTime(lhsTime), .updateCurrentTime(rhsTime)):
                return abs(lhsTime - rhsTime) < 0.1
            case let (.loadSegment(lhsStart, lhsEnd), .loadSegment(rhsStart, rhsEnd)):
                return lhsStart == rhsStart && lhsEnd == rhsEnd
            case (.clearDanmakus, .clearDanmakus),
                 (.reloadDanmakus, .reloadDanmakus),
                 (.pauseDanmaku, .pauseDanmaku),
                 (.resumeDanmaku, .resumeDanmaku):
                return true
            case let (.error(lhsError), .error(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }

    // MARK: - BackgroundState

    enum BackgroundState: Hashable {
        case loading
    }

    // MARK: - State

    enum State: Hashable {
        case initial
        case ready
        case loading
        case error(JellyfinAPIError)
    }

    // MARK: - SegmentLoadState

    private enum SegmentLoadState: Equatable {
        case loading
        case loaded
        case empty
        case failed(Date)
    }

    // MARK: - Published Properties

    @Published
    var danmakus: [DanmakuItem] = []

    @Published
    var currentDanmakus: [DanmakuItem] = []

    @Published
    var backgroundStates: Set<BackgroundState> = []

    @Published
    var state: State = .initial

    @Published
    var isPaused: Bool = false

    /// Incremented on large seeks / reload so the renderer can reset dedupe state.
    @Published
    private(set) var renderEpoch: UInt = 0

    // MARK: - Private Properties

    @Injected(\.danmakuService)
    private var danmakuService: DanmakuService

    private var mediaKeyword: String = ""
    private var seriesParams: SeriesDanmakuParams?
    private var segmentStates: [Int: SegmentLoadState] = [:]

    private var lastPlaybackTime: Double = -1
    private var lastPublishedIds: [Int] = []
    private var inFlightSegmentLoads: Int = 0

    /// Watermark: items with `progress <= emittedUntilMs` have already been handed to the renderer.
    private var emittedUntilMs: Int = -1

    private let retainBehindSeconds = 300
    private let retainAheadSeconds = 600
    private let failedRetryInterval: TimeInterval = 30
    private let seekResetThreshold: Double = 1.5

    /// Catch-up after small stalls / seek (ms).
    private let lookBehindMs = 200
    /// Prefire buffer so the next wave is already in flight before the previous exits.
    /// Needs to cover progress tick jitter; DanmakuKit still starts scroll at shoot time.
    private let lookAheadMs = 2000

    // MARK: - Configuration Properties

    var isEnabled: Bool {
        Defaults[.VideoPlayer.Overlay.danmakuEnabled]
    }

    var opacity: Double {
        Defaults[.VideoPlayer.Overlay.danmakuOpacity]
    }

    var speed: Double {
        Defaults[.VideoPlayer.Overlay.danmakuSpeed]
    }

    var maxDisplayCount: Int {
        Defaults[.VideoPlayer.Overlay.danmakuMaxDisplayCount]
    }

    var apiBaseURL: String {
        Defaults[.VideoPlayer.Overlay.danmakuAPIBaseURL]
    }

    var preferredSource: String {
        Defaults[.VideoPlayer.Overlay.danmakuPreferredSource]
    }

    var danmakuPlatform: String {
        Defaults[.VideoPlayer.Overlay.danmakuPlatform]
    }

    /// Align client windows with native source segment sizes where known.
    private var segmentDuration: Int {
        switch danmakuPlatform {
        case "bilibili":
            return 360
        default:
            return 30
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()

        Defaults.publisher(.VideoPlayer.Overlay.danmakuEnabled)
            .sink { [weak self] change in
                Task { @MainActor in
                    self?.send(.setEnabled(change.newValue))
                }
            }
            .store(in: &cancellables)

        Defaults.publisher(.VideoPlayer.Overlay.danmakuPlatform)
            .sink { [weak self] change in
                self?.logger.info("Danmaku platform changed: \(change.oldValue) -> \(change.newValue)")
                Task { @MainActor in
                    self?.send(.reloadDanmakus)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Stateful Implementation

    @MainActor
    func respond(to action: Action) -> State {
        switch action {
        case let .setEnabled(enabled):
            logger.debug("Danmaku enabled state changed: \(enabled)")
            if !enabled {
                publishCurrentDanmakus([])
            }
            return state

        case let .setMedia(item, seriesParams):
            self.seriesParams = seriesParams
            mediaKeyword = extractMediaKeyword(from: item)
            return prepareForNewMedia()

        case let .setMediaWithKeyword(keyword, seriesParams):
            self.seriesParams = seriesParams
            mediaKeyword = keyword
            return prepareForNewMedia()

        case let .updateCurrentTime(currentTime):
            updateDanmakus(at: currentTime)
            return state

        case let .loadSegment(startTime, endTime):
            loadDanmakuSegment(startTime: startTime, endTime: endTime)
            return state

        case .clearDanmakus:
            resetAllData()
            return .initial

        case .reloadDanmakus:
            danmakus.removeAll()
            publishCurrentDanmakus([])
            segmentStates.removeAll()
            lastPublishedIds.removeAll()
            lastPlaybackTime = -1
            emittedUntilMs = -1
            bumpRenderEpoch()
            logger.info("Danmaku data cleared, will reload")
            return state

        case .pauseDanmaku:
            isPaused = true
            logger.debug("Danmaku paused")
            return state

        case .resumeDanmaku:
            isPaused = false
            logger.debug("Danmaku resumed")
            return state

        case let .error(error):
            return .error(error)
        }
    }

    // MARK: - Private Methods

    @MainActor
    private func prepareForNewMedia() -> State {
        logger.info("Danmaku media keyword: '\(mediaKeyword)'")
        logger.debug("Series parameters: \(String(describing: seriesParams))")

        if mediaKeyword.isEmpty {
            logger.warning("Media keyword is empty")
            return .error(.init("无效的媒体标题"))
        }

        resetAllData()
        logger.info("Danmaku system ready")
        return .ready
    }

    @MainActor
    private func resetAllData() {
        danmakus.removeAll()
        publishCurrentDanmakus([])
        segmentStates.removeAll()
        lastPublishedIds.removeAll()
        lastPlaybackTime = -1
        emittedUntilMs = -1
        inFlightSegmentLoads = 0
        backgroundStates.remove(.loading)
        bumpRenderEpoch()
    }

    /// Soft per-tick emit cap (time-ordered). Remainder stays queued via `emittedUntilMs`.
    private var maxEmitPerTick: Int {
        max(40, maxDisplayCount * 2)
    }

    private func bumpRenderEpoch() {
        renderEpoch &+= 1
    }

    private func extractMediaKeyword(from item: BaseItemDto) -> String {
        let displayTitle = item.displayTitle
        if !displayTitle.isEmpty {
            return displayTitle
        }

        if let name = item.name, !name.isEmpty {
            return name
        }

        return ""
    }

    @MainActor
    private func updateDanmakus(at currentTime: Double) {
        guard isEnabled else {
            publishCurrentDanmakus([])
            return
        }

        // Pause: keep existing on-screen danmaku; renderer freezes animation.
        guard !isPaused else { return }

        let currentTimeMs = Int(currentTime * 1000)

        if lastPlaybackTime >= 0, abs(currentTime - lastPlaybackTime) > seekResetThreshold {
            bumpRenderEpoch()
            publishCurrentDanmakus([])
            // Rewind watermark so the live window can be re-emitted after seek.
            emittedUntilMs = max(-1, currentTimeMs - lookBehindMs - 1)
        }
        lastPlaybackTime = currentTime

        let currentTimeSec = Int(currentTime)
        checkAndLoadDanmakuSegment(for: currentTimeSec)
        pruneIfNeeded(around: currentTimeSec)

        guard !danmakus.isEmpty else { return }

        // Continuous cursor emit: hand over every due item in time order.
        // Previous sliding-window + score truncate permanently dropped overflow,
        // which showed up as empty gaps between batches on screen.
        let emitUntilMs = currentTimeMs + lookAheadMs
        let startMs = emittedUntilMs + 1
        guard startMs <= emitUntilMs else { return }

        let dueItems = items(inProgressRange: startMs ... emitUntilMs)
        guard !dueItems.isEmpty else { return }

        let batch: [DanmakuItem]
        if dueItems.count <= maxEmitPerTick {
            batch = dueItems
        } else {
            batch = Array(dueItems.prefix(maxEmitPerTick))
        }

        if let last = batch.last {
            emittedUntilMs = last.progress
        }

        publishCurrentDanmakus(batch)
    }

    @MainActor
    private func publishCurrentDanmakus(_ items: [DanmakuItem]) {
        let ids = items.map(\.id)
        guard ids != lastPublishedIds else { return }
        lastPublishedIds = ids
        currentDanmakus = items
    }

    /// Binary search over `danmakus` sorted by `progress`.
    private func items(inProgressRange range: ClosedRange<Int>) -> [DanmakuItem] {
        let lower = lowerBound(progress: range.lowerBound)
        let upper = upperBound(progress: range.upperBound)
        guard lower < upper else { return [] }
        return Array(danmakus[lower ..< upper])
    }

    private func lowerBound(progress: Int) -> Int {
        var low = 0
        var high = danmakus.count
        while low < high {
            let mid = (low + high) / 2
            if danmakus[mid].progress < progress {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    private func upperBound(progress: Int) -> Int {
        var low = 0
        var high = danmakus.count
        while low < high {
            let mid = (low + high) / 2
            if danmakus[mid].progress <= progress {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    @MainActor
    private func checkAndLoadDanmakuSegment(for currentTimeSec: Int) {
        let currentSegment = currentTimeSec / segmentDuration
        // Current + one ahead keeps RTT low; -1 covers seek-back into prior window.
        let segmentsToLoad = [
            max(0, currentSegment - 1),
            currentSegment,
            currentSegment + 1,
        ]

        for segment in Set(segmentsToLoad) where segment >= 0 {
            if shouldLoad(segment: segment) {
                segmentStates[segment] = .loading
                let startTime = segment * segmentDuration
                let endTime = startTime + segmentDuration
                Task { @MainActor in
                    send(.loadSegment(startTime, endTime))
                }
            }
        }
    }

    private func shouldLoad(segment: Int) -> Bool {
        switch segmentStates[segment] {
        case .none:
            return true
        case .loading, .loaded, .empty:
            return false
        case let .failed(date):
            return Date().timeIntervalSince(date) >= failedRetryInterval
        }
    }

    private func segmentIndex(forStart startTime: Int) -> Int {
        startTime / segmentDuration
    }

    @MainActor
    private func loadDanmakuSegment(startTime: Int, endTime: Int) {
        guard !mediaKeyword.isEmpty else {
            logger.warning("Media keyword is empty, skipping danmaku loading")
            return
        }

        let segment = segmentIndex(forStart: startTime)
        logger.debug("Loading danmaku segment: \(startTime)-\(endTime)s (index \(segment))")

        inFlightSegmentLoads += 1
        backgroundStates.insert(.loading)

        Task {
            do {
                let items = try await danmakuService.fetchDanmakuSegment(
                    platform: danmakuPlatform,
                    keyword: mediaKeyword,
                    start: startTime,
                    end: endTime,
                    seriesParams: seriesParams
                )

                await MainActor.run {
                    self.finishSegmentLoad(segment: segment, items: items, startTime: startTime, endTime: endTime)
                }
            } catch {
                await MainActor.run {
                    self.failSegmentLoad(segment: segment, error: error)
                }
            }
        }
    }

    @MainActor
    private func finishSegmentLoad(segment: Int, items: [DanmakuItem], startTime: Int, endTime: Int) {
        defer { completeBackgroundLoading() }

        if items.isEmpty {
            segmentStates[segment] = .empty
            logger.info("Empty danmaku segment \(startTime)-\(endTime)")
            return
        }

        segmentStates[segment] = .loaded
        mergeItems(items)
        logger.info("Successfully loaded danmaku segment \(startTime)-\(endTime): \(items.count) items")

        // Don't wait for the next progress tick — fill any due gap immediately.
        if lastPlaybackTime >= 0 {
            updateDanmakus(at: lastPlaybackTime)
        }
    }

    @MainActor
    private func failSegmentLoad(segment: Int, error: Error) {
        defer { completeBackgroundLoading() }
        segmentStates[segment] = .failed(Date())
        logger.error("Failed to load danmaku segment \(segment): \(error.localizedDescription)")
    }

    @MainActor
    private func completeBackgroundLoading() {
        inFlightSegmentLoads = max(0, inFlightSegmentLoads - 1)
        if inFlightSegmentLoads == 0 {
            backgroundStates.remove(.loading)
        }
    }

    @MainActor
    private func mergeItems(_ newItems: [DanmakuItem]) {
        guard !newItems.isEmpty else { return }

        var existingIDs = Set(danmakus.map(\.id))
        let uniqueNew = newItems
            .filter { existingIDs.insert($0.id).inserted }
            .sorted { $0.progress < $1.progress }

        guard !uniqueNew.isEmpty else { return }

        // Late-arriving items behind the watermark must be re-eligible to emit.
        if let earliestNew = uniqueNew.first?.progress, earliestNew <= emittedUntilMs {
            emittedUntilMs = earliestNew - 1
        }

        if danmakus.isEmpty {
            danmakus = uniqueNew
            return
        }

        var merged: [DanmakuItem] = []
        merged.reserveCapacity(danmakus.count + uniqueNew.count)

        var i = 0
        var j = 0
        while i < danmakus.count, j < uniqueNew.count {
            if danmakus[i].progress <= uniqueNew[j].progress {
                merged.append(danmakus[i])
                i += 1
            } else {
                merged.append(uniqueNew[j])
                j += 1
            }
        }
        if i < danmakus.count {
            merged.append(contentsOf: danmakus[i...])
        }
        if j < uniqueNew.count {
            merged.append(contentsOf: uniqueNew[j...])
        }
        danmakus = merged
    }

    @MainActor
    private func pruneIfNeeded(around currentTimeSec: Int) {
        let minMs = max(0, (currentTimeSec - retainBehindSeconds) * 1000)
        let maxMs = (currentTimeSec + retainAheadSeconds) * 1000

        let lower = lowerBound(progress: minMs)
        let upper = upperBound(progress: maxMs)

        if lower > 0 || upper < danmakus.count {
            danmakus = Array(danmakus[lower ..< upper])
        }

        let minSeg = max(0, (currentTimeSec - retainBehindSeconds) / segmentDuration - 1)
        let maxSeg = (currentTimeSec + retainAheadSeconds) / segmentDuration + 1
        segmentStates = segmentStates.filter { $0.key >= minSeg && $0.key <= maxSeg }
    }
}
