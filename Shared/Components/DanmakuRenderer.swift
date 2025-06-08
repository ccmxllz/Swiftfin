//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import DanmakuKit
import Defaults
import Factory
import Foundation
import Logging
import UIKit

// 避免与项目中的 DanmakuView 冲突
typealias DanmakuKitView = DanmakuKit.DanmakuView

// MARK: - DanmakuRenderer (DanmakuKit Implementation)

final class DanmakuRenderer: ObservableObject {

    // MARK: - Properties

    @Injected(\.logService)
    private var logger

    private weak var containerView: UIView?
    private var danmakuView: DanmakuKitView?
    private var containerSize: CGSize = .zero

    // 弹幕设置
    private var isEnabled: Bool = true
    private var opacity: CGFloat = 0.8
    private var speedMultiplier: CGFloat = 1.0

    // 显示区域设置
    private var displayAreaRatio: CGFloat = 0.5
    private var displayAreaPosition: String = "top"
    private var trackCount: Int = 4

    // 字体配置
    private let fontConfig = DanmakuFontConfiguration()

    // MARK: - Initialization

    init(containerView: UIView) {
        self.containerView = containerView
        self.containerSize = containerView.bounds.size

        // 确保容器尺寸有效
        if containerSize.width <= 0 || containerSize.height <= 0 {
            logger.warning("Invalid container view size: \(containerSize), using default size")
            self.containerSize = CGSize(width: 375, height: 667) // 默认iPhone尺寸
        }

        updateSettings()

        // 延迟创建弹幕视图，确保所有参数都已设置
        DispatchQueue.main.async { [weak self] in
            self?.setupDanmakuView()
        }
    }

    // MARK: - Public Methods

