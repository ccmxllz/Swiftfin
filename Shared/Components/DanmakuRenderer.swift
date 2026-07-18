//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import DanmakuKit
import Factory
import Foundation
import Logging
import UIKit

/// 避免与项目中的 DanmakuView 冲突
typealias DanmakuKitView = DanmakuKit.DanmakuView

// MARK: - DanmakuRenderer (DanmakuKit Implementation)

final class DanmakuRenderer: ObservableObject {

    // MARK: - Properties

    @Injected(\.logService)
    private var logger

    private weak var containerView: UIView?
    private var danmakuView: DanmakuKitView?
    private var containerSize: CGSize = .zero

    private var isEnabled: Bool = true
    private var settings = DanmakuRenderSettings.current()

    private let fontConfig = DanmakuFontConfiguration()
    private var cachedFont: UIFont?
    private var cachedFontSize: CGFloat = 0

    // MARK: - Initialization

    init(containerView: UIView) {
        self.containerView = containerView
        self.containerSize = containerView.bounds.size

        if containerSize.width <= 0 || containerSize.height <= 0 {
            logger.warning("Invalid container view size: \(containerSize), using default size")
            self.containerSize = CGSize(width: 375, height: 667)
        }

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

    func apply(settings: DanmakuRenderSettings) {
        let areaChanged = self.settings.displayAreaRatio != settings.displayAreaRatio
            || self.settings.displayAreaPosition != settings.displayAreaPosition
            || self.settings.trackCount != settings.trackCount

        self.settings = settings
        danmakuView?.alpha = settings.opacity

        if cachedFontSize != settings.fontSize {
            cachedFontSize = settings.fontSize
            cachedFont = fontConfig.getBestAvailableFont(size: settings.fontSize)
        }

        if areaChanged {
            updateDanmakuViewFrame()
        }
    }

    func addDanmakuItems(_ items: [DanmakuItem]) {
        guard isEnabled, !items.isEmpty else { return }

        if Thread.isMainThread {
            for item in items {
                addDanmakuItem(item)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for item in items {
                    self.addDanmakuItem(item)
                }
            }
        }
    }

    func clearAllDanmaku() {
        let clear = { [weak self] in
            self?.danmakuView?.stop()
            self?.danmakuView?.play()
            self?.logger.debug("DanmakuKit cleared all danmaku")
        }

        if Thread.isMainThread {
            clear()
        } else {
            DispatchQueue.main.async(execute: clear)
        }
    }

    func stopAnimation() {
        danmakuView?.pause()
    }

    // MARK: - Private Methods

    private func setupDanmakuView() {
        guard let containerView else { return }

        let danmakuView = DanmakuKitView()
        let frame = calculateDanmakuFrame()
        let trackHeight = calculateTrackHeight()

        guard frame.width > 0, frame.height > 0, trackHeight > 0 else {
            logger.warning("Invalid DanmakuKit parameters: frame=\(frame), trackHeight=\(trackHeight)")
            return
        }

        danmakuView.frame = frame
        danmakuView.backgroundColor = .clear
        danmakuView.alpha = settings.opacity
        danmakuView.trackHeight = trackHeight

        containerView.addSubview(danmakuView)
        self.danmakuView = danmakuView
        danmakuView.play()

        cachedFont = fontConfig.getBestAvailableFont(size: settings.fontSize)
        cachedFontSize = settings.fontSize

        logger.info("DanmakuKit view created: frame=\(frame), trackHeight=\(trackHeight)")
    }

    private func updateDanmakuViewFrame() {
        let frame = calculateDanmakuFrame()
        let trackHeight = calculateTrackHeight()

        guard frame.width > 0, frame.height > 0, trackHeight > 0 else {
            logger.warning("Invalid DanmakuKit update parameters: frame=\(frame), trackHeight=\(trackHeight)")
            return
        }

        danmakuView?.frame = frame
        danmakuView?.trackHeight = trackHeight
    }

    private func calculateDanmakuFrame() -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0 else {
            logger.warning("Invalid container size: \(containerSize)")
            return CGRect(x: 0, y: 0, width: 100, height: 100)
        }

        let displayAreaHeight = containerSize.height * settings.displayAreaRatio
        let offsetY: CGFloat

        switch settings.displayAreaPosition {
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

        if frame.width <= 0 || frame.height <= 0 {
            logger.warning("Invalid calculated danmaku area: \(frame)")
            return CGRect(x: 0, y: 0, width: containerSize.width, height: containerSize.height)
        }

        return frame
    }

    private func calculateTrackHeight() -> CGFloat {
        let displayAreaHeight = containerSize.height * settings.displayAreaRatio
        let trackHeight = displayAreaHeight / CGFloat(max(1, settings.trackCount))
        let validTrackHeight = max(20.0, trackHeight)

        if validTrackHeight.isNaN || validTrackHeight.isInfinite {
            logger.warning("Invalid track height calculation: displayAreaHeight=\(displayAreaHeight), trackCount=\(settings.trackCount)")
            return 20.0
        }

        return validTrackHeight
    }

    private func addDanmakuItem(_ item: DanmakuItem) {
        guard isEnabled, let danmakuView else { return }

        let fontSize = fontConfig.adjustFontSize(baseSize: settings.fontSize, content: item.content)
        let font: UIFont
        if abs(fontSize - cachedFontSize) < 0.01, let cachedFont {
            font = cachedFont
        } else {
            font = fontConfig.getBestAvailableFont(size: fontSize)
        }

        let cellModel = DanmakuTextCellModel(danmakuItem: item, settings: settings, font: font)
        cellModel.displayTime = 8.0 / Double(max(0.1, settings.speedMultiplier))
        cellModel.calculateSize()

        danmakuView.shoot(danmaku: cellModel)
    }
}
