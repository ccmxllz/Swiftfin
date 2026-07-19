//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import SwiftUI
import UIKit

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
        opacity: 0.92,
        fontSize: 17,
        speed: 1.0,
        maxDisplayCount: 20,
        trackCount: 4
    )
}

// MARK: - DanmakuFontConfiguration

struct DanmakuFontConfiguration {

    // MARK: - Font Names

    /// 略偏粗（Semibold）更接近腾讯「柔和透亮」体感，仍不至于发胖
    private let preferredFontNames: [String] = [
        "PingFangSC-Semibold",
        "PingFangTC-Semibold",
        "PingFangSC-Medium",
        "PingFangTC-Medium",
        "HiraginoSansGB-W6",
        "STHeitiSC-Medium",
        "HelveticaNeue-Medium",
    ]

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
        if UIFont(name: "PingFangSC-Semibold", size: size) != nil {
            return .custom("PingFangSC-Semibold", size: size)
        } else if UIFont(name: "PingFangSC-Medium", size: size) != nil {
            return .custom("PingFangSC-Medium", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    func calculateTextWidth(text: String, font: UIFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: 0.1,
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
        return max(15.0, min(24.0, adjustedSize))
    }
}