    func setContainerSize(_ size: CGSize) {
        guard size != containerSize else { return }
        containerSize = size
        updateDanmakuViewFrame()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            danmakuView?.play()
        } else {
            danmakuView?.pause()
        }
    }

    func setOpacity(_ opacity: CGFloat) {
        self.opacity = opacity
        danmakuView?.alpha = opacity
    }

    func setSpeedMultiplier(_ multiplier: CGFloat) {
        speedMultiplier = multiplier
        // DanmakuKit 通过调整 displayTime 来控制速度
    }

    func setDisplayArea(ratio: CGFloat, position: String) {
        displayAreaRatio = ratio
        displayAreaPosition = position
        updateDanmakuViewFrame()
    }

    func updateSettings() {
        trackCount = Defaults[.VideoPlayer.Overlay.danmakuTrackCount]
        displayAreaRatio = CGFloat(Defaults[.VideoPlayer.Overlay.danmakuDisplayArea])
        displayAreaPosition = Defaults[.VideoPlayer.Overlay.danmakuAreaPosition]

        updateDanmakuViewFrame()

        logger.debug("DanmakuKit settings updated: tracks=\(trackCount), ratio=\(displayAreaRatio), position=\(displayAreaPosition)")
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
            self?.danmakuView?.stop()
            self?.danmakuView?.play()
            self?.logger.debug("DanmakuKit cleared all danmaku")
        }
    }

    func stopAnimation() {
        danmakuView?.pause()
    }

    // MARK: - Private Methods

    private func setupDanmakuView() {
        guard let containerView = containerView else { return }

        // 创建 DanmakuKitView
        let danmakuView = DanmakuKitView()
        let frame = calculateDanmakuFrame()
        let trackHeight = calculateTrackHeight()

        // 验证参数有效性
        guard frame.width > 0, frame.height > 0, trackHeight > 0 else {
            logger.warning("Invalid DanmakuKit parameters: frame=\(frame), trackHeight=\(trackHeight)")
            return
        }

        danmakuView.frame = frame
        danmakuView.backgroundColor = .clear
        danmakuView.alpha = opacity

        // 配置弹幕视图
        danmakuView.trackHeight = trackHeight

        containerView.addSubview(danmakuView)
        self.danmakuView = danmakuView

        // 开始播放
        danmakuView.play()

        logger.info("DanmakuKit view created: frame=\(frame), trackHeight=\(trackHeight)")
    }

    private func updateDanmakuViewFrame() {
        let frame = calculateDanmakuFrame()
        let trackHeight = calculateTrackHeight()

        // 验证参数有效性
        guard frame.width > 0, frame.height > 0, trackHeight > 0 else {
            logger.warning("Invalid DanmakuKit update parameters: frame=\(frame), trackHeight=\(trackHeight)")
            return
        }

        danmakuView?.frame = frame
        danmakuView?.trackHeight = trackHeight

        logger.debug("DanmakuKit view updated: frame=\(frame), trackHeight=\(trackHeight)")
    }

    private func calculateDanmakuFrame() -> CGRect {
        // 确保容器尺寸有效
        guard containerSize.width > 0, containerSize.height > 0 else {
            logger.warning("Invalid container size: \(containerSize)")
            return CGRect(x: 0, y: 0, width: 100, height: 100) // 返回默认尺寸
        }

        let displayAreaHeight = containerSize.height * displayAreaRatio
        let offsetY: CGFloat

        switch displayAreaPosition {
        case "top":
            offsetY = 0
        case "bottom":
            offsetY = containerSize.height - displayAreaHeight
        case "full":
            return CGRect(origin: .zero, size: containerSize)
        default:
            offsetY = 0
        }

        let frame = CGRect(
            x: 0,
            y: offsetY,
            width: containerSize.width,
            height: displayAreaHeight
        )

        // 验证计算结果
        if frame.width <= 0 || frame.height <= 0 {
            logger.warning("Invalid calculated danmaku area: \(frame)")
            return CGRect(x: 0, y: 0, width: containerSize.width, height: containerSize.height)
        }

        return frame
    }

    private func calculateTrackHeight() -> CGFloat {
        let displayAreaHeight = containerSize.height * displayAreaRatio
        let trackHeight = displayAreaHeight / CGFloat(trackCount)

        // 确保轨道高度有效，最小为20
        let validTrackHeight = max(20.0, trackHeight)

        // 检查是否为有效数值
        if validTrackHeight.isNaN || validTrackHeight.isInfinite {
            logger.warning("Invalid track height calculation: displayAreaHeight=\(displayAreaHeight), trackCount=\(trackCount)")
            return 20.0 // 返回默认值
        }

        return validTrackHeight
    }

    private func addDanmakuItem(_ item: DanmakuItem) {
        guard isEnabled, let danmakuView = danmakuView else { return }

        // 创建弹幕模型
        let cellModel = DanmakuTextCellModel(danmakuItem: item)

        // 应用字体配置
        let fontSize = fontConfig.adjustFontSize(
            baseSize: CGFloat(Defaults[.VideoPlayer.Overlay.danmakuFontSize]),
            content: item.content
        )
        cellModel.font = fontConfig.getBestAvailableFont(size: fontSize)

        // 应用增强字体效果设置
        let enhancedShadow = Defaults[.VideoPlayer.Overlay.danmakuEnhancedShadow]
        if enhancedShadow {
            let shadowConfig = fontConfig.getShadowConfiguration(enhanced: true)
            cellModel.shadowOffset = shadowConfig.offset
            cellModel.shadowBlurRadius = shadowConfig.radius
            cellModel.shadowColor = UIColor(cgColor: shadowConfig.color).withAlphaComponent(CGFloat(shadowConfig.opacity))
            cellModel.strokeWidth = 2.5 // 更粗的描边
        } else {
            let shadowConfig = fontConfig.getShadowConfiguration(enhanced: false)
            cellModel.shadowOffset = shadowConfig.offset
            cellModel.shadowBlurRadius = shadowConfig.radius
            cellModel.shadowColor = UIColor(cgColor: shadowConfig.color).withAlphaComponent(CGFloat(shadowConfig.opacity))
            cellModel.strokeWidth = 2.0 // 标准描边
        }

        // 应用速度设置
        cellModel.displayTime = 8.0 / Double(speedMultiplier)

        // 重新计算尺寸
        cellModel.calculateSize()

        // 发射弹幕
        danmakuView.shoot(danmaku: cellModel)

        logger.trace("DanmakuKit shot danmaku: '\(item.content)', type: \(cellModel.type), duration: \(cellModel.displayTime)s")
    }
}
