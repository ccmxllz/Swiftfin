//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import Foundation
import UIKit

// MARK: - DanmakuTrackItem

struct DanmakuTrackItem {
    let width: CGFloat
    let startTime: CGFloat
    let duration: CGFloat
    let speed: CGFloat

    // 弹幕头部到达屏幕左边缘的时间
    var headExitTime: CGFloat {
        startTime + (containerWidth / speed)
    }

    // 弹幕尾部离开屏幕右边缘的时间
    var tailExitTime: CGFloat {
        startTime + ((containerWidth + width) / speed)
    }

    // 当前弹幕的位置（从右边缘开始）
    func currentPosition(at time: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let elapsed = time - startTime
        return containerWidth - (speed * elapsed)
    }

    // 弹幕尾部的位置
    func tailPosition(at time: CGFloat, containerWidth: CGFloat) -> CGFloat {
        currentPosition(at: time, containerWidth: containerWidth) + width
    }

    private let containerWidth: CGFloat

    init(width: CGFloat, startTime: CGFloat, duration: CGFloat, speed: CGFloat, containerWidth: CGFloat) {
        self.width = width
        self.startTime = startTime
        self.duration = duration
        self.speed = speed
        self.containerWidth = containerWidth
    }
}

// MARK: - DanmakuRenderer

final class DanmakuRenderer {

    // MARK: - Properties

    private weak var containerView: UIView?
    private var containerSize: CGSize = .zero
    private var isEnabled: Bool = true
    private var opacity: CGFloat = 0.8
    private var speedMultiplier: CGFloat = 1.0

    // 弹幕轨道管理
    private var trackCount: Int = 4
    private var trackHeights: [CGFloat] = []

    // 简化的轨道管理：只记录每个轨道的最后弹幕结束时间
    private var trackEndTimes: [CGFloat] = []

    // 弹幕显示区域
    private var displayAreaRatio: CGFloat = 0.5
    private var displayAreaPosition: String = "top"
    private var displayAreaHeight: CGFloat = 0
    private var displayAreaOffsetY: CGFloat = 0

    // 对象池
    private var labelPool: [UILabel] = []
    private var activeDanmakus: [DanmakuDisplayItem] = []

    // 字体配置
    private let fontConfig = DanmakuFontConfiguration()

    // MARK: - Initialization

    init(containerView: UIView) {
        self.containerView = containerView
        self.containerSize = containerView.bounds.size
        setupTracks()
        setupLabelPool()
    }

    // MARK: - Public Methods

