import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var inputURL: URL?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("GOPRO STRETCH").font(.largeTitle).bold()
            Text("by kitanaizyxx").font(.caption)
            
            PhotosPicker(selection: $selectedItem, matching: .videos) {
                Text("SELECT VIDEO").padding().background(Color.blue).foregroundColor(.white).cornerRadius(10)
            }
            
            if isProcessing {
                ProgressView("Processing...")
            }
        }
        .onChange(of: selectedItem) { _ in
            Task {
                if let item = selectedItem, let data = try? await item.loadTransferable(type: Data.self) {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("input.mp4")
                    try? data.write(to: url)
                    self.inputURL = url
                    runStretch()
                }
            }
        }
    }
    
    func runStretch() {
        guard let url = inputURL else { return }
        isProcessing = true
        
        let asset = AVAsset(url: url)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.mp4")
        try? FileManager.default.removeItem(at: outputURL)
        
        let kernel = CIWarpKernel(source: "kernel vec2 stretch(float width, float k) { vec2 p = destCoord(); float x = p.x / width; float normX = x * 2.0 - 1.0; float distortedX = normX + sin(normX * 3.141592) * k; return vec2((distortedX + 1.0) / 2.0 * width, p.y); }")
        
        let composition = AVMutableVideoComposition(asset: asset) { request in
            let source = request.sourceImage
            let targetW = source.extent.height * (16/9)
            let output = kernel?.apply(extent: CGRect(x: 0, y: 0, width: targetW, height: source.extent.height),
                                      arguments: [Float(targetW), 0.19], image: source)
            request.finish(with: output ?? source, context: nil)
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

@main
struct GoproApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
