import UIKit
import SwiftUI
import WebKit
import AVKit
import CarPlay

// MARK: - ตัวจัดการเชื่อมต่อระหว่าง iPhone และหน้าจอรถยนต์ (CarPlay / External Display)
class StreamManager: ObservableObject {
    static let shared = StreamManager()
    @Published var currentStreamTitle: String = "ยังไม่ได้เลือกสตรีม"
    @Published var detectedVideoURL: URL? = nil
    @Published var isConnectedToCar: Bool = false
    
    var sharedPlayer: AVPlayer = {
        let p = AVPlayer()
        p.allowsExternalPlayback = true
        p.usesExternalPlaybackWhileExternalScreenIsActive = true
        return p
    }()
    
    func loadAndSendToCar(title: String, url: URL) {
        self.currentStreamTitle = title
        self.detectedVideoURL = url
        let item = AVPlayerItem(url: url)
        sharedPlayer.replaceCurrentItem(with: item)
        sharedPlayer.play()
        NotificationCenter.default.post(name: NSNotification.Name("UpdateCarPlayScreen"), object: nil)
    }
}

// MARK: - โมเดลบุ๊กมาร์ก
struct BookmarkItem: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let color: Color
    let icon: String
}

// MARK: - หน้าจอหลักบน iPhone (เหมือนตัวจำลอง)
struct ContentView: View {
    @ObservedObject var streamManager = StreamManager.shared
    @State private var currentTab: Int = 0 // 0 = Home Bookmarks, 1 = Web Browser
    @State private var urlInput: String = "https://m.youtube.com"
    @State private var activeWebURL: String = "https://m.youtube.com"
    @State private var showFullPlayer: Bool = false
    