    func setContainerSize(_ size: CGSize) {
        guard size != containerSize else { return }
        containerSize = size
        setupTracks()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            clearAllDanmaku()
        }
    }

    func setOpacity(_ opacity: CGFloat) {
        self.opacity = opacity
        updateActiveLabelsOpacity()
    }

    func setSpeedMultiplier(_ multiplier: CGFloat) {
        speedMultiplier = multiplier
    }

    func setDisplayArea(ratio: CGFloat, position: String) {
        displayAreaRatio = ratio
        displayAreaPosition = position
        setupTracks()
    }

    func updateSettings() {
        setupTracks()
    }

    func addDanmakuItems(_ items: [DanmakuItem]) {
        guard isEnabled, !items.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            for item in items {
                self?.addDanmakuItem(item)
            }
        }
    }

    func clearAllDanmaku() {
        DispatchQueue.main.async { [weak self] in
            self?.activeDanmakus.forEach { $0.label.removeFromSuperview() }
            self?.activeDanmakus.removeAll()
            self?.resetTracks()
        }
    }

    func stopAnimation() {
        activeDanmakus.forEach { $0.label.layer.removeAllAnimations() }
    }

    // MARK: - Private Methods

    private func setupTracks() {
        trackCount = Defaults[.VideoPlayer.Overlay.danmakuTrackCount]
        displayAreaRatio = CGFloat(Defaults[.VideoPlayer.Overlay.danmakuDisplayArea])
        displayAreaPosition = Defaults[.VideoPlayer.Overlay.danmakuAreaPosition]

        // 计算显示区域
        displayAreaHeight = containerSize.height * displayAreaRatio

        switch displayAreaPosition {
        case "top":
            displayAreaOffsetY = 0
        case "bottom":
            displayAreaOffsetY = containerSize.height - displayAreaHeight
        case "full":
            displayAreaHeight = containerSize.height
            displayAreaOffsetY = 0
        default:
            displayAreaOffsetY = 0
        }

        let trackHeight = displayAreaHeight / CGFloat(trackCount)
        trackHeights = Array(repeating: trackHeight, count: trackCount)
        resetTracks()

        print("🎯 弹幕显示区域设置: 位置=\(displayAreaPosition), 比例=\(displayAreaRatio), 高度=\(displayAreaHeight), 偏移=\(displayAreaOffsetY)")
    }

    private func resetTracks() {
        trackEndTimes = Array(repeating: 0, count: trackCount)
    }

    private func setupLabelPool() {
        labelPool.removeAll()
        for _ in 0 ..< 30 {
            let label = createDanmakuLabel()
            labelPool.append(label)
        }
    }

    private func createDanmakuLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .left
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        label.backgroundColor = .clear
        label.isUserInteractionEnabled = false

        // 添加阴影效果
        let shadowConfig = fontConfig.getShadowConfiguration()
        label.layer.shadowColor = shadowConfig.color
        label.layer.shadowOffset = shadowConfig.offset
        label.layer.shadowRadius = shadowConfig.radius
        label.layer.shadowOpacity = shadowConfig.opacity

        return label
    }

    private func getDanmakuLabel() -> UILabel {
        if let label = labelPool.popLast() {
            return label
        }
        return createDanmakuLabel()
    }

    private func recycleDanmakuLabel(_ label: UILabel) {
        label.removeFromSuperview()
        label.text = nil
        label.layer.removeAllAnimations()

        if labelPool.count < 30 {
            labelPool.append(label)
        }
    }

    private func addDanmakuItem(_ item: DanmakuItem) {
        guard let containerView = containerView else { return }

        let label = getDanmakuLabel()

        // 设置文本和样式
        let fontSize = fontConfig.adjustFontSize(
            baseSize: CGFloat(Defaults[.VideoPlayer.Overlay.danmakuFontSize]),
            content: item.content
        )
        let font = fontConfig.getBestAvailableFont(size: fontSize)

        label.text = item.content
        label.font = font
        label.textColor = UIColor(item.displayColor)
        label.alpha = opacity

        // 计算文本宽度
        let textWidth = fontConfig.calculateTextWidth(text: item.content, font: font)
        let textHeight = font.lineHeight

        // 基于轨道的分配算法
        let currentTime = CGFloat(CACurrentMediaTime())
        let trackIndex = selectOptimalTrack(currentTime: currentTime)
        let yPosition = displayAreaOffsetY + CGFloat(trackIndex) * trackHeights[trackIndex] + (trackHeights[trackIndex] - textHeight) / 2

        print(
            "🎯 弹幕 '\(item.content)' 分配到轨道 \(trackIndex), Y位置: \(yPosition) (显示区域: \(displayAreaOffsetY)-\(displayAreaOffsetY + displayAreaHeight))"
        )

        // 设置初始位置
        label.frame = CGRect(
            x: containerSize.width,
            y: yPosition,
            width: textWidth,
            height: textHeight
        )

        containerView.addSubview(label)

        // 统一的弹幕参数：所有弹幕相同速度
        let duration: TimeInterval = 8.0 // 固定8秒
        let speed = (containerSize.width + textWidth) / CGFloat(duration)

        // 计算这个弹幕的实际开始时间和结束时间
        let danmakuStartTime = max(currentTime, trackEndTimes[trackIndex])
        let danmakuEndTime = danmakuStartTime + CGFloat(duration)

        // 更新轨道结束时间
        trackEndTimes[trackIndex] = danmakuEndTime

        print("🎬 弹幕分配:")
        print("   轨道: \(trackIndex)")
        print("   当前时间: \(String(format: "%.2f", currentTime))")
        print("   开始时间: \(String(format: "%.2f", danmakuStartTime))")
        print("   结束时间: \(String(format: "%.2f", danmakuEndTime))")
        print("   延迟: \(String(format: "%.2f", danmakuStartTime - currentTime))秒")
        print("   速度: \(String(format: "%.2f", speed)) (统一)")

        // 创建显示项
        let displayItem = DanmakuDisplayItem(
            item: item,
            label: label,
            startTime: CACurrentMediaTime()
        )
        activeDanmakus.append(displayItem)

        // 计算延迟时间
        let delayTime = danmakuStartTime - currentTime

        // 执行动画（可能有延迟）
        UIView.animate(
            withDuration: duration,
            delay: TimeInterval(delayTime),
            options: [.curveLinear, .allowUserInteraction],
            animations: {
                label.frame.origin.x = -textWidth
            },
            completion: { [weak self] _ in
                self?.removeDanmakuDisplayItem(displayItem)
            }
        )

        // 清理过期的弹幕
        cleanupExpiredDanmakus()
    }

    /// 基于轨道结束时间的最优轨道选择
    private func selectOptimalTrack(currentTime: CGFloat) -> Int {
        // 确保轨道数组大小正确
        while trackEndTimes.count < trackCount {
            trackEndTimes.append(0)
        }

        var bestTrack = 0
        var earliestEndTime = trackEndTimes[0]

        print("🎯 轨道选择:")
        for i in 0 ..< trackCount {
            let endTime = trackEndTimes[i]
            let waitTime = max(0, endTime - currentTime)

            print("   轨道 \(i): 结束时间=\(String(format: "%.2f", endTime)), 等待=\(String(format: "%.2f", waitTime))秒")

            if endTime < earliestEndTime {
                earliestEndTime = endTime
                bestTrack = i
            }
        }

        let selectedWaitTime = max(0, earliestEndTime - currentTime)
        print("   选择轨道 \(bestTrack), 等待时间: \(String(format: "%.2f", selectedWaitTime))秒")

        return bestTrack
    }

    private func updateActiveLabelsOpacity() {
        activeDanmakus.forEach { $0.label.alpha = opacity }
    }

    private func removeDanmakuDisplayItem(_ item: DanmakuDisplayItem) {
        if let index = activeDanmakus.firstIndex(where: { $0.item.id == item.item.id }) {
            activeDanmakus.remove(at: index)
        }
        recycleDanmakuLabel(item.label)
    }

    private func cleanupExpiredDanmakus() {
        let currentTime = CACurrentMediaTime()
        let expiredItems = activeDanmakus.filter { currentTime - $0.startTime > 10.0 }

        expiredItems.forEach { removeDanmakuDisplayItem($0) }
    }
}

// MARK: - DanmakuDisplayItem

private struct DanmakuDisplayItem {
    let item: DanmakuItem
    let label: UILabel
    let startTime: TimeInterval
}
