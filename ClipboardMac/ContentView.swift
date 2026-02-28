import SwiftUI
import Cocoa
import WebKit

struct ClipboardItem: Identifiable, Hashable {
    var id: String { pasteboardType }
    let pasteboardType: String
    let content: Data
    let timestamp: Date
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "\(formatter.string(from: timestamp))"
    }
    
    var typeDescription: String {
        // 返回类型的友好描述
        switch pasteboardType {
        case NSPasteboard.PasteboardType.string.rawValue, "NSStringPboardType", "public.utf8-plain-text", "public.text":
            return "Plain Text"
        case NSPasteboard.PasteboardType.rtf.rawValue, "public.rtf":
            return "Rich Text (RTF)"
        case NSPasteboard.PasteboardType.html.rawValue, "public.html":
            return "HTML Document"
        case "public.url":
            return "Web URL"
        case NSPasteboard.PasteboardType.pdf.rawValue, "com.adobe.pdf":
            return "PDF Document"
        case NSPasteboard.PasteboardType.png.rawValue, "public.png":
            return "PNG Image"
        case NSPasteboard.PasteboardType.tiff.rawValue, "public.tiff":
            return "TIFF Image"
        case "public.image":
            return "Image"
        case "public.file-url", "NSFilenamesPboardType":
            return "File Reference"
        case "com.apple.icns":
            return "macOS Icon"
        case "public.json":
            return "JSON Data"
        case "public.xml":
            return "XML Document"
        case "public.source-code":
            return "Source Code"
        case "public.movie", "public.video":
            return "Video File"
        case "public.audio":
            return "Audio File"
        case "Apple URL pasteboard type":
            return "Apple URL"
        case "com.apple.finder.noderef":
            return "Finder Node"
        case let type where type.hasPrefix("CorePasteboardFlavorType"):
            return "Internal Data"
        case let type where type.hasPrefix("dyn."):
            return "Dynamic Type"
        default:
            return pasteboardType
        }
    }
}

class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    
    init() {
        checkClipboard()
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        
        if changeCount != lastChangeCount {
            lastChangeCount = changeCount
            processClipboard()
        }
    }
    
    private func processClipboard() {
        let pasteboard = NSPasteboard.general
        guard let types = pasteboard.types, !types.isEmpty else { return }
        
        var updatedItems: [ClipboardItem] = []
        
        for type in types {
            if let data = pasteboard.data(forType: type) {
                let item = ClipboardItem(
                    pasteboardType: type.rawValue,
                    content: data,
                    timestamp: Date()
                )
                updatedItems.append(item)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.clipboardItems = updatedItems
        }
    }
}

struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @State private var selectedType: String?
    @State private var lastSelectedType: String?
    
    var body: some View {
        NavigationView {
            List(clipboardManager.clipboardItems) { item in
                VStack(alignment: .leading, spacing: 2) {
                    // 第一行：类型描述（带颜色标签）
                    HStack(spacing: 6) {
                        Text(item.typeDescription)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(typeColor(for: item.pasteboardType))
                        
                        Spacer()
                    }
                    
                    // 第二行：时间和原始类型
                    HStack(spacing: 6) {
                        Text(item.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        Text(item.pasteboardType)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    selectedType == item.pasteboardType
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
                )
                .cornerRadius(4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedType = item.pasteboardType
                    lastSelectedType = item.pasteboardType
                }
            }
            .navigationTitle("剪切板项")
            .listStyle(SidebarListStyle())
            .onChange(of: clipboardManager.clipboardItems) { newItems in
                if let lastType = lastSelectedType {
                    if newItems.contains(where: { $0.pasteboardType == lastType }) {
                        selectedType = lastType
                    } else {
                        selectedType = newItems.first?.pasteboardType
                        lastSelectedType = selectedType
                    }
                } else if selectedType == nil && !newItems.isEmpty {
                    selectedType = newItems.first?.pasteboardType
                    lastSelectedType = selectedType
                }
            }
            
            if let selectedType = selectedType,
               let item = clipboardManager.clipboardItems.first(where: { $0.pasteboardType == selectedType }) {
                ClipboardContentViewer(item: item)
                    .id(item.id)
            } else {
                Text("选择一个剪切板项来查看内容")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.1))
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // 根据类型返回颜色
    private func typeColor(for type: String) -> Color {
        switch type {
        case NSPasteboard.PasteboardType.string.rawValue, "NSStringPboardType", "public.utf8-plain-text", "public.text":
            return .blue
        case NSPasteboard.PasteboardType.html.rawValue, "public.html":
            return .orange
        case NSPasteboard.PasteboardType.rtf.rawValue, "public.rtf":
            return .purple
        case "public.url", "Apple URL pasteboard type":
            return .green
        case NSPasteboard.PasteboardType.pdf.rawValue, "com.adobe.pdf":
            return .red
        case NSPasteboard.PasteboardType.png.rawValue, NSPasteboard.PasteboardType.tiff.rawValue, "public.png", "public.tiff", "public.image", "com.apple.icns":
            return .pink
        case "public.file-url", "NSFilenamesPboardType":
            return .gray
        case "public.json", "public.xml", "public.source-code":
            return .cyan
        case "public.movie", "public.video":
            return .indigo
        case "public.audio":
            return .mint
        default:
            return .secondary
        }
    }
}

struct ClipboardContentViewer: View {
    let item: ClipboardItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("类型: \(item.pasteboardType)")
                    .font(.headline)
                
                Text("时间: \(String(describing: item.displayName.split(separator: " - ").last ?? ""))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                contentView
            }
            .padding()
        }
        .navigationTitle("内容预览")
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch item.pasteboardType {
        // 文本类型
        case NSPasteboard.PasteboardType.string.rawValue,
             "NSStringPboardType",
             "public.utf8-plain-text",
             "public.text":
            if let string = String(data: item.content, encoding: .utf8) {
                Text(string)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        // 富文本
        case NSPasteboard.PasteboardType.rtf.rawValue,
             "public.rtf":
            if let string = String(data: item.content, encoding: .utf8) {
                Text("RTF 内容:")
                    .font(.body)
                Text(string)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        // 图片类型
        case NSPasteboard.PasteboardType.png.rawValue,
             NSPasteboard.PasteboardType.tiff.rawValue,
             "public.png",
             "public.tiff",
             "public.image",
             "com.apple.icns",
             "NeXT TIFF v4.0 pasteboard type":
            if let image = NSImage(data: item.content) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 400, maxHeight: 400)
            }
        // PDF
        case NSPasteboard.PasteboardType.pdf.rawValue,
             "com.adobe.pdf":
            Text("PDF 内容")
                .font(.body)
            Text("(PDF 预览)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        // HTML
        case NSPasteboard.PasteboardType.html.rawValue,
             "public.html":
            if let html = String(data: item.content, encoding: .utf8) {
                VStack(alignment: .leading, spacing: 16) {
                    // 网页预览
                    Text("网页预览:")
                        .font(.headline)
                    HTMLPreviewView(htmlContent: html)
                        .frame(minHeight: 300)
                    
                    Divider()
                    
                    // 原始 HTML 代码
                    Text("原始 HTML 代码:")
                        .font(.headline)
                    Text(html)
                        .font(.system(.body, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        // URL
        case NSPasteboard.PasteboardType.URL.rawValue,
             "public.url":
            if let urlString = String(data: item.content, encoding: .utf8),
               let url = URL(string: urlString) {
                Text("URL:")
                    .font(.body)
                Text(url.absoluteString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        // 文件路径
        case "public.file-url",
             "NSFilenamesPboardType":
            if let urlString = String(data: item.content, encoding: .utf8),
               let url = URL(string: urlString) {
                Text("文件路径:")
                    .font(.body)
                Text(url.path)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        // Apple URL
        case "Apple URL pasteboard type":
            if let urlString = String(data: item.content, encoding: .utf8) {
                Text("Apple URL:")
                    .font(.body)
                Text(urlString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        // Finder 节点引用
        case "com.apple.finder.noderef":
            Text("Finder 节点引用")
                .font(.body)
            Text("(Finder 内部数据)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        // 颜色
        case NSPasteboard.PasteboardType.color.rawValue:
            Text("颜色数据")
                .font(.body)
            Text("(颜色信息)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        // 字体
        case NSPasteboard.PasteboardType.font.rawValue:
            Text("字体数据")
                .font(.body)
            Text("(字体信息)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        // 声音
        case NSPasteboard.PasteboardType.sound.rawValue:
            Text("音频数据")
                .font(.body)
            Text("(音频内容)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        // 多文件类型
        case NSPasteboard.PasteboardType.fileContents.rawValue:
            Text("文件内容")
                .font(.body)
            Text("(文件数据)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case NSPasteboard.PasteboardType.filePromise.rawValue:
            Text("文件承诺")
                .font(.body)
            Text("(延迟加载的文件)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        // 其他常见类型
        case "public.utf16-external-plain-text":
            if let string = String(data: item.content, encoding: .utf16) {
                Text("UTF-16 文本:")
                    .font(.body)
                Text(string)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "com.apple.traditional-mac-plain-text":
            if let string = String(data: item.content, encoding: .macOSRoman) {
                Text("Mac Roman 文本:")
                    .font(.body)
                Text(string)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.utf16-plain-text":
            if let string = String(data: item.content, encoding: .utf16) {
                Text("UTF-16 文本:")
                    .font(.body)
                Text(string)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.plain-text":
            if let string = String(data: item.content, encoding: .utf8) {
                Text(string)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.xml":
            if let xml = String(data: item.content, encoding: .utf8) {
                Text("XML 内容:")
                    .font(.body)
                Text(xml)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.json":
            if let json = String(data: item.content, encoding: .utf8) {
                Text("JSON 内容:")
                    .font(.body)
                Text(json)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.source-code":
            if let code = String(data: item.content, encoding: .utf8) {
                Text("源代码:")
                    .font(.body)
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.movie",
             "public.video":
            Text("视频内容")
                .font(.body)
            Text("(视频数据)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case "public.audio":
            Text("音频内容")
                .font(.body)
            Text("(音频数据)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        // CorePasteboard 类型 - 通常是内部数据
        case let type where type.hasPrefix("CorePasteboardFlavorType"):
            Text("CorePasteboard 内部数据")
                .font(.body)
            Text("(\(type))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        // dyn. 类型 - 动态生成的类型标识符
        case let type where type.hasPrefix("dyn."):
            Text("动态类型数据")
                .font(.body)
            Text("(\(type))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        default:
            Text("未知类型: \(item.pasteboardType)")
                .font(.body)
            Text("数据大小: \(item.content.count) 字节")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// HTML 预览视图
struct HTMLPreviewView: NSViewRepresentable {
    let htmlContent: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    padding: 20px;
                    line-height: 1.6;
                    color: #333;
                    background-color: transparent;
                }
                img { max-width: 100%; height: auto; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
}
