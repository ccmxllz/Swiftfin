//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import Factory
import Logging
import SwiftUI

#if canImport(UIKit)
import UIKit

// MARK: - DanmakuView

struct DanmakuView: UIViewRepresentable {

    // MARK: - Properties

    @ObservedObject
    var viewModel: DanmakuViewModel

    // MARK: - Coordinator

    class Coordinator: NSObject {
        @Injected(\.logService)
        private var logger

        var parent: DanmakuView
        var renderer: DanmakuRenderer?
        var cancellables = Set<AnyCancellable>()
        var processedDanmakuIds: Set<Int> = []
        var lastSettings: DanmakuRenderSettings?
        var lastPaused: Bool?
        var lastEnabled: Bool?

        init(parent: DanmakuView) {
            self.parent = parent
            super.init()

            parent.viewModel.$currentDanmakus
                .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] danmakus in
                    self?.processDanmakus(danmakus)
                }
                .store(in: &cancellables)

            parent.viewModel.$renderEpoch
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.handleRenderEpochChange()
                }
                .store(in: &cancellables)
        }

        deinit {
            cancellables.forEach { $0.cancel() }
        }

        func processDanmakus(_ danmakus: [DanmakuItem]) {
            guard parent.viewModel.isEnabled, !danmakus.isEmpty else {
                if !parent.viewModel.isEnabled {
                    processedDanmakuIds.removeAll()
                }
                return
            }

            let newDanmakus = danmakus.filter { !processedDanmakuIds.contains($0.id) }
            guard !newDanmakus.isEmpty else { return }

            logger.debug("Processing \(newDanmakus.count) new danmaku items")
            renderer?.addDanmakuItems(newDanmakus)

            for item in newDanmakus {
                processedDanmakuIds.insert(item.id)
            }

            if processedDanmakuIds.count > 1000 {
                // Set has no stable order; drop all and keep only the latest batch.
                processedDanmakuIds = Set(newDanmakus.map(\.id))
            }
        }

        func handleRenderEpochChange() {
            processedDanmakuIds.removeAll()
            renderer?.clearAllDanmaku()
        }

        func applySettingsIfNeeded() {
            let settings = DanmakuRenderSettings.current()
            let enabled = parent.viewModel.isEnabled
            let paused = parent.viewModel.isPaused

            if lastSettings != settings {
                lastSettings = settings
                renderer?.apply(settings: settings)
            }

            if lastEnabled != enabled {
                lastEnabled = enabled
                renderer?.setEnabled(enabled)
            }

            if lastPaused != paused {
                lastPaused = paused
                if paused {
                    renderer?.stopAnimation()
                } else if enabled {
                    renderer?.setEnabled(true)
                }
            }
        }
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        let renderer = DanmakuRenderer(containerView: view)
        context.coordinator.renderer = renderer

        let settings = DanmakuRenderSettings.current()
        context.coordinator.lastSettings = settings
        context.coordinator.lastEnabled = viewModel.isEnabled
        context.coordinator.lastPaused = viewModel.isPaused
        renderer.apply(settings: settings)
        renderer.setEnabled(viewModel.isEnabled)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self

        if uiView.bounds.size != .zero {
            context.coordinator.renderer?.setContainerSize(uiView.bounds.size)
        }

        context.coordinator.applySettingsIfNeeded()
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.renderer?.stopAnimation()
        coordinator.renderer?.clearAllDanmaku()
        coordinator.cancellables.forEach { $0.cancel() }
    }
}

#else
/// 非 UIKit 平台的占位实现
struct DanmakuView: View {
    @ObservedObject
    var viewModel: DanmakuViewModel

    var body: some View {
        Text("弹幕功能仅支持iOS平台")
            .foregroundColor(.white)
            .font(.caption)
            .opacity(0.7)
    }
}
#endif
