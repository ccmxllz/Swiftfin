//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
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
            case let (.setMedia(lhsItem, lhsParams), .setMedia(rhsItem, rhsParams)):
                return lhsItem.id == rhsItem.id
            case let (.setMediaWithKeyword(lhsKeyword, lhsParams), .setMediaWithKeyword(rhsKeyword, rhsParams)):
                return lhsKeyword == rhsKeyword
            case let (.updateCurrentTime(lhsTime), .updateCurrentTime(rhsTime)):
                return abs(lhsTime - rhsTime) < 0.1
            case let (.loadSegment(lhsStart, lhsEnd), .loadSegment(rhsStart, rhsEnd)):
                return lhsStart == rhsStart && lhsEnd == rhsEnd
            case (.clearDanmakus, .clearDanmakus):
                return true
            case (.reloadDanmakus, .reloadDanmakus):
                return true
            case (.pauseDanmaku, .pauseDanmaku):
                return true
            case (.resumeDanmaku, .resumeDanmaku):
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

    // MARK: - Private Properties

    private var danmakuService: DanmakuService = DanmakuService()

    private var mediaKeyword: String = ""
    private var seriesParams: SeriesDanmakuParams?
    private var loadedTimeSegments: Set<Int> = []
    private let segmentDuration = 30

    // 弹幕缓存
    private var danmakuCache: [String: [DanmakuItem]] = [:]
    private var lastCacheTime: Double = -1
    private let cacheValidDuration: Double = 2.0

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

    // MARK: - Initialization

    override init() {
        super.init()

        // 监听设置变化
        Defaults.publisher(.VideoPlayer.Overlay.danmakuEnabled)
            .sink { [weak self] change in
                Task {
                    await self?.send(.setEnabled(change.newValue))
                }
            }
            .store(in: &cancellables)

        // 监听弹幕平台变化
        Defaults.publisher(.VideoPlayer.Overlay.danmakuPlatform)
            .sink { [weak self] change in
                self?.logger.info("Danmaku platform changed: \(change.oldValue) -> \(change.newValue)")
                Task {
                    await self?.send(.reloadDanmakus)
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
                currentDanmakus = []
            }
            return state

        case let .setMedia(item, seriesParams):
            self.seriesParams = seriesParams

            // 提取媒体关键词
            mediaKeyword = extractMediaKeyword(from: item)

            logger.info("Danmaku media keyword: '\(mediaKeyword)'")
            logger.debug("Series parameters: \(String(describing: seriesParams))")

            if mediaKeyword.isEmpty {
                logger.warning("Media keyword is empty")
                return .error(.init("无效的媒体标题"))
            }

            // 清除旧数据
            danmakus.removeAll()
            currentDanmakus.removeAll()
            loadedTimeSegments.removeAll()

            logger.info("Danmaku system ready")
            return .ready

        case let .setMediaWithKeyword(keyword, seriesParams):
            self.seriesParams = seriesParams
            self.mediaKeyword = keyword

            logger.info("Danmaku media keyword: '\(mediaKeyword)'")
            logger.debug("Series parameters: \(String(describing: seriesParams))")

            if mediaKeyword.isEmpty {
                logger.warning("Media keyword is empty")
                return .error(.init("无效的媒体标题"))
            }

            // 清除旧数据
            danmakus.removeAll()
            currentDanmakus.removeAll()
            loadedTimeSegments.removeAll()

            logger.info("Danmaku system ready")
            return .ready

        case let .updateCurrentTime(currentTime):
            logger.trace("Update playback time: \(currentTime)s, danmaku enabled: \(isEnabled)")
            updateDanmakus(at: currentTime)
            return state

        case let .loadSegment(startTime, endTime):
            loadDanmakuSegment(startTime: startTime, endTime: endTime)
            return state

        case .clearDanmakus:
            danmakus.removeAll()
            currentDanmakus.removeAll()
            loadedTimeSegments.removeAll()
            return .initial

        case .reloadDanmakus:
            // 清除已加载的弹幕数据，强制重新加载
            danmakus.removeAll()
            currentDanmakus.removeAll()
            loadedTimeSegments.removeAll()
            danmakuCache.removeAll()
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

    private func extractMediaKeyword(from item: BaseItemDto) -> String {
        // 优先使用 displayTitle
        let displayTitle = item.displayTitle
        if !displayTitle.isEmpty {
            return displayTitle
        }

        // 备选使用 name
        if let name = item.name, !name.isEmpty {
            return name
        }

        return ""
    }

    private func updateDanmakus(at currentTime: Double) {
        guard isEnabled && !isPaused else {
            if !currentDanmakus.isEmpty && isPaused {
                // 暂停时清空当前弹幕，但不清空已加载的弹幕数据
                currentDanmakus = []
            } else if !isEnabled && !currentDanmakus.isEmpty {
                currentDanmakus = []
            }
            return
        }

        // 检查并加载新的弹幕段（即使当前没有弹幕数据）
        checkAndLoadDanmakuSegment(for: Int(currentTime))

        // 如果还没有弹幕数据，直接返回
        guard !danmakus.isEmpty else {
            return
        }

        // 时间范围筛选
        let startTimeMs = max(0, Int(currentTime * 1000) - 80)
        let endTimeMs = Int(currentTime * 1000) + 350

        // 缓存检查
        let cacheKey = "\(startTimeMs)-\(endTimeMs)"
        let timeDiff = abs(currentTime - lastCacheTime)

        if timeDiff < cacheValidDuration, let cachedDanmakus = danmakuCache[cacheKey] {
            currentDanmakus = cachedDanmakus
            return
        }

        // 筛选当前时间段的弹幕
        let filteredDanmakus = danmakus.filter { danmaku in
            danmaku.progress >= startTimeMs && danmaku.progress <= endTimeMs
        }

        // 按评分排序并限制数量
        let sortedDanmakus = filteredDanmakus
            .sorted { $0.score > $1.score }
            .prefix(maxDisplayCount)
            .sorted { $0.progress < $1.progress }

        currentDanmakus = Array(sortedDanmakus)

        // 更新缓存
        danmakuCache[cacheKey] = currentDanmakus
        lastCacheTime = currentTime

        // 清理过期缓存
        if danmakuCache.count > 10 {
            danmakuCache.removeAll()
        }
    }

    private func checkAndLoadDanmakuSegment(for currentTimeSec: Int) {
        let currentSegment = currentTimeSec / segmentDuration

        let segmentsToLoad = [
            max(0, currentSegment - 1),
            currentSegment,
            currentSegment + 1,
            currentSegment + 2,
        ]

        for segment in segmentsToLoad {
            if segment >= 0 && !loadedTimeSegments.contains(segment) {
                loadedTimeSegments.insert(segment)

                let startTime = segment * segmentDuration
                let endTime = startTime + segmentDuration

                Task {
                    await send(.loadSegment(startTime, endTime))
                }
            }
        }
    }

    private func loadDanmakuSegment(startTime: Int, endTime: Int) {
        guard !mediaKeyword.isEmpty else {
            logger.warning("Media keyword is empty, skipping danmaku loading")
            return
        }

        logger.debug("Loading danmaku segment: \(startTime)-\(endTime)s")
        logger.trace("Keyword: '\(mediaKeyword)', platform: \(danmakuPlatform)")

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
                    self.danmakus.append(contentsOf: items)
                    self.backgroundStates.remove(.loading)
                    self.logger.info("Successfully loaded danmaku segment \(startTime)-\(endTime): \(items.count) items")
                }
            } catch {
                await MainActor.run {
                    self.backgroundStates.remove(.loading)
                    self.logger.error("Failed to load danmaku: \(error.localizedDescription)")
                }
            }
        }
    }
}
