//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

// MARK: - DanmakuActionButton

struct DanmakuActionButton: View {

    // MARK: - Properties

    @Default(.VideoPlayer.Overlay.danmakuEnabled)
    private var isDanmakuEnabled
    @Default(.VideoPlayer.Overlay.danmakuPlatform)
    private var danmakuPlatform

    // MARK: - Body

    var body: some View {
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
            Image(systemName: isDanmakuEnabled ? "bubble.left.fill" : "bubble.left")
                .font(.title2)
                .foregroundColor(isDanmakuEnabled ? .jellyfinPurple : .white)
        }
        .buttonStyle(PlainButtonStyle())
        .help(isDanmakuEnabled ? "弹幕设置" : "启用弹幕")
    }
}

// MARK: - Preview

#if DEBUG
struct DanmakuActionButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            DanmakuActionButton()
            DanmakuActionButton()
                .environment(\.colorScheme, .dark)
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .previewLayout(.sizeThatFits)
    }
}
#endif
