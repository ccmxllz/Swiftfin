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

    // MARK: - 初始化

    init(danmakuItem: DanmakuItem) {
        self.identifier = UUID().uuidString
        self.text = danmakuItem.content
        self.textColor = UIColor(danmakuItem.displayColor)

        // 根据弹幕类型设置显示类型
        switch danmakuItem.mode {
        case 1, 2, 3: // 滚动弹幕
            self.type = .floating
        case 4: // 底部弹幕
            self.type = .bottom
        case 5: // 顶部弹幕
            self.type = .top
        default:
            self.type = .floating
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

        // 添加一些边距
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

    override func willDisplay() {
        // 弹幕即将显示时的回调
    }

    override func displaying(_ context: CGContext, _ size: CGSize, _ isCancelled: Bool) {
        guard let model = model as? DanmakuTextCellModel else { return }

        let text = NSString(string: model.text)

        // 启用抗锯齿和平滑渲染，减少锐利感
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = .high

        // 设置阴影
        context.setShadow(
            offset: model.shadowOffset,
            blur: model.shadowBlurRadius,
            color: model.shadowColor.cgColor
        )

        // 设置描边属性
        context.setLineWidth(model.strokeWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setStrokeColor(model.strokeColor.cgColor)

        // 根据柔和模式设置渲染参数
        let smoothMode = Defaults[.VideoPlayer.Overlay.danmakuSmoothMode]

        let attributes: [NSAttributedString.Key: Any] = [
            .font: model.font,
            .foregroundColor: model.textColor.withAlphaComponent(smoothMode ? 0.9 : 0.95),
            .strokeColor: model.strokeColor.withAlphaComponent(smoothMode ? 0.6 : 0.7),
            .strokeWidth: -(model.strokeWidth * (smoothMode ? 0.6 : 0.8)), // 柔和模式使用更细的描边
        ]

        // 清除阴影后绘制文字
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
        text.draw(at: .zero, withAttributes: attributes)
    }

    override func didDisplay(_ finished: Bool) {
        // 弹幕显示完成时的回调
    }
}
