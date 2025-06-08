//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

// MARK: - DanmakuOverlay

extension VideoPlayer {
    struct DanmakuOverlay: View {

        // MARK: - Properties

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
                print("📱 收到 currentViewModel 变化: \(viewModel?.item.displayTitle ?? "nil")")
                if let viewModel = viewModel {
                    setupDanmakuForItem(viewModel)
                } else {
                    print("🧹 清除弹幕数据")
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
                print("🎭 DanmakuOverlay 出现")
                // 检查是否已经有当前视频
                if let currentViewModel = videoPlayerManager.currentViewModel {
                    print("🎬 发现已有视频: \(currentViewModel.item.displayTitle)")
                    setupDanmakuForItem(currentViewModel)
                } else {
                    print("❌ 当前没有视频")
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
                print("🎬 设置弹幕媒体 (剧集): \(viewModel.item.displayTitle) -> 系列: \(seriesName)")
            } else {
                mediaKeyword = viewModel.item.displayTitle
                print("🎬 设置弹幕媒体: \(mediaKeyword)")
            }

            print("📺 系列参数: \(String(describing: seriesParams))")

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
