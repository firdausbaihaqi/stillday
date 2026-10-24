import AppKit
import WebKit

@MainActor
final class YouTubeController: NSObject, NSWindowDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var onClose: (() -> Void)?
    var onStatus: ((Bool, String?) -> Void)?
    private var window: NSWindow?
    private var webView: WKWebView?
    private var videoID: String?
    private var closing = false
    private var visibilityObserver: NSObjectProtocol?

    func show(videoID: String, volume: Double) {
        stop()
        closing = false
        self.videoID = videoID
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: "playback")
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = self
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 334), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Stillday · YouTube"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let container = NSView()
        web.translatesAutoresizingMaskIntoConstraints = false
        let note = NSTextField(labelWithString: "Keep this player visible. Close it to stop ambient sound.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(web); container.addSubview(note)
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: container.topAnchor), web.leadingAnchor.constraint(equalTo: container.leadingAnchor), web.trailingAnchor.constraint(equalTo: container.trailingAnchor), web.heightAnchor.constraint(equalToConstant: 292),
            note.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14), note.topAnchor.constraint(equalTo: web.bottomAnchor, constant: 13)
        ])
        window.contentView = container
        window.center()
        self.window = window; self.webView = web
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let identity = "https://\(Bundle.main.bundleIdentifier ?? "day.stillday.mac")"
        let html = """
        <!doctype html><html><head><meta name="referrer" content="strict-origin-when-cross-origin"><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body,#player{margin:0;width:100%;height:100%;background:#181d1b;overflow:hidden}</style></head><body><div id="player"></div><script>
        let player;
        function send(playing,message){window.webkit.messageHandlers.playback.postMessage({playing:playing,message:message||''});}
        function onYouTubeIframeAPIReady(){player=new YT.Player('player',{width:'100%',height:'100%',videoId:'\(videoID)',playerVars:{origin:'\(identity)',playsinline:1,autoplay:0,controls:1,loop:1,playlist:'\(videoID)'},events:{onReady:function(e){e.target.setVolume(\(Int(volume * 100)));send(false,'YouTube ready · press play');},onStateChange:function(e){send(e.data===YT.PlayerState.PLAYING,e.data===YT.PlayerState.PLAYING?'Playing from YouTube':'YouTube paused');},onError:function(e){send(false,'YouTube error '+e.data+' · try another video or local audio');}}});}
        let script=document.createElement('script');script.src='https://www.youtube.com/iframe_api';script.onerror=function(){send(false,'Could not load YouTube. Check your connection or use local audio.');};document.head.appendChild(script);
        </script></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: identity))
        visibilityObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, let window = self.window else { return }
                if !window.occlusionState.contains(.visible) { _ = try? await self.webView?.evaluateJavaScript("if(player && player.pauseVideo) player.pauseVideo();") }
            }
        }
    }

    func showExisting() {
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setVolume(_ volume: Double) { webView?.evaluateJavaScript("if(player && player.setVolume) player.setVolume(\(Int(volume * 100)));", completionHandler: nil) }

    func stop() {
        closing = true
        if let visibilityObserver { NotificationCenter.default.removeObserver(visibilityObserver) }
        visibilityObserver = nil
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "playback")
        webView?.navigationDelegate = nil
        webView?.loadHTMLString("", baseURL: nil)
        window?.delegate = nil
        window?.close()
        window?.contentView = nil
        window = nil; webView = nil; videoID = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard !closing else { return }
        stop()
        onClose?()
    }
    func windowWillMiniaturize(_ notification: Notification) {
        webView?.evaluateJavaScript("if(player && player.pauseVideo) player.pauseVideo();", completionHandler: nil)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let playing = body["playing"] as? Bool else { return }
        onStatus?(playing, body["message"] as? String)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { onStatus?(false, "YouTube could not load. Check your connection or use local audio.") }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.navigationType == .linkActivated, ["https", "http"].contains(url.scheme ?? "") {
            NSWorkspace.shared.open(url); decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
}
