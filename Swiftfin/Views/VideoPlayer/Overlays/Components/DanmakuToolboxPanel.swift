//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

// MARK: - DanmakuToolboxPanel

/// In-player danmaku toolbox inspired by Tencent Video's side panel.
extension VideoPlayer.Overlay {

    struct DanmakuToolboxPanel: View {

        @Environment(\.isPresentingDanmakuToolbox)
        @Binding
        private var isPresentingDanmakuToolbox

        @Default(.VideoPlayer.Overlay.danmakuEnabled)
        private var isEnabled
        @Default(.VideoPlayer.Overlay.danmakuTrackCount)
        private var trackCount
        @Default(.VideoPlayer.Overlay.danmakuOpacity)
        private var opacity
        @Default(.VideoPlayer.Overlay.danmakuSpeed)
        private var speed
        @Default(.VideoPlayer.Overlay.danmakuFontSize)
        private var fontSize
        @Default(.VideoPlayer.Overlay.danmakuFeaturedOnly)
        private var featuredOnly
        @Default(.VideoPlayer.Overlay.danmakuColorEnabled)
        private var colorEnabled
        @Default(.VideoPlayer.Overlay.danmakuEnhancedShadow)
        private var enhancedShadow
        @Default(.VideoPlayer.Overlay.danmakuPlatform)
        private var platform
        @Default(.VideoPlayer.Overlay.danmakuShowTopComments)
        private var showTop
        @Default(.VideoPlayer.Overlay.danmakuShowBottomComments)
        private var showBottom
        @Default(.VideoPlayer.Overlay.danmakuShowScrollComments)
        private var showScroll

        var body: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    Toggle(isOn: $isEnabled) {
                        Text("显示弹幕")
                            .foregroundStyle(.white)
                    }
                    .tint(Color(red: 0.15, green: 0.75, blue: 0.72))

                    if isEnabled {
                        slidersRow

                        modeSection

                        typeSection

                        platformSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.45))
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }

        // MARK: - Sections

        private var header: some View {
            HStack(alignment: .firstTextBaseline) {
                Text("弹幕工具箱")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Button("恢复默认设置") {
                    restoreDefaults()
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresentingDanmakuToolbox = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }

        private var slidersRow: some View {
            HStack(alignment: .bottom, spacing: 14) {
                VerticalValueSlider(
                    title: "行数",
                    value: Binding(
                        get: { Double(trackCount) },
                        set: { trackCount = Int($0.rounded()) }
                    ),
                    range: 2 ... 8,
                    step: 1,
                    display: { "\(Int($0.rounded()))" }
                )

                VerticalValueSlider(
                    title: "不透明度",
                    value: $opacity,
                    range: 0.2 ... 1.0,
                    step: 0.05,
                    display: { "\(Int(($0 * 100).rounded()))%" }
                )

                VerticalValueSlider(
                    title: "速度",
                    value: $speed,
                    range: 0.5 ... 2.0,
                    step: 0.1,
                    display: { String(format: "%.1fx", $0) }
                )

                VerticalValueSlider(
                    title: "字号",
                    value: $fontSize,
                    range: 12 ... 24,
                    step: 1,
                    display: { "\(Int($0.rounded()))" }
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }

        private var modeSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("弹幕模式")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))

                HStack(spacing: 0) {
                    modeChip(title: "完整", selected: !featuredOnly) {
                        featuredOnly = false
                    }
                    modeChip(title: "精选", selected: featuredOnly) {
                        featuredOnly = true
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.12), in: Capsule())
            }
        }

        private var typeSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("弹幕类型")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))

                toolboxToggle(
                    icon: "paintpalette.fill",
                    title: "彩色弹幕",
                    isOn: $colorEnabled
                )

                toolboxToggle(
                    icon: "sparkles",
                    title: "增强描边",
                    isOn: $enhancedShadow
                )

                toolboxToggle(
                    icon: "arrow.left.and.right",
                    title: "滚动弹幕",
                    isOn: $showScroll
                )

                toolboxToggle(
                    icon: "arrow.up.to.line",
                    title: "顶部弹幕",
                    isOn: $showTop
                )

                toolboxToggle(
                    icon: "arrow.down.to.line",
                    title: "底部弹幕",
                    isOn: $showBottom
                )
            }
        }

        private var platformSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("弹幕平台")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 72), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(Self.danmakuPlatforms, id: \.id) { item in
                        modeChip(title: item.title, selected: platform == item.id) {
                            platform = item.id
                        }
                    }
                }
            }
        }

        private static let danmakuPlatforms: [(id: String, title: String)] = [
            ("tencent", "腾讯"),
            ("bilibili", "B站"),
            ("youku", "优酷"),
            ("iqiyi", "爱奇艺"),
            ("mgtv", "芒果"),
            ("renren", "人人"),
            ("sohu", "搜狐"),
            ("xigua", "西瓜"),
            ("leshi", "乐视"),
        ]

        // MARK: - Helpers

        private func modeChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(selected ? .black : .white)
                    .background {
                        if selected {
                            Capsule().fill(Color.white)
                        }
                    }
            }
            .buttonStyle(.plain)
        }

        private func toolboxToggle(icon: String, title: String, isOn: Binding<Bool>) -> some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 22)

                Text(title)
                    .foregroundStyle(.white)

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(Color(red: 0.15, green: 0.75, blue: 0.72))
            }
        }

        private func restoreDefaults() {
            isEnabled = true
            trackCount = 4
            opacity = 0.92
            speed = 1.0
            fontSize = 17
            featuredOnly = false
            colorEnabled = true
            enhancedShadow = false
            showTop = true
            showBottom = true
            showScroll = true
        }
    }
}

// MARK: - VerticalValueSlider

private struct VerticalValueSlider: View {

    let title: String
    @Binding
    var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: (Double) -> String

    private let barHeight: CGFloat = 150
    private let barWidth: CGFloat = 36

    var body: some View {
        VStack(spacing: 10) {
            Text(display(value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .frame(height: 14)

            GeometryReader { geo in
                let height = geo.size.height
                let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let fillHeight = max(8, height * progress)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.14))

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .frame(height: fillHeight)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let y = min(max(0, drag.location.y), height)
                            let ratio = 1 - (y / height)
                            let raw = range.lowerBound + Double(ratio) * (range.upperBound - range.lowerBound)
                            value = snapped(raw)
                        }
                )
            }
            .frame(width: barWidth, height: barHeight)

            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }

    private func snapped(_ raw: Double) -> Double {
        let clamped = min(max(raw, range.lowerBound), range.upperBound)
        guard step > 0 else { return clamped }
        let steps = ((clamped - range.lowerBound) / step).rounded()
        return range.lowerBound + steps * step
    }
}
