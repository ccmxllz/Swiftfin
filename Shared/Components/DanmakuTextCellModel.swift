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

/// DanmakuKit 弹幕文本模型（含腾讯气泡头像 / 等级角标 / 点赞）
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
    var font = UIFont.systemFont(ofSize: 17, weight: .semibold)
    var textColor = UIColor.white
    /// 渐变填充色（左→右）；nil 则单色 textColor
    var gradientColors: [UIColor]?
    /// 细描边（腾讯风格：无投影，仅薄描边）
    var outlineColor = UIColor.black.withAlphaComponent(0.42)
    /// Core Text 负 strokeWidth = 描边+填充；绝对值约 1～1.6
    var outlineWidth: CGFloat = -1.2
    var textAlpha: CGFloat = 0.88
    var useSoftEdge = true

    // MARK: - 装饰

    var bubbleHeadURL: String?
    var bubbleLevelURL: String?
    var vipDegree: Int = 0
    var upCount: Int = 0

    var bubbleHeadImage: UIImage?
    var bubbleLevelImage: UIImage?

    /// 布局缓存（calculateSize 时更新）
    fileprivate(set) var layout = DanmakuDecorLayout()

    // MARK: - 初始化

    init(danmakuItem: DanmakuItem, settings: DanmakuRenderSettings, font: UIFont) {
        self.identifier = String(danmakuItem.id)
        self.text = danmakuItem.content
        self.bubbleHeadURL = danmakuItem.bubbleHead
        self.bubbleLevelURL = danmakuItem.bubbleLevel
        self.vipDegree = danmakuItem.vipDegree ?? 0
        self.upCount = max(0, danmakuItem.upCount)

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

        // 柔和透亮：略透、描边更淡；增强模式只加粗描边，不加阴影
        if settings.enhancedShadow {
            self.outlineWidth = -1.45
            self.outlineColor = UIColor.black.withAlphaComponent(0.50)
            self.textAlpha = 0.92
        } else if settings.smoothMode {
            self.outlineWidth = -1.15
            self.outlineColor = UIColor.black.withAlphaComponent(0.38)
            self.textAlpha = 0.86
        } else {
            self.outlineWidth = -1.25
            self.outlineColor = UIColor.black.withAlphaComponent(0.42)
            self.textAlpha = 0.88
        }

        bubbleHeadImage = DanmakuDecorImageLoader.cached(urlString: bubbleHeadURL)
        bubbleLevelImage = DanmakuDecorImageLoader.cached(urlString: bubbleLevelURL)

        calculateSize()

        // 提前预热装饰图，减少首帧占位
        ensureDecorImagesLoaded {}
    }

    func ensureDecorImagesLoaded(onUpdate: @escaping () -> Void) {
        let needHead = bubbleHeadURL != nil && bubbleHeadImage == nil
        let needLevel = bubbleLevelURL != nil && bubbleLevelImage == nil
        guard needHead || needLevel else { return }

        let group = DispatchGroup()
        if needHead {
            group.enter()
            DanmakuDecorImageLoader.load(urlString: bubbleHeadURL) { [weak self] image in
                if let image {
                    self?.bubbleHeadImage = image
                }
                group.leave()
            }
        }
        if needLevel {
            group.enter()
            DanmakuDecorImageLoader.load(urlString: bubbleLevelURL) { [weak self] image in
                if let image {
                    self?.bubbleLevelImage = image
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            onUpdate()
        }
    }

    // MARK: - 计算尺寸

    func calculateSize() {
        layout = DanmakuDecorLayout.make(
            text: text,
            font: font,
            outlinePad: abs(outlineWidth),
            hasHead: bubbleHeadURL != nil || bubbleHeadImage != nil,
            hasLevel: bubbleLevelURL != nil || bubbleLevelImage != nil || vipDegree > 0,
            upCount: upCount
        )
        size = layout.totalSize
    }

    func isEqual(to cellModel: DanmakuCellModel) -> Bool {
        identifier == cellModel.identifier
    }
}

// MARK: - Layout

struct DanmakuDecorLayout {
    var totalSize: CGSize = .zero
    var textOrigin: CGPoint = .zero
    var textSize: CGSize = .zero
    var headRect: CGRect?
    var levelRect: CGRect?
    var likeOrigin: CGPoint?
    var likeFont: UIFont = .systemFont(ofSize: 12, weight: .medium)
    var likeText: String?
    var likeIconSide: CGFloat = 14
    var pad: CGFloat = 3

    static func make(
        text: String,
        font: UIFont,
        outlinePad: CGFloat,
        hasHead: Bool,
        hasLevel: Bool,
        upCount: Int
    ) -> DanmakuDecorLayout {
        var layout = DanmakuDecorLayout()
        let pad = max(2, ceil(outlinePad + 1))
        layout.pad = pad

        let textSize = NSString(string: text).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 40),
            options: [.usesFontLeading, .usesLineFragmentOrigin],
            attributes: [.font: font],
            context: nil
        ).size
        layout.textSize = textSize

        let lineH = max(font.lineHeight, textSize.height)
        var leading: CGFloat = 0
        let gap: CGFloat = 4

        if hasHead {
            let headSide = max(18, lineH * 1.05)
            layout.headRect = CGRect(x: pad, y: pad + (lineH - headSide) * 0.5, width: headSide, height: headSide)
            leading = headSide + gap
            if hasLevel {
                let badge = headSide * 0.48
                layout.levelRect = CGRect(
                    x: pad + headSide - badge * 0.32,
                    y: pad + (lineH - headSide) * 0.5 + headSide - badge * 0.72,
                    width: badge,
                    height: badge
                )
                if let levelRect = layout.levelRect {
                    leading = max(leading, (levelRect.maxX - pad) + gap)
                }
            }
        } else if hasLevel {
            let badgeH = max(16, lineH * 0.95)
            let badgeW = badgeH * 1.6
            layout.levelRect = CGRect(x: pad, y: pad + (lineH - badgeH) * 0.5, width: badgeW, height: badgeH)
            leading = badgeW + gap
        }

        layout.textOrigin = CGPoint(x: pad + leading, y: pad + max(0, (lineH - textSize.height) * 0.5))

        var trailing: CGFloat = 0
        if upCount > 0 {
            // 点赞区略小于正文：人像+「+1」+ 数字
            let likeFont = UIFont.systemFont(ofSize: max(10, font.pointSize * 0.68), weight: .medium)
            layout.likeFont = likeFont
            let likeText = "\(upCount)"
            layout.likeText = likeText
            let numW = NSString(string: likeText).size(withAttributes: [.font: likeFont]).width
            let iconSide = max(12, likeFont.pointSize * 1.15)
            layout.likeIconSide = iconSide
            // icon(+1 叠在右侧) + 间距 + 数字
            trailing = 6 + iconSide + 10 + 3 + numW
            layout.likeOrigin = CGPoint(
                x: layout.textOrigin.x + textSize.width + 6,
                y: pad + max(0, (lineH - likeFont.lineHeight) * 0.5)
            )
        }

        let levelBottom = layout.levelRect.map { $0.maxY - pad } ?? 0
        let contentH = max(lineH, layout.headRect?.height ?? 0, levelBottom)
        layout.totalSize = CGSize(
            width: pad + leading + textSize.width + trailing + pad,
            height: contentH + pad * 2
        )
        return layout
    }
}

