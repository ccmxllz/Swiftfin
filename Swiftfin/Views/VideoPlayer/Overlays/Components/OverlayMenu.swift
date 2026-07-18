//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI
import VLCUI

extension VideoPlayer.Overlay {

    struct OverlayMenu: View {

        @Default(.VideoPlayer.menuActionButtons)
        private var menuActionButtons
        @Default(.VideoPlayer.Overlay.danmakuEnabled)
        private var isDanmakuEnabled
        @Default(.VideoPlayer.Overlay.danmakuPlatform)
        private var danmakuPlatform

        @EnvironmentObject
        private var splitContentViewProxy: SplitContentViewProxy
        @EnvironmentObject
        private var viewModel: VideoPlayerViewModel

        private var advancedButton: some View {
            Button {
                splitContentViewProxy.present()
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")

                    Text(L10n.advanced)
                }
            }
        }

        private var aspectFillButton: some View {
            ActionButtons.AspectFill { isAspectFilled in
                HStack {
                    if isAspectFilled {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                    } else {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }

                    Text(L10n.aspectFill)
                }
            }
        }

        private var audioTrackMenu: some View {
            ActionButtons.Audio { audioTrackSelected in
                HStack {
                    if audioTrackSelected {
                        Image(systemName: "speaker.wave.2.fill")
                    } else {
                        Image(systemName: "speaker.wave.2")
                    }

                    L10n.audio.text
                }
            }
        }

        @ViewBuilder
        private var autoPlayButton: some View {
            if viewModel.item.type == .episode {
                ActionButtons.AutoPlay { autoPlayEnabled in
                    HStack {
                        if autoPlayEnabled {
                            Image(systemName: "play.circle.fill")
                        } else {
                            Image(systemName: "stop.circle")
                        }

                        L10n.autoPlay.text
                    }
                }
            }
        }

        @ViewBuilder
        private var chaptersButton: some View {
            if viewModel.chapters.isNotEmpty {
                ActionButtons.Chapters {
                    HStack {
                        Image(systemName: "list.dash")

                        L10n.chapters.text
                    }
                }
            }
        }

        private var danmakuButton: some View {
            Menu {
                // 弹幕开关
                Button {
                    isDanmakuEnabled.toggle()
                } label: {
                    Label(
                        isDanmakuEnabled ? "禁用弹幕" : "启用弹幕",
                        systemImage: isDanmakuEnabled ? "bubble.left.fill" : "bubble.left"
                    )
                }

                if isDanmakuEnabled {
                    Divider()

                    // 弹幕平台选择
                    Menu("弹幕平台") {
                        Button {
                            danmakuPlatform = "tencent"
                        } label: {
                            Label("腾讯视频", systemImage: danmakuPlatform == "tencent" ? "checkmark" : "")
                        }

                        Button {
                            danmakuPlatform = "bilibili"
                        } label: {
                            Label("哔哩哔哩", systemImage: danmakuPlatform == "bilibili" ? "checkmark" : "")
                        }

                        Button {
                            danmakuPlatform = "youku"
                        } label: {
                            Label("优酷", systemImage: danmakuPlatform == "youku" ? "checkmark" : "")
                        }

                        Button {
                            danmakuPlatform = "iqiyi"
                        } label: {
                            Label("爱奇艺", systemImage: danmakuPlatform == "iqiyi" ? "checkmark" : "")
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isDanmakuEnabled ? "bubble.left.fill" : "bubble.left")

                    Text("弹幕")
                }
            }
        }

        private var playbackSpeedMenu: some View {
            ActionButtons.PlaybackSpeedMenu {
                HStack {
                    Image(systemName: "speedometer")

                    L10n.playbackSpeed.text
                }
            }
        }

        @ViewBuilder
        private var playNextItemButton: some View {
            if viewModel.item.type == .episode {
                ActionButtons.PlayNextItem {
                    HStack {
                        Image(systemName: "chevron.right.circle")

                        Text(L10n.playNextItem)
                    }
                }
            }
        }

        @ViewBuilder
        private var playPreviousItemButton: some View {
            if viewModel.item.type == .episode {
                ActionButtons.PlayPreviousItem {
                    HStack {
                        Image(systemName: "chevron.left.circle")

                        Text(L10n.playPreviousItem)
                    }
                }
            }
        }

        private var subtitleTrackMenu: some View {
            ActionButtons.Subtitles { subtitleTrackSelected in
                HStack {
                    if subtitleTrackSelected {
                        Image(systemName: "captions.bubble.fill")
                    } else {
                        Image(systemName: "captions.bubble")
                    }

                    L10n.subtitles.text
                }
            }
        }

        var body: some View {
            Menu {
                ForEach(menuActionButtons) { actionButton in
                    switch actionButton {
//                    case .advanced:
//                        advancedButton
                    case .aspectFill:
                        aspectFillButton
                    case .audio:
                        audioTrackMenu
                    case .autoPlay:
                        autoPlayButton
                    case .chapters:
                        chaptersButton
                    case .danmaku:
                        danmakuButton
                    case .playbackSpeed:
                        playbackSpeedMenu
                    case .playNextItem:
                        playNextItemButton
                    case .playPreviousItem:
                        playPreviousItemButton
                    case .subtitles:
                        subtitleTrackMenu
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .frame(width: 50, height: 50)
        }
    }
}
