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

// MARK: - DanmakuPosition

enum DanmakuPosition: String, CaseIterable, Codable, Displayable {
    case top
    case bottom
    case scroll

    var displayTitle: String {
        switch self {
        case .top:
            return "顶部"
        case .bottom:
            return "底部"
        case .scroll:
            return "滚动"
        }
    }
}

// MARK: - DanmakuItem (保持与参考实现兼容)

struct DanmakuItem: Identifiable, Codable, Hashable {

    let id: Int
    let content: String
    let progress: Int // 弹幕出现的时间点（毫秒）
    let mode: Int // 弹幕类型，1为滚动
    let fontsize: Int // 字体大小
    let opacity: Double // 不透明度
    let color: Int // 颜色值
    let midHash: String // 用户hash
    let contentScore: Double? // 内容评分
    let upCount: Int // 点赞数
    let replyCount: Int // 回复数
    let ctime: Int // 创建时间
    let showWeight: Int // 权重
    let pool: Int // 弹幕池
    /// 渐变色（hex，无 #），≥2 且颜色不同时左→右渐变绘制
    let gradientColors: [String]?
    /// 气泡头像 URL（腾讯 bubble_head）
    let bubbleHead: String?
    /// 气泡等级角标 URL（腾讯 bubble_level）
    let bubbleLevel: String?
    /// VIP 等级（无 bubble_level 图时可用于文字角标）
    let vipDegree: Int?

    // MARK: - Computed Properties (保持兼容性)

    var timeOffsetInSeconds: Double {
        Double(progress) / 1000.0
    }

    var timeOffsetInMilliseconds: Int {
        progress
    }

    var score: Double {
        contentScore ?? 50.0
    }

    var isHighQuality: Bool {
        score > 51.0
    }

    /// 可用于渐变绘制的色值；不足 2 个不同色则返回 nil
    var resolvedGradientHexes: [String]? {
        guard let gradientColors, gradientColors.count >= 2 else { return nil }
        let cleaned = gradientColors
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "") }
            .filter { !$0.isEmpty }
        guard cleaned.count >= 2 else { return nil }
        let unique = Set(cleaned.map { $0.uppercased() })
        if unique.count < 2 {
            return nil
        }
        return cleaned
    }

    // MARK: - Swiftfin 适配属性

    var displayColor: Color {
        let red = CGFloat((color & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((color & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(color & 0x0000FF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    var position: DanmakuPosition {
        switch mode {
        case 4: return .bottom
        case 5: return .top
        default: return .scroll
        }
    }
}

// MARK: - DanmakuResponse (保持与参考实现兼容)

struct DanmakuResponse: Codable {
    let chatId: Int
    let chatServer: String
    let source: String
    let items: [DanmakuItem]

    private enum CodingKeys: String, CodingKey {
        case chatId
        case chatServer
        case source
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chatId = try container.decodeIfPresent(Int.self, forKey: .chatId) ?? 0
        chatServer = try container.decodeIfPresent(String.self, forKey: .chatServer) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        items = try container.decodeIfPresent([DanmakuItem].self, forKey: .items) ?? []
    }
}

// MARK: - SeriesDanmakuParams (保持与参考实现兼容)

struct SeriesDanmakuParams {
    let season: Int?
    let episode: Int?
    let mediaType: Int?

    init(season: Int? = nil, episode: Int? = nil, mediaType: Int? = nil) {
        self.season = season
        self.episode = episode
        self.mediaType = mediaType
    }
}

// MARK: - Color Extension

extension Color {

    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let rgb: Int = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255) << 0
        return String(format: "#%06x", rgb)
    }
}
