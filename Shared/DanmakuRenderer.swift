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
    private var trackOccupiedUntil: [CGFloat] = []

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
        trackCount = Defaults[.Danmaku.trackCount]
        let trackHeight = containerSize.height / CGFloat(trackCount)

        trackHeights = Array(repeating: trackHeight, count: trackCount)
        resetTracks()
    }

    private func resetTracks() {
        trackOccupiedUntil = Array(repeating: 0, count: trackCount)
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
            baseSize: CGFloat(Defaults[.Danmaku.fontSize]),
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

        // 选择轨道
        let trackIndex = selectBestTrack(for: textWidth)
        let yPosition = CGFloat(trackIndex) * trackHeights[trackIndex] + (trackHeights[trackIndex] - textHeight) / 2

        // 设置初始位置
        label.frame = CGRect(
            x: containerSize.width,
            y: yPosition,
            width: textWidth,
            height: textHeight
        )

        containerView.addSubview(label)

        // 计算动画时长
        let distance = containerSize.width + textWidth
        let baseDuration: TimeInterval = 8.0
        let duration = baseDuration / Double(speedMultiplier)

        // 更新轨道占用时间
        let occupiedTime = CGFloat(duration) * (textWidth / distance)
        trackOccupiedUntil[trackIndex] = max(trackOccupiedUntil[trackIndex], occupiedTime)

        // 创建显示项
        let displayItem = DanmakuDisplayItem(
            item: item,
            label: label,
            startTime: CACurrentMediaTime()
        )
        activeDanmakus.append(displayItem)

        // 执行动画
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.linear, .allowUserInteraction],
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

    private func selectBestTrack(for textWidth: CGFloat) -> Int {
        let currentTime = CGFloat(CACurrentMediaTime())

        // 寻找最早可用的轨道
        var bestTrack = 0
        var earliestAvailableTime = trackOccupiedUntil[0]

        for i in 1 ..< trackCount {
            if trackOccupiedUntil[i] < earliestAvailableTime {
                bestTrack = i
                earliestAvailableTime = trackOccupiedUntil[i]
            }
        }

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
