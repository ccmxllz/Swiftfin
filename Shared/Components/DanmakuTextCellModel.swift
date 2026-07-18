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
    var font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    var textColor = UIColor.white
    var strokeColor = UIColor.black
    var strokeWidth: CGFloat = 2.0
    var shadowOffset = CGSize(width: 1.0, height: 1.0)
    var shadowBlurRadius: CGFloat = 1.0
    var shadowColor = UIColor.black.withAlphaComponent(0.6)
    var smoothMode = true
    var textAlpha: CGFloat = 0.95
    var strokeAlpha: CGFloat = 0.7

    // MARK: - 初始化

    init(danmakuItem: DanmakuItem, settings: DanmakuRenderSettings, font: UIFont) {
        self.identifier = String(danmakuItem.id)
        self.text = danmakuItem.content
        self.textColor = UIColor(danmakuItem.displayColor)
        self.font = font
        self.smoothMode = settings.smoothMode

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

        if settings.enhancedShadow {
            self.shadowOffset = CGSize(width: 1.2, height: 1.2)
            self.shadowBlurRadius = 1.2
            self.shadowColor = UIColor.black.withAlphaComponent(1.0)
            self.strokeWidth = 2.5
        } else {
            self.shadowOffset = CGSize(width: 1.0, height: 1.0)
            self.shadowBlurRadius = 1.0
            self.shadowColor = UIColor.black.withAlphaComponent(0.6)
            self.strokeWidth = 2.0
        }

        if settings.smoothMode {
            self.textAlpha = 0.9
            self.strokeAlpha = 0.6
            self.strokeWidth *= 0.6
        } else {
            self.textAlpha = 0.95
            self.strokeAlpha = 0.7
            self.strokeWidth *= 0.8
        }

        calculateSize()
    }

    // MARK: - 计算尺寸

    func calculateSize() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
        ]

        size = NSString(string: text).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 30),
            options: [.usesFontLeading, .usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        ).size

        size.width += 4
        size.height += 2
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

// MARK: - DanmakuTextCell

/// DanmakuKit 弹幕文本视图
class DanmakuTextCell: DanmakuCell {

    required init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willDisplay() {}

    override func displaying(_ context: CGContext, _ size: CGSize, _ isCancelled: Bool) {
        guard let model = model as? DanmakuTextCellModel else { return }

        let text = NSString(string: model.text)

        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = model.smoothMode ? .default : .high

        context.setShadow(
            offset: model.shadowOffset,
            blur: model.shadowBlurRadius,
            color: model.shadowColor.cgColor
        )

        context.setLineWidth(model.strokeWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setStrokeColor(model.strokeColor.cgColor)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: model.font,
            .foregroundColor: model.textColor.withAlphaComponent(model.textAlpha),
            .strokeColor: model.strokeColor.withAlphaComponent(model.strokeAlpha),
            .strokeWidth: -model.strokeWidth,
        ]

        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
        text.draw(at: .zero, withAttributes: attributes)
    }

    override func didDisplay(_ finished: Bool) {}
}
