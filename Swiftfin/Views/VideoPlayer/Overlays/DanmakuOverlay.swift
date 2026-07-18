//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import JellyfinAPI
import Logging
import SwiftUI

// MARK: - DanmakuOverlay

extension VideoPlayer {
    struct DanmakuOverlay: View {

        // MARK: - Properties

        @Injected(\.logService)
        private var logger
        @StateObject
        private var danmakuViewModel = DanmakuViewModel()
        @ObservedObject
        var videoPlayerManager: VideoPlayerManager

        // MARK: - Body

        var body: some View {
            ZStack {
                if danmakuViewModel.isEnabled {
                    DanmakuView(
                        viewModel: danmakuViewModel,
                        currentTime: Double(videoPlayerManager.currentProgressHandler.seconds)
                    )
                    .allowsHitTesting(false)
                    .opacity(danmakuViewModel.opacity)
                }
            }
            .onReceive(videoPlayerManager.$currentViewModel) { viewModel in
                logger.debug("Current view model changed: \(viewModel?.item.displayTitle ?? "nil")")
                if let viewModel = viewModel {
                    setupDanmakuForItem(viewModel)
                } else {
                    logger.debug("Clearing danmaku data")
                    Task {
                        await danmakuViewModel.send(.clearDanmakus)
                    }
                }
            }
            .onReceive(videoPlayerManager.$state) { state in
                // 当播放器状态变化时，同步弹幕状态
                switch state {
                case .stopped, .error:
                    Task {
                        await danmakuViewModel.send(.clearDanmakus)
                    }
                case .paused:
                    Task {
                        await danmakuViewModel.send(.pauseDanmaku)
                    }
                case .playing:
                    Task {
                        await danmakuViewModel.send(.resumeDanmaku)
                    }
                default:
                    break
                }
            }
            .onReceive(videoPlayerManager.currentProgressHandler.$seconds) { seconds in
                // 监听播放时间变化，更新弹幕
                Task {
                    await danmakuViewModel.send(.updateCurrentTime(Double(seconds)))
                }
            }
            .onAppear {
                logger.debug("DanmakuOverlay appeared")
                // 检查是否已经有当前视频
                if let currentViewModel = videoPlayerManager.currentViewModel {
                    logger.debug("Found existing video: \(currentViewModel.item.displayTitle)")
                    setupDanmakuForItem(currentViewModel)
                } else {
                    logger.debug("No current video found")
                }
            }
        }

        // MARK: - Private Methods

        private func setupDanmakuForItem(_ viewModel: VideoPlayerViewModel) {
            // 提取系列参数
            let seriesParams = extractSeriesParams(from: viewModel.item)

            // 确定媒体关键词：对于剧集使用系列名称，其他使用显示标题
            let mediaKeyword: String
            if viewModel.item.type == .episode, let seriesName = viewModel.item.seriesName {
                mediaKeyword = seriesName
                logger.info("Setting danmaku media (episode): \(viewModel.item.displayTitle) -> series: \(seriesName)")
            } else {
                mediaKeyword = viewModel.item.displayTitle
                logger.info("Setting danmaku media: \(mediaKeyword)")
            }

            logger.debug("Series parameters: \(String(describing: seriesParams))")

            Task {
                await danmakuViewModel.send(.setMediaWithKeyword(mediaKeyword, seriesParams))
            }
        }

        private func extractSeriesParams(from item: BaseItemDto) -> SeriesDanmakuParams? {

            // 检查是否为电影
            if item.type == .movie {
                return SeriesDanmakuParams(mediaType: 1)
            }

            // 检查是否为剧集
            if item.type == .episode {
                var season: Int?
                var episode: Int?

                // 提取季数
                if let parentIndexNumber = item.parentIndexNumber {
                    season = parentIndexNumber
                }

                // 提取集数
                if let indexNumber = item.indexNumber {
                    episode = indexNumber
                }

                return SeriesDanmakuParams(
                    season: season,
                    episode: episode,
                    mediaType: 2
                )
            }

            return nil
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DanmakuOverlay_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayer.DanmakuOverlay(videoPlayerManager: VideoPlayerManager())
            .background(Color.black)
            .previewLayout(.fixed(width: 400, height: 300))
    }
}
#endif
