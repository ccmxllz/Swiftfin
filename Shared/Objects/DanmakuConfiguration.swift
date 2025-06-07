//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Foundation
import SwiftUI

// MARK: - DanmakuConfiguration

struct DanmakuConfiguration {

    let isEnabled: Bool
    let opacity: Double
    let fontSize: CGFloat
    let speed: Double
    let maxDisplayCount: Int
    let trackCount: Int

    static let `default` = DanmakuConfiguration(
        isEnabled: true,
        opacity: 0.8,
        fontSize: 16,
        speed: 1.0,
        maxDisplayCount: 20,
        trackCount: 4
    )
}

// MARK: - DanmakuFontConfiguration

struct DanmakuFontConfiguration {

    // MARK: - Font Names

    private let preferredFontNames: [String] = [
        "PingFangSC-Medium", // 苹果默认中文字体
        "HiraginoSansGB-W6", // 冬青黑体中粗
        "STHeitiSC-Medium", // 华文黑体
        "HiraginoSansGB-W3", // 冬青黑体
        "HelveticaNeue-Medium", // 英文字体备选
    ]

    // MARK: - Shadow Configuration

    struct ShadowConfiguration {
        let opacity: Float
        let radius: CGFloat
        let offset: CGSize
        let color: CGColor

        static let standard = ShadowConfiguration(
            opacity: 0.8,
            radius: 1.0,
            offset: CGSize(width: 1.0, height: 1.0),
            color: UIColor.black.cgColor
        )

        static let enhanced = ShadowConfiguration(
            opacity: 1.0,
            radius: 1.2,
            offset: CGSize(width: 1.2, height: 1.2),
            color: UIColor.black.cgColor
        )
    }

    // MARK: - Methods

    func getBestAvailableFont(size: CGFloat) -> UIFont {
        for fontName in preferredFontNames {
            if let font = UIFont(name: fontName, size: size) {
                return font
            }
        }
        return UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    func getSwiftUIFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if UIFont(name: "PingFangSC-Medium", size: size) != nil {
            return .custom("PingFangSC-Medium", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    func getShadowConfiguration(enhanced: Bool = false) -> ShadowConfiguration {
        enhanced ? .enhanced : .standard
    }

    func calculateTextWidth(text: String, font: UIFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: 0.0,
        ]

        let size = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 6.0
        return ceil(size.width) + padding
    }

    func adjustFontSize(baseSize: CGFloat, content: String) -> CGFloat {
        var multiplier: CGFloat = 1.0

        let contentLength = content.count
        if contentLength <= 3 {
            multiplier *= 1.02
        } else if contentLength > 20 {
            multiplier *= 0.98
        }

        let adjustedSize = baseSize * multiplier
        return max(14.0, min(22.0, adjustedSize))
    }
}
