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
        switch pasteboardType {
        case NSPasteboard.PasteboardType.string.rawValue, "NSStringPboardType", "public.utf8-plain-text", "public.text":
            return "Plain Text"
        case NSPasteboard.PasteboardType.rtf.rawValue, "public.rtf":
            return "Rich Text (RTF)"
        case NSPasteboard.PasteboardType.html.rawValue, "public.html", "Apple HTML pasteboard type":
            return "HTML Document"
        case "public.url":
            return "Web URL"
        case NSPasteboard.PasteboardType.pdf.rawValue, "com.adobe.pdf":
            return "PDF Document"
        case NSPasteboard.PasteboardType.png.rawValue, "public.png", "Apple PNG pasteboard type":
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
        case "org.chromium.source-url":
            return "Chromium Source URL"
        case "org.chromium.web-custom-data":
            return "Chromium Web Custom Data"
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

struct ClipboardHistoryItem: Identifiable, Codable, Hashable {
    let id: String
    let typeContentMap: [String: Data]
    let timestamp: Date
    
    var types: [String] {
        Array(typeContentMap.keys)
    }
    
    init(typeContentMap: [String: Data], timestamp: Date) {
        self.id = UUID().uuidString
        self.typeContentMap = typeContentMap
        self.timestamp = timestamp
    }
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return "\(formatter.string(from: timestamp))"
    }
    
    var typeDescription: String {
        let typeNames = types.map { type -> String in
            switch type {
            case NSPasteboard.PasteboardType.string.rawValue, "NSStringPboardType", "public.utf8-plain-text", "public.text":
                return "Text"
            case NSPasteboard.PasteboardType.rtf.rawValue, "public.rtf":
                return "RTF"
            case NSPasteboard.PasteboardType.html.rawValue, "public.html", "Apple HTML pasteboard type":
                return "HTML"
            case "public.url":
                return "URL"
            case NSPasteboard.PasteboardType.pdf.rawValue, "com.adobe.pdf":
                return "PDF"
            case NSPasteboard.PasteboardType.png.rawValue, "public.png", "Apple PNG pasteboard type":
                return "PNG"
            case NSPasteboard.PasteboardType.tiff.rawValue, "public.tiff":
                return "TIFF"
            case "public.image":
                return "Image"
            case "public.file-url", "NSFilenamesPboardType":
                return "File"
            case "com.apple.icns":
                return "Icon"
            case "public.json":
                return "JSON"
            case "public.xml":
                return "XML"
            case "public.source-code":
                return "Code"
            case "public.movie", "public.video":
                return "Video"
            case "public.audio":
                return "Audio"
            default:
                return type.split(separator: ".").last?.description ?? type
            }
        }
        return typeNames.joined(separator: ", ")
    }
}