// MARK: - Equatable

extension DanmakuTextCellModel: Equatable {
    static func == (lhs: DanmakuTextCellModel, rhs: DanmakuTextCellModel) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

extension UIColor {

    func danmakuBrightened() -> UIColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        // 透亮：略提亮度，饱和度克制，避免发脏
        if s < 0.12 {
            return UIColor(hue: h, saturation: s, brightness: min(1, b * 1.06 + 0.03), alpha: a)
        }
        return UIColor(hue: h, saturation: min(1, s * 1.03), brightness: min(1, b * 1.06 + 0.02), alpha: a)
    }

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

    override func willDisplay() {
        guard let model = model as? DanmakuTextCellModel else { return }
        model.ensureDecorImagesLoaded { [weak self] in
            self?.redraw()
        }
    }

    override func displaying(_ context: CGContext, _ size: CGSize, _ isCancelled: Bool) {
        guard let model = model as? DanmakuTextCellModel else { return }
        let layout = model.layout
        let text = NSString(string: model.text)
        let origin = layout.textOrigin

        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = .high

        drawDecorations(model: model, layout: layout)

        let kern: CGFloat = model.useSoftEdge ? 0.12 : 0.0
        let textBounds = CGRect(origin: origin, size: layout.textSize).insetBy(dx: -1.5, dy: -1.5)

        if let gradient = model.gradientColors, gradient.count >= 2 {
            // 渐变：先细描边，再渐变填充
            text.draw(at: origin, withAttributes: [
                .font: model.font,
                .foregroundColor: UIColor.clear,
                .strokeColor: model.outlineColor,
                .strokeWidth: abs(model.outlineWidth),
                .kern: kern,
            ])
            drawGradientFill(
                in: context,
                textBounds: textBounds,
                text: text,
                origin: origin,
                font: model.font,
                colors: gradient,
                alpha: model.textAlpha,
                kern: kern
            )
        } else {
            // 单色：一次绘制（负 strokeWidth = 细描边 + 填充，无投影）
            text.draw(at: origin, withAttributes: [
                .font: model.font,
                .foregroundColor: model.textColor.withAlphaComponent(model.textAlpha),
                .strokeColor: model.outlineColor,
                .strokeWidth: model.outlineWidth,
                .kern: kern,
            ])
        }

        drawLikeCount(model: model, layout: layout)
    }

