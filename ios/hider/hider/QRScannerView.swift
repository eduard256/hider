//
//  QRScannerView.swift
//  hider
//
//  Живое превью камеры со сканированием QR (iOS, iPadOS, macOS-вебка).
//

import SwiftUI
import AVFoundation
import os

private let log = Logger(subsystem: "com.webaweba.hider", category: "qrscanner")

struct QRScannerView: View {
    var onCode: (String) -> Void

    @State private var authorized: Bool?

    var body: some View {
        Group {
            if authorized == true {
                CameraPreview(onCode: onCode)
            } else {
                // Нет доступа/камеры — бледная иконка
                Image(systemName: authorized == false ? "video.slash" : "video")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundStyle(DS.ink.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                authorized = true
            case .notDetermined:
                authorized = await AVCaptureDevice.requestAccess(for: .video)
            default:
                authorized = false
            }
        }
    }
}

// MARK: - Превью камеры (UIKit/AppKit)

#if os(iOS)
private typealias PlatformViewRepresentable = UIViewRepresentable
#else
private typealias PlatformViewRepresentable = NSViewRepresentable
#endif

private struct CameraPreview: PlatformViewRepresentable {
    var onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    #if os(iOS)
    func makeUIView(context: Context) -> PreviewContainer {
        PreviewContainer(session: context.coordinator.session)
    }
    func updateUIView(_ view: PreviewContainer, context: Context) {}
    static func dismantleUIView(_ view: PreviewContainer, coordinator: Coordinator) {
        coordinator.stop()
    }
    #else
    func makeNSView(context: Context) -> PreviewContainer {
        PreviewContainer(session: context.coordinator.session)
    }
    func updateNSView(_ view: PreviewContainer, context: Context) {}
    static func dismantleNSView(_ view: PreviewContainer, coordinator: Coordinator) {
        coordinator.stop()
    }
    #endif

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let session = AVCaptureSession()
        private let onCode: (String) -> Void
        private var found = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
            super.init()
            configure()
        }

        private func configure() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                log.warning("no camera input available")
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                log.warning("cannot add metadata output")
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
            }

            let session = self.session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        func stop() {
            let session = self.session
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !found,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let string = object.stringValue else { return }
            found = true
            log.info("qr code scanned")
            onCode(string)
        }
    }
}

#if os(iOS)
private final class PreviewContainer: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        let preview = layer as! AVCaptureVideoPreviewLayer
        preview.session = session
        preview.videoGravity = .resizeAspectFill
        // Скругление на самом слое — SwiftUI-клип теряется при анимации клавиатуры
        preview.cornerRadius = 16
        preview.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }
}
#else
private final class PreviewContainer: NSView {
    private let preview: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.cornerRadius = 16
        preview.masksToBounds = true
        super.init(frame: .zero)
        wantsLayer = true
        layer = preview
    }

    required init?(coder: NSCoder) { fatalError() }
}
#endif