    @State private var bookmarks: [BookmarkItem] = [
        BookmarkItem(name: "YouTube", url: "https://m.youtube.com", color: .red, icon: "play.rectangle.fill"),
        BookmarkItem(name: "ช่อง 33 HD", url: "https://ch3plus.com/live", color: .blue, icon: "tv.fill"),
        BookmarkItem(name: "ช่องวัน 31", url: "https://www.oned.net/live", color: .green, icon: "tv.circle.fill"),
        BookmarkItem(name: "ช่อง 7HD", url: "https://www.ch7.com/live.html", color: .purple, icon: "antenna.radiowaves.left.and.right"),
        BookmarkItem(name: "Twitch", url: "https://m.twitch.tv", color: .indigo, icon: "gamecontroller.fill"),
        BookmarkItem(name: "Apple HLS Test", url: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8", color: .orange, icon: "film.fill")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // แถบสถานะด้านบน + สถานะการเชื่อมต่อ CarPlay
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(streamManager.isConnectedToCar ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(streamManager.isConnectedToCar ? "CarPlay เชื่อมต่อแล้ว" : "โหมดสแตนด์บาย (รอจอรถ)")
                        .font(.caption)
                        .bold()
                }
                Spacer()
                // ปุ่มสลับหน้า Home / Browser
                Picker("", selection: $currentTab) {
                    Text("บุ๊กมาร์ก").tag(0)
                    Text("เบราว์เซอร์").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 170)
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
            
            // แบนเนอร์สีเขียวเมื่อ WKWebView ดักจับวิดีโอได้ (เหมือนตัวจำลอง)
            if let videoURL = streamManager.detectedVideoURL {
                HStack {
                    Image(systemName: "sparkles.tv.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("ตรวจพบสตรีมวิดีโอในหน้าเว็บ!")
                            .font(.caption).bold().foregroundColor(.white)
                        Text(videoURL.absoluteString)
                            .font(.system(size: 10)).foregroundColor(.gray).lineLimit(1)
                    }
                    Spacer()
                    Button(action: {
                        streamManager.loadAndSendToCar(title: "Web Video Stream", url: videoURL)
                        showFullPlayer = true
                    }) {
                        Text("ส่งขึ้นจอรถ / เล่น")
                            .font(.caption).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                }
                .padding(10)
                .background(Color.black)
            }
            
            // ส่วนแสดงผลหลัก
            if currentTab == 0 {
                // หน้า Bookmark Grid
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ทางลัดเว็บวิดีโอ & ทีวีสด")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(bookmarks) { item in
                                Button(action: {
                                    if item.url.hasSuffix(".m3u8") || item.url.hasSuffix(".mp4") {
                                        if let u = URL(string: item.url) {
                                            streamManager.loadAndSendToCar(title: item.name, url: u)
                                            showFullPlayer = true
                                        }
                                    } else {
                                        urlInput = item.url
                                        activeWebURL = item.url
                                        currentTab = 1
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: item.icon)
                                            .font(.title2)
                                            .foregroundColor(item.color)
                                        VStack(alignment: .leading) {
                                            Text(item.name)
                                                .font(.subheadline).bold()
                                                .foregroundColor(.primary)
                                            Text("กดเพื่อเปิดสตรีม")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                // หน้า Web Browser + แถบใส่ URL + ตัวดึงวิดีโออัตโนมัติ
                VStack(spacing: 0) {
                    HStack {
                        Button(action: { currentTab = 0 }) {
                            Image(systemName: "house.fill")
                        }
                        TextField("ใส่ URL เว็บไซต์ หรือ .m3u8", text: $urlInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        Button("ไป") {
                            let formatted = urlInput.hasPrefix("http") ? urlInput : "https://\(urlInput)"
                            activeWebURL = formatted
                            NotificationCenter.default.post(name: NSNotification.Name("NavigateWeb"), object: formatted)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(8)
                    .background(Color(UIColor.systemBackground))
                    
                    BrowserWebView(urlString: $activeWebURL)
                }
            }
        }
        // หน้าจอ Player พร้อมปุ่มยิงออก CarPlay / AirPlay Route
        .sheet(isPresented: $showFullPlayer) {
            VStack(spacing: 0) {
                HStack {
                    Text(streamManager.currentStreamTitle)
                        .font(.headline).foregroundColor(.white)
                    Spacer()
                    AirPlayRouteButton()
                        .frame(width: 40, height: 40)
                    Button("ปิด") { showFullPlayer = false }
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.black)
                
                VideoPlayer(player: streamManager.sharedPlayer)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

// MARK: - ปุ่มเลือกจอรถยนต์ (AirPlay / CarPlay Audio-Video Route)
struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .green
        picker.tintColor = .white
        picker.prioritizesVideoDevices = true
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - WKWebView พร้อมสคริปต์ดักจับ <video> และ .m3u8 เหมือนตัวจำลอง
struct BrowserWebView: UIViewRepresentable {
    @Binding var urlString: String
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let jsHook = """
        setInterval(function() {
            var videos = document.getElementsByTagName('video');
            for (var i = 0; i < videos.length; i++) {
                var src = videos[i].currentSrc || videos[i].src;
                if (src && src.startsWith('http')) {
                    window.webkit.messageHandlers.extractor.postMessage(src);
                }
            }
        }, 1200);
        """
        let script = WKUserScript(source: jsHook, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.userContentController.add(context.coordinator, name: "extractor")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        if let u = URL(string: urlString) {
            webView.load(URLRequest(url: u))
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("NavigateWeb"), object: nil, queue: .main) { note in
            if let target = note.object as? String, let u = URL(string: target) {
                webView.load(URLRequest(url: u))
            }
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "extractor", let src = message.body as? String, let url = URL(string: src) {
                DispatchQueue.main.async {
                    if StreamManager.shared.detectedVideoURL != url {
                        StreamManager.shared.detectedVideoURL = url
                    }
                }
            }
        }
    }
}

// MARK: - ระบบเชื่อมต่อหน้าจอรถยนต์ CarPlay (CarPlaySceneDelegate)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    var carWindow: CPWindow?
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController, to window: CPWindow) {
        self.interfaceController = interfaceController
        self.carWindow = window
        StreamManager.shared.isConnectedToCar = true
        
        // แนบ Video Player Layer เข้ากับหน้าต่างรถยนต์เมื่อมีการส่งสตรีม
        NotificationCenter.default.addObserver(forName: NSNotification.Name("UpdateCarPlayScreen"), object: nil, queue: .main) { _ in
            let playerVC = AVPlayerViewController()
            playerVC.player = StreamManager.shared.sharedPlayer
            window.rootViewController = playerVC
        }
        
        let item1 = CPListItem(text: "Apple HLS Test", detailText: "กดเพื่อเล่นสตรีมทดสอบบนจอรถ")
        item1.handler = { _, completion in
            if let u = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8") {
                StreamManager.shared.loadAndSendToCar(title: "Apple HLS Test", url: u)
            }
            completion()
        }
        
        let section = CPListSection(items: [item1])
        let listTemplate = CPListTemplate(title: "APTV CarPlay", sections: [section])
        interfaceController.setRootTemplate(listTemplate, animated: true, completion: nil)
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController, from window: CPWindow) {
        StreamManager.shared.isConnectedToCar = false
    }
}

// MARK: - App & Scene Delegate มาตรฐาน
@main
class AppDelegate: UIResponder, UIApplicationDelegate {}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ContentView())
        self.window = window
        window.makeKeyAndVisible()
    }
}