//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import DanmakuKit
import Defaults
import Foundation
import UIKit

/// 基于 DanmakuKit 的弹幕渲染器
final class DanmakuKitRenderer: ObservableObject {

    // MARK: - Properties

    private weak var containerView: UIView?
    private var danmakuView: DanmakuView?
    private var containerSize: CGSize = .zero

    // 弹幕设置
    private var isEnabled: Bool = true
    private var opacity: CGFloat = 0.8
    private var speedMultiplier: CGFloat = 1.0

    // 显示区域设置
    private var displayAreaRatio: CGFloat = 0.5
    private var displayAreaPosition: String = "top"
    private var trackCount: Int = 4

    /// 字体配置
    private let fontConfig = DanmakuFontConfiguration()

    // MARK: - Initialization

    init(containerView: UIView) {
        self.containerView = containerView
        self.containerSize = containerView.bounds.size
        setupDanmakuView()
        updateSettings()
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
        // 速度越快，displayTime 越小
    }

    func updateSettings() {
        trackCount = Defaults[.VideoPlayer.Overlay.danmakuTrackCount]
        displayAreaRatio = CGFloat(Defaults[.VideoPlayer.Overlay.danmakuDisplayArea])
        displayAreaPosition = Defaults[.VideoPlayer.Overlay.danmakuAreaPosition]

        updateDanmakuViewFrame()

        print("🎯 DanmakuKit 设置更新:")
        print("   轨道数: \(trackCount)")
        print("   显示比例: \(displayAreaRatio)")
        print("   显示位置: \(displayAreaPosition)")
    }

    func addDanmakuItem(_ item: DanmakuItem) {
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

        print("🎬 DanmakuKit 发射弹幕: '\(item.content)'")
    }

    func addDanmakuItems(_ items: [DanmakuItem]) {
        for item in items {
            addDanmakuItem(item)
        }
    }

    func clearAllDanmaku() {
        danmakuView?.stop()
        danmakuView?.play()
        print("🧹 DanmakuKit 清空所有弹幕")
    }

    func pauseDanmaku() {
        danmakuView?.pause()
    }

    func resumeDanmaku() {
        if isEnabled {
            danmakuView?.play()
        }
    }

    // MARK: - Private Methods

    private func setupDanmakuView() {
        guard let containerView = containerView else { return }

        // 创建 DanmakuView
        let danmakuView = DanmakuView(frame: calculateDanmakuFrame())
        danmakuView.backgroundColor = .clear
        danmakuView.alpha = opacity

        // 配置弹幕视图
        danmakuView.trackHeight = calculateTrackHeight()

        containerView.addSubview(danmakuView)
        self.danmakuView = danmakuView

        // 开始播放
        danmakuView.play()

        print("🎯 DanmakuKit 视图创建完成")
    }

    private func updateDanmakuViewFrame() {
        danmakuView?.frame = calculateDanmakuFrame()
        danmakuView?.trackHeight = calculateTrackHeight()
    }

    private func calculateDanmakuFrame() -> CGRect {
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

        return CGRect(
            x: 0,
            y: offsetY,
            width: containerSize.width,
            height: displayAreaHeight
        )
    }

    private func calculateTrackHeight() -> CGFloat {
        let displayAreaHeight = containerSize.height * displayAreaRatio
        return displayAreaHeight / CGFloat(trackCount)
    }
}

// MARK: - DanmakuRenderer Protocol Compatibility

extension DanmakuKitRenderer {

    /// 兼容原有接口的方法
    func processNewDanmakus(_ danmakus: [DanmakuItem]) {
        addDanmakuItems(danmakus)
    }
}
