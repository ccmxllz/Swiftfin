//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import Foundation
import Logging

// MARK: - Factory Registration

extension Container {
    var danmakuService: Factory<DanmakuService> {
        self { DanmakuService() }.singleton
    }
}

// MARK: - DanmakuService

final class DanmakuService {

    @Injected(\.logService)
    private var logger

    // MARK: - Properties

    private let session = URLSession.shared

    private var baseURL: String {
        let configuredURL = Defaults[.VideoPlayer.Overlay.danmakuAPIBaseURL]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if configuredURL.isEmpty {
            return "http://192.168.50.112:8080/danmu/api/danmu" // 默认地址
        }
        return configuredURL.hasSuffix("/") ? String(configuredURL.dropLast()) : configuredURL
    }

    // MARK: - Public Methods

    /// 获取指定平台和关键词的分段弹幕
    /// - Parameters:
    ///   - platform: 平台标识(tencent, iqiyi, bilibili等)
    ///   - keyword: 查询关键词(视频标题)
    ///   - start: 起始时间(秒)
    ///   - end: 结束时间(秒)
    ///   - seriesParams: 系列参数(season, episode, mediaType)
    /// - Returns: 弹幕数组
    func fetchDanmakuSegment(
        platform: String,
        keyword: String,
        start: Int,
        end: Int,
        seriesParams: SeriesDanmakuParams? = nil
    ) async throws -> [DanmakuItem] {

        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlatform = platform.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKeyword.isEmpty else {
            throw DanmakuError.invalidKeyword
        }
        guard !trimmedPlatform.isEmpty else {
            throw DanmakuError.invalidURL
        }

        guard var url = URL(string: baseURL) else {
            logger.error("弹幕 API 地址无效: \(baseURL)")
            throw DanmakuError.invalidURL
        }
        url.appendPathComponent(trimmedPlatform)
        url.appendPathComponent("segment.json")

        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.error("弹幕 URL 构建失败: \(url.absoluteString)")
            throw DanmakuError.invalidURL
        }

        var queryItems = [
            URLQueryItem(name: "keyword", value: trimmedKeyword),
            URLQueryItem(name: "start", value: "\(start)"),
            URLQueryItem(name: "end", value: "\(end)"),
        ]

        // 添加系列参数
        if let seriesParams = seriesParams {
            let isMovie = seriesParams.mediaType == 1

            if isMovie {
                if let mediaType = seriesParams.mediaType {
                    queryItems.append(URLQueryItem(name: "mediaType", value: "\(mediaType)"))
                    logger.debug("电影类型，添加媒体类型参数: mediaType=\(mediaType)")
                }
            } else {
                if let season = seriesParams.season {
                    queryItems.append(URLQueryItem(name: "season", value: "\(season)"))
                    logger.debug("添加季数参数: season=\(season)")
                }
                if let episode = seriesParams.episode {
                    queryItems.append(URLQueryItem(name: "episode", value: "\(episode)"))
                    logger.debug("添加集数参数: episode=\(episode)")
                }
                if let mediaType = seriesParams.mediaType {
                    queryItems.append(URLQueryItem(name: "mediaType", value: "\(mediaType)"))
                    logger.debug("添加媒体类型参数: mediaType=\(mediaType)")
                }
            }
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw DanmakuError.invalidURL
        }

        logger.debug("请求弹幕数据: \(url.absoluteString)")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("弹幕响应异常: 状态码\(statusCode)")
            throw DanmakuError.invalidResponse(statusCode)
        }

        do {
            let danmakuResponse = try JSONDecoder().decode(DanmakuResponse.self, from: data)
            logger.debug("弹幕数据解析成功: 获取到\(danmakuResponse.items.count)条弹幕")
            return danmakuResponse.items
        } catch {
            logger.error("弹幕数据解析失败: \(error.localizedDescription)")
            throw DanmakuError.decodingFailed(error)
        }
    }
}

// MARK: - DanmakuError

enum DanmakuError: LocalizedError {
    case invalidKeyword
    case invalidURL
    case invalidResponse(Int)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidKeyword:
            return "无效的弹幕关键词"
        case .invalidURL:
            return "无效的URL"
        case let .invalidResponse(statusCode):
            return "无效的响应，状态码: \(statusCode)"
        case let .decodingFailed(error):
            return "弹幕数据解析失败: \(error.localizedDescription)"
        }
    }
}