class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var historyItems: [ClipboardHistoryItem] = []
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxHistoryItems = 50
    
    init() {
        loadHistory()
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
        guard let types = pasteboard.types, !types.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.clipboardItems = []
            }
            return
        }
        
        var updatedItems: [ClipboardItem] = []
        var typeContentMap: [String: Data] = [:]
        
        for type in types {
            if let data = pasteboard.data(forType: type) {
                let item = ClipboardItem(
                    pasteboardType: type.rawValue,
                    content: data,
                    timestamp: Date()
                )
                updatedItems.append(item)
                typeContentMap[type.rawValue] = data
            }
        }
        
        // 添加到历史记录
        addToHistory(typeContentMap: typeContentMap)
        
        DispatchQueue.main.async { [weak self] in
            self?.clipboardItems = updatedItems
        }
    }
    
    private func addToHistory(typeContentMap: [String: Data]) {
        let historyItem = ClipboardHistoryItem(typeContentMap: typeContentMap, timestamp: Date())
        
        // 移除重复的历史记录
        historyItems = historyItems.filter { $0.typeContentMap != typeContentMap }
        
        // 添加到历史记录开头
        historyItems.insert(historyItem, at: 0)
        
        // 限制历史记录数量
        if historyItems.count > maxHistoryItems {
            historyItems = Array(historyItems.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(historyItems)
            UserDefaults.standard.set(data, forKey: "clipboardHistory")
        } catch {
            print("Error saving history: \(error)")
        }
    }
    
    private func loadHistory() {
        do {
            if let data = UserDefaults.standard.data(forKey: "clipboardHistory") {
                let decoder = JSONDecoder()
                historyItems = try decoder.decode([ClipboardHistoryItem].self, from: data)
            }
        } catch {
            print("Error loading history: \(error)")
            historyItems = []
        }
    }
    
    func clearClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        lastChangeCount = pasteboard.changeCount
        DispatchQueue.main.async { [weak self] in
            self?.clipboardItems = []
        }
    }
    
    func removeItem(withType type: String) {
        let pasteboard = NSPasteboard.general
        
        // 1. 先计算要保留的项目
        let itemsToKeep = clipboardItems.filter { $0.pasteboardType != type }
        
        // 2. 清空剪切板
        pasteboard.clearContents()
        
        // 3. 写入要保留的项目
        if !itemsToKeep.isEmpty {
            let pasteboardItem = NSPasteboardItem()
            for item in itemsToKeep {
                let pbType = NSPasteboard.PasteboardType(item.pasteboardType)
                pasteboardItem.setData(item.content, forType: pbType)
            }
            pasteboard.writeObjects([pasteboardItem])
        }
        
        lastChangeCount = pasteboard.changeCount
        
        // 4. 更新本地列表
        DispatchQueue.main.async { [weak self] in
            self?.clipboardItems = itemsToKeep
        }
    }
    
    func restoreFromHistory(_ historyItem: ClipboardHistoryItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let pasteboardItem = NSPasteboardItem()
        for (type, data) in historyItem.typeContentMap {
            pasteboardItem.setData(data, forType: NSPasteboard.PasteboardType(type))
        }
        pasteboard.writeObjects([pasteboardItem])
        
        lastChangeCount = pasteboard.changeCount
        processClipboard()
    }
    
    func clearHistory() {
        historyItems = []
        saveHistory()
    }
    
    func removeHistoryItem(_ item: ClipboardHistoryItem) {
        historyItems.removeAll { $0.id == item.id }
        saveHistory()
    }
}

struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @State private var selectedType: String?
    @State private var lastSelectedType: String?
    @State private var selectedHistoryItem: String?
    @State private var selectedHistoryItemType: String?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showHistory = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack {
                
                List(clipboardManager.clipboardItems) { item in
                    ClipboardItemRow(
                        item: item,
                        isSelected: selectedType == item.pasteboardType,
                        onSelect: {
                            selectedType = item.pasteboardType
                            lastSelectedType = item.pasteboardType
                        },
                        onDelete: {
                            clipboardManager.removeItem(withType: item.pasteboardType)
                            if selectedType == item.pasteboardType {
                                selectedType = nil
                                lastSelectedType = nil
                            }
                        }
                    )
                }
                .listStyle(SidebarListStyle())
                
                if showHistory {
                    Divider()
                    HStack {
                        Text("History")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.leading, 12)
                        Spacer()
                        Button(action: {
                            clipboardManager.clearHistory()
                            selectedHistoryItem = nil
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                Text("Clear All")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 12)
                        .disabled(clipboardManager.historyItems.isEmpty)
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    HStack(spacing: 0) {
                        // 第一列：历史记录列表
                        ScrollView {
                            LazyVStack(spacing: 1) {
                                ForEach(clipboardManager.historyItems) { historyItem in
                                    HistoryItemRow(
                                        historyItem: historyItem,
                                        isSelected: selectedHistoryItem == historyItem.id,
                                        onSelect: {
                                            selectedHistoryItem = historyItem.id
                                            selectedHistoryItemType = nil
                                            selectedType = nil
                                            lastSelectedType = nil
                                        },
                                        onRestore: {
                                            clipboardManager.restoreFromHistory(historyItem)
                                        },
                                        onDelete: {
                                            clipboardManager.removeHistoryItem(historyItem)
                                            if selectedHistoryItem == historyItem.id {
                                                selectedHistoryItem = nil
                                                selectedHistoryItemType = nil
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .frame(minWidth: 320, maxWidth: 500)
                        
                        // 分隔线
                        Divider()
                        
                        // 第二列：选中项的详细信息
                        if let selectedHistoryItemId = selectedHistoryItem, 
                           let historyItem = clipboardManager.historyItems.first(where: { $0.id == selectedHistoryItemId }) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    // 标题区域
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "clock.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.accentColor)
                                            Text("History Item")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Timestamp")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                            Text(historyItem.displayName)
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                    }
                                    .padding(.bottom, 8)
                                    
                                    Divider()
                                    
                                    // 类型列表
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                            Text("Available Types")
                                                .font(.system(size: 13, weight: .medium))
                                            Text("(\(historyItem.types.count))")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            ForEach(historyItem.types, id: \.self) { type in
                                                TypeItemRow(
                                                    type: type,
                                                    isSelected: selectedHistoryItemType == type,
                                                    onSelect: {
                                                        selectedHistoryItemType = type
                                                    }
                                                )
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(16)
                            }
                            .frame(minWidth: 280, maxWidth: 400)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("Select a history item")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("to view available types")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .frame(minWidth: 280, maxWidth: 400, maxHeight: .infinity)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300)
            .navigationTitle("Clipboard")
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        showHistory.toggle()
                    }) {
                        Label("History", systemImage: "clock.fill")
                    }
                    .help("Toggle history")
                }
                ToolbarItem {
                    Button(action: {
                        clipboardManager.clearClipboard()
                        selectedType = nil
                        lastSelectedType = nil
                    }) {
                        Label("Clear", systemImage: "trash")
                    }
                    .help("Clear clipboard")
                    .disabled(clipboardManager.clipboardItems.isEmpty)
                }
            }
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
            .onChange(of: selectedHistoryItem) { newValue in
                if newValue != nil {
                    selectedType = nil
                    lastSelectedType = nil
                    selectedHistoryItemType = nil
                }
            }
        } detail: {
            if let selectedType = selectedType,
               let item = clipboardManager.clipboardItems.first(where: { $0.pasteboardType == selectedType }) {
                ClipboardContentViewer(item: item)
                    .id(item.id)
            } else if let selectedHistoryItemId = selectedHistoryItem, 
                      let historyItem = clipboardManager.historyItems.first(where: { $0.id == selectedHistoryItemId }) {
                let targetType = selectedHistoryItemType ?? historyItem.types.first
                if let type = targetType,
                   let data = historyItem.typeContentMap[type] {
                    let item = ClipboardItem(
                        pasteboardType: type,
                        content: data,
                        timestamp: historyItem.timestamp
                    )
                    ClipboardContentViewer(item: item)
                        .id(historyItem.id)
                } else {
                    Text("No content to preview")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.1))
                }
            } else {
                Text("Select a clipboard item to view content")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.1))
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyEvent(event)
                return event
            }
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        let items = clipboardManager.clipboardItems
        guard !items.isEmpty else { return }
        
        let currentIndex: Int
        if let selectedType = selectedType {
            currentIndex = items.firstIndex(where: { $0.pasteboardType == selectedType }) ?? -1
        } else {
            currentIndex = -1
        }
        
        switch event.keyCode {
        case 126:
            let newIndex = max(0, currentIndex - 1)
            if newIndex >= 0 && newIndex < items.count {
                selectedType = items[newIndex].pasteboardType
                lastSelectedType = selectedType
            }
        case 125:
            let newIndex = min(items.count - 1, currentIndex + 1)
            if newIndex >= 0 && newIndex < items.count {
                selectedType = items[newIndex].pasteboardType
                lastSelectedType = selectedType
            }
        default:
            break
        }
    }
}

