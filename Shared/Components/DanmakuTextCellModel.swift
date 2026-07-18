//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import DanmakuKit
import Foundation
import UIKit

/// DanmakuKit 弹幕文本模型
class DanmakuTextCellModel: DanmakuCellModel {

    // MARK: - DanmakuCellModel 协议要求

    var identifier = ""
    var size: CGSize = .zero
    var track: UInt?
    var displayTime: Double = 8.0
    var type: DanmakuCellType = .floating
    var isPause = false
    var offsetTime: TimeInterval = 0

    var cellClass: DanmakuCell.Type {
        DanmakuTextCell.self
    }

    // MARK: - 弹幕属性

    var text = ""
    var font = UIFont.systemFont(ofSize: 17, weight: .medium)
    var textColor = UIColor.white
    /// Outer rim (Tencent-style thin black outline).
    var outlineColor = UIColor.black.withAlphaComponent(0.85)
    var outlineWidth: CGFloat = 2.2
    /// Soft contact shadow under the outline.
    var shadowOffset = CGSize(width: 0, height: 1.0)
    var shadowBlurRadius: CGFloat = 1.5
    var shadowColor = UIColor.black.withAlphaComponent(0.45)
    var textAlpha: CGFloat = 1.0
    var useSoftEdge = true

    // MARK: - 初始化

    init(danmakuItem: DanmakuItem, settings: DanmakuRenderSettings, font: UIFont) {
        self.identifier = String(danmakuItem.id)
        self.text = danmakuItem.content
        self.textColor = UIColor(danmakuItem.displayColor).danmakuBrightened()
        self.font = font
        self.useSoftEdge = settings.smoothMode

        switch danmakuItem.mode {
        case 1, 2, 3:
            self.type = .floating
        case 4:
            self.type = .bottom
        case 5:
            self.type = .top
        default:
            self.type = .floating
        }

        // Tencent-like: crisp bright fill + thin dark rim + soft lift shadow.
        // Keep fill near opaque so white reads "透亮", not grey.
        if settings.enhancedShadow {
            self.outlineWidth = 2.6
            self.outlineColor = UIColor.black.withAlphaComponent(0.92)
            self.shadowOffset = CGSize(width: 0, height: 1.2)
            self.shadowBlurRadius = 2.0
            self.shadowColor = UIColor.black.withAlphaComponent(0.55)
            self.textAlpha = 1.0
        } else if settings.smoothMode {
            self.outlineWidth = 2.0
            self.outlineColor = UIColor.black.withAlphaComponent(0.78)
            self.shadowOffset = CGSize(width: 0, height: 0.8)
            self.shadowBlurRadius = 1.2
            self.shadowColor = UIColor.black.withAlphaComponent(0.35)
            self.textAlpha = 0.98
        } else {
            self.outlineWidth = 2.3
            self.outlineColor = UIColor.black.withAlphaComponent(0.88)
            self.shadowOffset = CGSize(width: 0, height: 1.0)
            self.shadowBlurRadius = 1.5
            self.shadowColor = UIColor.black.withAlphaComponent(0.45)
            self.textAlpha = 1.0
        }

        calculateSize()
    }

    // MARK: - 计算尺寸

    func calculateSize() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
        ]

        size = NSString(string: text).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 40),
            options: [.usesFontLeading, .usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        ).size

        // Room for outline + soft shadow so glyphs are not clipped.
        let pad = max(4, ceil(outlineWidth + shadowBlurRadius))
        size.width += pad * 2
        size.height += pad * 2
    }

    // MARK: - 相等性比较

    func isEqual(to cellModel: DanmakuCellModel) -> Bool {
        identifier == cellModel.identifier
    }
}

// MARK: - Equatable

extension DanmakuTextCellModel: Equatable {
    static func == (lhs: DanmakuTextCellModel, rhs: DanmakuTextCellModel) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

// MARK: - Color Brightness

private extension UIColor {
    /// Lift near-greys / dim API colors toward a Tencent-like luminous look.
    func danmakuBrightened() -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Near-white / grey comments → pure bright white.
            if saturation < 0.12, brightness > 0.7 {
                return UIColor(white: 1.0, alpha: 1.0)
            }
            // Colored comments: bump brightness a bit, keep hue.
            let lifted = min(1.0, brightness * 1.08 + 0.04)
            let sat = min(1.0, saturation * 1.05)
            return UIColor(hue: hue, saturation: sat, brightness: lifted, alpha: 1.0)
        }

        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return UIColor(white: min(1.0, white * 1.05 + 0.02), alpha: 1.0)
        }

        return self
    }
}

// MARK: - DanmakuTextCell

/// DanmakuKit 弹幕文本视图 — multi-pass draw for Tencent-like 透亮 outline.
class DanmakuTextCell: DanmakuCell {

    required init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        layer.allowsEdgeAntialiasing = true
        contentScaleFactor = UIScreen.main.scale
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willDisplay() {}

    override func displaying(_ context: CGContext, _ size: CGSize, _ isCancelled: Bool) {
        guard let model = model as? DanmakuTextCellModel else { return }

        let text = NSString(string: model.text)
        let pad = max(4, ceil(model.outlineWidth + model.shadowBlurRadius))
        let origin = CGPoint(x: pad * 0.5, y: pad * 0.35)

        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = .high

        // Pass 1: soft drop shadow (lift), drawn as a darkened fill underneath.
        context.saveGState()
        context.setShadow(
            offset: model.shadowOffset,
            blur: model.shadowBlurRadius,
            color: model.shadowColor.cgColor
        )
        let shadowFill: [NSAttributedString.Key: Any] = [
            .font: model.font,
            .foregroundColor: UIColor.black.withAlphaComponent(0.01),
        ]
        text.draw(at: origin, withAttributes: shadowFill)
        context.restoreGState()

        // Pass 2: dark outline (stroke only) — thin rim that stays crisp on light/dark video.
        let outlineStroke: [NSAttributedString.Key: Any] = [
            .font: model.font,
            .foregroundColor: UIColor.clear,
            .strokeColor: model.outlineColor,
            .strokeWidth: model.outlineWidth, // positive = stroke only
        ]
        text.draw(at: origin, withAttributes: outlineStroke)

        // Pass 3: luminous fill on top — high opacity for 透亮 whites/colors.
        let fillColor = model.textColor.withAlphaComponent(model.textAlpha)
        let fillAttrs: [NSAttributedString.Key: Any] = [
            .font: model.font,
            .foregroundColor: fillColor,
            .kern: model.useSoftEdge ? 0.2 : 0.0,
        ]
        text.draw(at: origin, withAttributes: fillAttrs)
    }

    override func didDisplay(_ finished: Bool) {}
}