    private func drawDecorations(model: DanmakuTextCellModel, layout: DanmakuDecorLayout) {
        if let headRect = layout.headRect {
            if let image = model.bubbleHeadImage {
                drawCircularImage(image, in: headRect)
            } else {
                // 占位圆，避免加载前布局跳动太大
                UIColor.white.withAlphaComponent(0.2).setFill()
                UIBezierPath(ovalIn: headRect).fill()
            }
        }

        if let levelRect = layout.levelRect {
            if let image = model.bubbleLevelImage {
                image.draw(in: levelRect)
            } else if model.vipDegree > 0, layout.headRect == nil {
                drawVipTextBadge(degree: model.vipDegree, in: levelRect)
            }
        }
    }

    private func drawCircularImage(_ image: UIImage, in rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.saveGState()
        UIBezierPath(ovalIn: rect).addClip()
        image.draw(in: rect)
        ctx?.restoreGState()
        UIColor.white.withAlphaComponent(0.35).setStroke()
        let ring = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
        ring.lineWidth = 1
        ring.stroke()
    }

    private func drawVipTextBadge(degree: Int, in rect: CGRect) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height * 0.5)
        UIColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 0.92).setFill()
        path.fill()
        let label = "V\(degree)" as NSString
        let font = UIFont.systemFont(ofSize: max(9, rect.height * 0.45), weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
        ]
        let s = label.size(withAttributes: attrs)
        let p = CGPoint(x: rect.midX - s.width * 0.5, y: rect.midY - s.height * 0.5)
        label.draw(at: p, withAttributes: attrs)
    }

    private func drawLikeCount(model: DanmakuTextCellModel, layout: DanmakuDecorLayout) {
        guard let likeOrigin = layout.likeOrigin, let likeText = layout.likeText else { return }

        // 腾讯截图里点赞偏浅白/浅灰，弱于正文，不抢色
        let tint = UIColor.white.withAlphaComponent(0.88)
        let stroke = UIColor.black.withAlphaComponent(0.4)
        let font = layout.likeFont
        let iconSide = layout.likeIconSide
        let iconRect = CGRect(
            x: likeOrigin.x,
            y: likeOrigin.y + (font.lineHeight - iconSide) * 0.5,
            width: iconSide,
            height: iconSide
        )

        drawPersonPlusOneIcon(in: iconRect, tint: tint)

        let numAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: tint,
            .strokeColor: stroke,
            .strokeWidth: -1.1,
        ]
        (likeText as NSString).draw(
            at: CGPoint(x: iconRect.maxX + 9, y: likeOrigin.y),
            withAttributes: numAttrs
        )
    }

    /// 腾讯点赞：小人轮廓 + 右上角「+1」
    private func drawPersonPlusOneIcon(in rect: CGRect, tint: UIColor) {
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.saveGState()
        tint.setFill()

        // 头
        let headR = rect.width * 0.22
        let headCenter = CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.32)
        UIBezierPath(
            ovalIn: CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR * 2, height: headR * 2)
        ).fill()

        // 肩/身（扁椭圆）
        let bodyW = rect.width * 0.52
        let bodyH = rect.height * 0.36
        let bodyRect = CGRect(
            x: headCenter.x - bodyW * 0.5,
            y: headCenter.y + headR * 0.55,
            width: bodyW,
            height: bodyH
        )
        UIBezierPath(ovalIn: bodyRect).fill()

        ctx?.restoreGState()

        // 「+1」叠在人像右侧
        let plus = "+1" as NSString
        let plusFont = UIFont.systemFont(ofSize: max(7, rect.height * 0.42), weight: .bold)
        let plusAttrs: [NSAttributedString.Key: Any] = [
            .font: plusFont,
            .foregroundColor: tint,
            .strokeColor: UIColor.black.withAlphaComponent(0.4),
            .strokeWidth: -0.9,
        ]
        plus.draw(
            at: CGPoint(
                x: rect.minX + rect.width * 0.52,
                y: rect.minY + rect.height * 0.08
            ),
            withAttributes: plusAttrs
        )
    }

    private func drawGradientFill(
        in context: CGContext,
        textBounds: CGRect,
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

        guard textBounds.width > 1, textBounds.height > 1,
              let gradientImage = makeHorizontalGradientUIImage(size: textBounds.size, colors: colors, alpha: alpha)
        else {
            solidFallback()
            return
        }

        context.saveGState()
        // pattern 相位对齐到文字原点，避免整 cell 错位
        context.setPatternPhase(CGSize(width: textBounds.minX, height: textBounds.minY))
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
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.saveGState()
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            layer.render(in: cg)
            cg.restoreGState()
        }
    }

    override func didDisplay(_ finished: Bool) {}
}
