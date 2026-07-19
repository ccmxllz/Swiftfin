//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import Nuke
import UIKit

/// 弹幕装饰图（bubble_head / bubble_level）异步加载缓存。
enum DanmakuDecorImageLoader {

    private static let memory = NSCache<NSString, UIImage>()

    static func cached(urlString: String?) -> UIImage? {
        guard let urlString, !urlString.isEmpty else { return nil }
        return memory.object(forKey: urlString as NSString)
    }

    /// 已缓存则同步返回；否则异步下载，完成后主线程回调。
    static func load(urlString: String?, completion: @escaping (UIImage?) -> Void) {
        guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        if let cached = memory.object(forKey: urlString as NSString) {
            completion(cached)
            return
        }

        ImagePipeline.shared.loadImage(with: url) { result in
            switch result {
            case let .success(response):
                let image = response.image
                memory.setObject(image, forKey: urlString as NSString)
                DispatchQueue.main.async {
                    completion(image)
                }
            case .failure:
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
