//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension VideoPlayerSettingsView {
    struct DanmakuSection: View {

        @Default(.VideoPlayer.Overlay.danmakuEnabled)
        private var isEnabled
        @Default(.VideoPlayer.Overlay.danmakuOpacity)
        private var opacity
        @Default(.VideoPlayer.Overlay.danmakuFontSize)
        private var fontSize
        @Default(.VideoPlayer.Overlay.danmakuSpeed)
        private var speed
        @Default(.VideoPlayer.Overlay.danmakuMaxDisplayCount)
        private var maxDisplayCount
        @Default(.VideoPlayer.Overlay.danmakuShowTopComments)
        private var showTopComments
        @Default(.VideoPlayer.Overlay.danmakuShowBottomComments)
        private var showBottomComments
        @Default(.VideoPlayer.Overlay.danmakuShowScrollComments)
        private var showScrollComments
        @Default(.VideoPlayer.Overlay.danmakuTrackCount)
        private var trackCount
        @Default(.VideoPlayer.Overlay.danmakuDisplayArea)
        private var displayArea
        @Default(.VideoPlayer.Overlay.danmakuAreaPosition)
        private var areaPosition
        @Default(.VideoPlayer.Overlay.danmakuAPIBaseURL)
        private var apiBaseURL
        @Default(.VideoPlayer.Overlay.danmakuPreferredSource)
        private var preferredSource
        @Default(.VideoPlayer.Overlay.danmakuEnhancedShadow)
        private var enhancedShadow
        @Default(.VideoPlayer.Overlay.danmakuSmoothMode)
        private var smoothMode

        var body: some View {
            Section {
                Toggle("启用弹幕", isOn: $isEnabled)

                if isEnabled {
                    BasicStepper(
                        title: "不透明度",
                        value: $opacity,
                        range: 0.1 ... 1.0,
                        step: 0.1
                    )
                    .valueFormatter { value in
                        "\(Int(value * 100))%"
                    }

                    BasicStepper(
                        title: "字体大小",
                        value: $fontSize,
                        range: 12 ... 24,
                        step: 1
                    )
                    .valueFormatter { value in
                        "\(Int(value))"
                    }

                    Toggle("增强字体效果", isOn: $enhancedShadow)

                    Toggle("柔和显示模式", isOn: $smoothMode)

                    BasicStepper(
                        title: "滚动速度",
                        value: $speed,
                        range: 0.5 ... 2.0,
                        step: 0.1
                    )
                    .valueFormatter { value in
                        String(format: "%.1fx", value)
                    }

                    BasicStepper(
                        title: "最大显示数量",
                        value: $maxDisplayCount,
                        range: 5 ... 50,
                        step: 5
                    )

                    BasicStepper(
                        title: "弹幕轨道数",
                        value: $trackCount,
                        range: 2 ... 8,
                        step: 1
                    )
                    .valueFormatter { value in
                        "\(Int(value))条"
                    }

                    BasicStepper(
                        title: "显示区域大小",
                        value: $displayArea,
                        range: 0.2 ... 1.0,
                        step: 0.1
                    )
                    .valueFormatter { value in
                        "\(Int(value * 100))%"
                    }

                    Picker("显示位置", selection: $areaPosition) {
                        Text("顶部").tag("top")
                        Text("底部").tag("bottom")
                        Text("全屏").tag("full")
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Group {
                        Toggle("显示顶部弹幕", isOn: $showTopComments)
                        Toggle("显示底部弹幕", isOn: $showBottomComments)
                        Toggle("显示滚动弹幕", isOn: $showScrollComments)
                    }
                }
            } header: {
                Text("弹幕设置")
            } footer: {
                Text("弹幕功能可以在视频播放时显示观众评论。柔和显示模式可减少眼部疲劳，提供更舒适的观看体验。")
            }

            // 服务器配置部分
            Section {
                HStack {
                    Text("弹幕服务器地址")
                    Spacer()
                    TextField("请输入服务器地址", text: $apiBaseURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 200)
                }

                Picker("弹幕源", selection: $preferredSource) {
                    Text("Jellyfin").tag("jellyfin")
                    Text("DanDanPlay").tag("dandanplay")
                    Text("自定义").tag("custom")
                }
                .pickerStyle(SegmentedPickerStyle())
            } header: {
                Text("服务器配置")
            } footer: {
                Text("请配置弹幕服务器地址以启用弹幕功能。支持 Jellyfin 插件或 DanDanPlay API。弹幕平台可在播放器中直接切换。")
            }
        }
    }
}
