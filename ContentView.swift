import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var showModeSelection = false
    @State private var inputURL: URL?
    @State private var statusText = "Ready"
    
    let developerTag = "by kitanaizyxx"
    let modes = ["Linear", "Wide", "SuperView", "HyperView"]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 30) {
                VStack(spacing: 5) {
                    Text("123GOPRO STRETCH")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.blue)
                    Text(developerTag)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                if !isProcessing {
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        VStack(spacing: 20) {
                            Image(systemName: "video.badge.plus.fill").font(.system(size: 60))
                            Text("SELECT 4:3 VIDEO").bold()
                        }
                        .frame(width: 280, height: 280)
                        .background(RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.05)))
                        .foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 20) {
                        ProgressView().tint(.blue).scaleEffect(2)
                        Text(statusText).foregroundColor(.white).font(.caption)
                    }
                }
            }
        }
        .sheet(isPresented: $showModeSelection) {
            VStack(spacing: 15) {
                Text("SELECT MODE").font(.headline).padding(.top)
                ForEach(modes, id: \.self) { mode in
                    Button(action: { 
                        self.showModeSelection = false
                        self.runProcessing(mode: mode) 
                    }) {
                        Text(mode).bold().frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
                    }.padding(.horizontal)
                }
                Spacer()
            }
            .presentationDetents([.medium])
        }
        .onChange(of: selectedItem) { _ in
            Task {
                if let item = selectedItem,
                   let data = try? await item.loadTransferable(type: Data.self) {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("input.mp4")
                    try? data.write(to: url)
                    self.inputURL = url
                    self.showModeSelection = true
                }
            }
        }
    }
    
    func runProcessing(mode: String) {
        guard let url = inputURL else { return }
        isProcessing = true
        statusText = "Rendering \(mode)..."
        
        let asset = AVAsset(url: url)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("result.mp4")
        try? FileManager.default.removeItem(at: outputURL)
        
        let kValue: Float = (mode == "SuperView") ? 0.19 : (mode == "HyperView" ? 0.44 : 0.0)
        let kernel = CIWarpKernel(source: "kernel vec2 stretch(float width, float k) { vec2 p = destCoord(); float x = p.x / width; float normX = x * 2.0 - 1.0; float distortedX = normX + sin(normX * 3.141592) * k; return vec2((distortedX + 1.0) / 2.0 * width, p.y); }")

        let composition = AVMutableVideoComposition(asset: asset) { request in
            let source = request.sourceImage
            let w = source.extent.width
            let h = source.extent.height
            let targetW = h * (16/9)
            
            if mode == "Wide" {
                let rect = CGRect(x: 0, y: (h - (w * 9 / 16)) / 2, width: w, height: w * 9 / 16)
                request.finish(with: source.cropped(to: rect), context: nil)
            } else if let k = kernel {
                let output = k.apply(extent: CGRect(x: 0, y: 0, width: targetW, height: h),
                                    arguments: [Float(targetW), kValue], image: source)
                request.finish(with: output ?? source, context: nil)
            } else {
                request.finish(with: source, context: nil)
            }
        }

        let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        exporter?.videoComposition = composition
        exporter?.outputURL = outputURL
        exporter?.outputFileType = .mp4
        
        exporter?.exportAsynchronously {
            DispatchQueue.main.async { self.isProcessing = false }
        }
    }
}

// ТОЧКА ВХОДА (ОБЯЗАТЕЛЬНО)
@main
struct GoproStretchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