private func typeColor(for type: String) -> Color {
    switch type {
    case NSPasteboard.PasteboardType.string.rawValue, "NSStringPboardType", "public.utf8-plain-text", "public.text":
        return .blue
    case NSPasteboard.PasteboardType.html.rawValue, "public.html", "Apple Html pasteboard type":
        return .orange
    case NSPasteboard.PasteboardType.rtf.rawValue, "public.rtf":
        return .purple
    case "public.url", "Apple URL pasteboard type", "org.chromium.source-url", "org.chromium.web-custom-data":
        return .green
    case NSPasteboard.PasteboardType.pdf.rawValue, "com.adobe.pdf":
        return .red
    case NSPasteboard.PasteboardType.png.rawValue, NSPasteboard.PasteboardType.tiff.rawValue, "public.png", "public.tiff", "public.image", "com.apple.icns", "Apple PNG pasteboard type":
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

struct ClipboardContentViewer: View {
    let item: ClipboardItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Type: \(item.pasteboardType)")
                    .font(.headline)
                
                Text("Time: \(String(describing: item.displayName.split(separator: " - ").last ?? ""))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                contentView
            }
            .padding()
        }
        .navigationTitle("Content Preview")
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch item.pasteboardType {
        case NSPasteboard.PasteboardType.string.rawValue,
             "NSStringPboardType",
             "public.utf8-plain-text",
             "public.text":
            if let string = String(data: item.content, encoding: .utf8) {
                Text(string)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case NSPasteboard.PasteboardType.rtf.rawValue,
             "public.rtf":
            if let string = String(data: item.content, encoding: .utf8) {
                Text("RTF Content:")
                    .font(.body)
                Text(string)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case NSPasteboard.PasteboardType.png.rawValue,
             NSPasteboard.PasteboardType.tiff.rawValue,
             "public.png",
             "public.tiff",
             "public.image",
             "com.apple.icns",
             "NeXT TIFF v4.0 pasteboard type",
             "Apple PNG pasteboard type",
             "public.jpeg",
             "public.gif",
             "public.bmp":
            if let image = NSImage(data: item.content) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 400, maxHeight: 400)
            }
        case NSPasteboard.PasteboardType.pdf.rawValue,
             "com.adobe.pdf":
            Text("PDF Content")
                .font(.body)
            Text("(PDF Preview)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case NSPasteboard.PasteboardType.html.rawValue,
             "public.html",
             "Apple HTML pasteboard type":
            if let html = String(data: item.content, encoding: .utf8) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Web Preview:")
                        .font(.headline)
                    HTMLPreviewView(htmlContent: html)
                        .frame(minHeight: 300)
                    
                    Divider()
                    
                    Text("Raw HTML Source:")
                        .font(.headline)
                    Text(html)
                        .font(.system(.body, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
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
        case "public.file-url",
             "NSFilenamesPboardType":
            if let urlString = String(data: item.content, encoding: .utf8),
               let url = URL(string: urlString) {
                Text("File Path:")
                    .font(.body)
                Text(url.path)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "Apple URL pasteboard type":
            if let urlString = String(data: item.content, encoding: .utf8) {
                Text("Apple URL:")
                    .font(.body)
                Text(urlString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "org.chromium.source-url":
            if let urlString = String(data: item.content, encoding: .utf8) {
                Text("Chromium Source URL:")
                    .font(.body)
                Text(urlString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "com.apple.finder.noderef":
            Text("Finder Node Reference")
                .font(.body)
            Text("(Finder Internal Data)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case NSPasteboard.PasteboardType.color.rawValue:
            Text("Color Data")
                .font(.body)
            Text("(Color Information)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case NSPasteboard.PasteboardType.font.rawValue:
            Text("Font Data")
                .font(.body)
            Text("(Font Information)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case NSPasteboard.PasteboardType.sound.rawValue:
            Text("Audio Data")
                .font(.body)
            Text("(Audio Content)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case NSPasteboard.PasteboardType.fileContents.rawValue:
            Text("File Contents")
                .font(.body)
            Text("(File Data)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case NSPasteboard.PasteboardType.filePromise.rawValue:
            Text("File Promise")
                .font(.body)
            Text("(Lazy Loaded File)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case "public.utf16-external-plain-text":
            if let string = String(data: item.content, encoding: .utf16) {
                Text("UTF-16 Text:")
                    .font(.body)
                Text(string)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "com.apple.traditional-mac-plain-text":
            if let string = String(data: item.content, encoding: .macOSRoman) {
                Text("Mac Roman Text:")
                    .font(.body)
                Text(string)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.utf16-plain-text":
            if let string = String(data: item.content, encoding: .utf16) {
                Text("UTF-16 Text:")
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
                Text("XML Content:")
                    .font(.body)
                Text(xml)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.json":
            if let json = String(data: item.content, encoding: .utf8) {
                Text("JSON Content:")
                    .font(.body)
                Text(json)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.source-code":
            if let code = String(data: item.content, encoding: .utf8) {
                Text("Source Code:")
                    .font(.body)
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "public.movie",
             "public.video",
             "public.mpeg-4",
             "public.avi",
             "public.mov":
            Text("Video Content")
                .font(.body)
            Text("(Video Data)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case "public.audio",
             "public.mp3",
             "public.wav",
             "public.aiff":
            Text("Audio Content")
                .font(.body)
            Text("(Audio Data)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case "public.spreadsheet",
             "com.microsoft.excel.xls",
             "com.microsoft.excel.xlsx":
            Text("Spreadsheet Document")
                .font(.body)
            Text("(Excel or Spreadsheet Data)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case "public.wordprocessing",
             "com.microsoft.word.doc",
             "com.microsoft.word.docx":
            Text("Word Processing Document")
                .font(.body)
            Text("(Word or Text Document Data)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case let type where type.hasPrefix("CorePasteboardFlavorType"):
            Text("CorePasteboard Internal Data")
                .font(.body)
            Text("(\(type))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case let type where type.hasPrefix("dyn."):
            Text("Dynamic Type Data")
                .font(.body)
            Text("(\(type))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        case "org.chromium.web-custom-data":
            if let data = String(data: item.content, encoding: .utf8) {
                Text("Chromium Web Custom Data:")
                    .font(.body)
                Text(data)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Chromium Web Custom Data")
                    .font(.body)
                Text("(Binary Data)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        default:
            Text("Unknown Type: \(item.pasteboardType)")
                .font(.body)
            Text("Data Size: \(item.content.count) bytes")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.typeDescription)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(typeColor(for: item.pasteboardType))
                    
                    Spacer()
                }
                
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
            
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color.gray.opacity(0.15)
        } else {
            return Color.clear
        }
    }
}

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

struct HistoryItemRow: View {
    let historyItem: ClipboardHistoryItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：时间戳和类型数量
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 16)
                    .layoutPriority(2)
                
                Text(historyItem.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                
                Spacer(minLength: 4)
                
                Text("\(historyItem.types.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
                    .layoutPriority(2)
                
                if isHovered {
                    HStack(spacing: 4) {
                        Button(action: onRestore) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .scale))
                    .layoutPriority(2)
                }
            }
            
            // 第二行：文本预览
            if let firstType = historyItem.types.first, 
               let data = historyItem.typeContentMap[firstType],
               let text = String(data: data, encoding: .utf8) {
                Text(text.prefix(80).replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(0)
            } else {
                Text("Non-text content")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: onRestore) {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            Button(action: onSelect) {
                Label("Preview", systemImage: "eye")
            }
            Divider()
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor)
        } else {
            return Color.clear
        }
    }
}

struct TypeItemRow: View {
    let type: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // 类型图标
                Image(systemName: typeIcon(for: type))
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 16)
                
                // 类型名称
                Text(type)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                
                Spacer()
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.1)
        } else if isHovered {
            return Color.secondary.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private func typeIcon(for type: String) -> String {
        switch type {
        case let t where t.contains("text") || t.contains("string"):
            return "textformat"
        case let t where t.contains("html"):
            return "globe"
        case let t where t.contains("image") || t.contains("png") || t.contains("jpg") || t.contains("tiff"):
            return "photo"
        case let t where t.contains("url"):
            return "link"
        case let t where t.contains("file"):
            return "doc"
        case let t where t.contains("pdf"):
            return "doc.richtext"
        case let t where t.contains("json"):
            return "curlybraces"
        case let t where t.contains("xml"):
            return "chevron.left.forwardslash.chevron.right"
        case let t where t.contains("code") || t.contains("source"):
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.text"
        }
    }
}
