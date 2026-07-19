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
    /// 渐变填充色（腾讯 content_style.gradient_colors，左→右）；nil 则单色 textColor
    var gradientColors: [UIColor]?
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
        if settings.colorEnabled {
            self.textColor = UIColor(danmakuItem.displayColor).danmakuBrightened()
            if let hexes = danmakuItem.resolvedGradientHexes {
                let colors = hexes.compactMap { UIColor(danmakuHex: $0)?.danmakuBrightened() }
                if colors.count >= 2 {
                    self.gradientColors = colors
                }
            }
        } else {
            self.textColor = .white
            self.gradientColors = nil
        }
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

extension UIColor {

    /// Lift near-greys / dim API colors toward a Tencent-like luminous look.
    func danmakuBrightened() -> UIColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        // Near-grey: bump brightness so white/light colors read 透亮.
        if s < 0.12 {
            return UIColor(hue: h, saturation: s, brightness: min(1, b * 1.08 + 0.04), alpha: a)
        }
        return UIColor(hue: h, saturation: min(1, s * 1.05), brightness: min(1, b * 1.06), alpha: a)
    }

    /// Parse RRGGBB / #RRGGBB / RGB hex from danmu API.
    convenience init?(danmakuHex: String) {
        var hex = danmakuHex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - DanmakuTextCell

/// DanmakuKit 弹幕文本视图 — multi-pass draw for Tencent-like 透亮 outline + optional gradient fill.
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

        // Pass 3: solid or horizontal (左→右) gradient fill.
        // 注意：DanmakuAsyncLayer 已在 UIGraphicsBeginImageContext 中调用本方法，
        // 禁止再套一层 BeginImageContext，否则 destinationIn 裁切会失败，变成整块色条。
        if let gradient = model.gradientColors, gradient.count >= 2 {
            drawGradientFill(
                in: context,
                size: size,
                text: text,
                origin: origin,
                font: model.font,
                colors: gradient,
                alpha: model.textAlpha,
                kern: model.useSoftEdge ? 0.2 : 0.0
            )
        } else {
            let fillColor = model.textColor.withAlphaComponent(model.textAlpha)
            let fillAttrs: [NSAttributedString.Key: Any] = [
                .font: model.font,
                .foregroundColor: fillColor,
                .kern: model.useSoftEdge ? 0.2 : 0.0,
            ]
            text.draw(at: origin, withAttributes: fillAttrs)
        }
    }

    /// 生成左→右渐变 UIImage，再用 patternColor 走 text.draw（只填字形，不会铺满 cell）。
    private func drawGradientFill(
        in context: CGContext,
        size: CGSize,
        text: NSString,
        origin: CGPoint,
        font: UIFont,
        colors: [UIColor],
        alpha: CGFloat,
        kern: CGFloat
    ) {
        let solidFallback: () -> Void = {
            text.draw(at: origin, withAttributes: [
                .font: font,
                .foregroundColor: (colors.first ?? .white).withAlphaComponent(alpha),
                .kern: kern,
            ])
        }

        guard size.width > 1, size.height > 1,
              let gradientImage = makeHorizontalGradientUIImage(size: size, colors: colors, alpha: alpha)
        else {
            solidFallback()
            return
        }

        context.saveGState()
        context.setPatternPhase(.zero)
        text.draw(at: origin, withAttributes: [
            .font: font,
            .foregroundColor: UIColor(patternImage: gradientImage),
            .kern: kern,
        ])
        context.restoreGState()
    }

    private func makeHorizontalGradientUIImage(size: CGSize, colors: [UIColor], alpha: CGFloat) -> UIImage? {
        let scale = contentScaleFactor > 0 ? contentScaleFactor : UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let layer = CAGradientLayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.colors = colors.map { $0.withAlphaComponent(alpha).cgColor }
        layer.locations = (0 ..< colors.count).map {
            NSNumber(value: colors.count == 1 ? 0 : Double($0) / Double(colors.count - 1))
        }
        // 腾讯弹幕渐变：左 → 右
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            // layer.render 进位图时默认 CG 取向，翻转到 UIKit（与 text.draw 一致）
            cg.saveGState()
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            layer.render(in: cg)
            cg.restoreGState()
        }
    }

    override func didDisplay(_ finished: Bool) {}
}
