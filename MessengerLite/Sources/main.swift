import AppKit
import WebKit

func isMessengerHost(_ host: String?) -> Bool {
    guard let host = host?.lowercased() else { return false }
    return ["facebook.com", "messenger.com"].contains {
        host == $0 || host.hasSuffix("." + $0)
    }
}

@MainActor
final class BrowserWindow: NSWindowController, NSWindowDelegate, WKUIDelegate, WKNavigationDelegate, WKDownloadDelegate {
    let webView: WKWebView
    let isMain: Bool
    weak var appDelegate: AppDelegate?

    init(configuration: WKWebViewConfiguration, main: Bool, owner: AppDelegate) {
        self.isMain = main
        self.appDelegate = owner
        // Popup configurations contain WebKit's opener state and must not be replaced.
        configuration.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: configuration)
        // WKWebView's default user agent lacks Safari's Version/Safari tokens.
        // Identify the system WebKit as Safari, without pretending it is Chromium.
        let safariVersion = Bundle(url: URL(fileURLWithPath: "/Applications/Safari.app"))?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "17.0"
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(safariVersion) Safari/605.1.15"
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0,
                                                  width: main ? 1080 : 900,
                                                  height: main ? 780 : 680),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        super.init(window: window)
        window.title = main ? "Messenger Lite" : "Messenger Lite - Call"
        window.minSize = NSSize(width: 420, height: 420)
        window.contentView = webView
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        if main {
            window.setFrameAutosaveName("MessengerLiteMain")
        }
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.configuration.preferences.isElementFullscreenEnabled = true
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let owner = appDelegate else { return nil }
        let popup = BrowserWindow(configuration: configuration, main: false, owner: owner)
        owner.windows.append(popup)
        popup.showWindow(nil)
        popup.window?.makeKeyAndOrderFront(nil)
        // WebKit performs the navigation itself, preserving window.open and the call session.
        return popup.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        if !isMain { close() }
    }

    func windowWillClose(_ notification: Notification) {
        webView.stopLoading()
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.setCameraCaptureState(.none, completionHandler: nil)
        webView.setMicrophoneCaptureState(.none, completionHandler: nil)
        appDelegate?.windows.removeAll { $0 === self }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let scheme = url.scheme?.lowercased()
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        if scheme == "about" || scheme == "blob" {
            decisionHandler(.allow)
        } else if scheme == "https" || scheme == "http" {
            if navigationAction.targetFrame?.isMainFrame != false && !isMessengerHost(url.host) {
                decisionHandler(.cancel)
                NSWorkspace.shared.open(url)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame,
              let response = navigationResponse.response as? HTTPURLResponse,
              let mimeType = response.mimeType?.lowercased(),
              mimeType.hasPrefix("image/") else {
            decisionHandler(.allow)
            return
        }
        // Opening a CDN image in the main view replaces Messenger with an unclosable image page.
        decisionHandler(.download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let safeName = URL(fileURLWithPath: suggestedFilename).lastPathComponent
        let base = URL(fileURLWithPath: safeName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: safeName).pathExtension
        var destination = downloads.appendingPathComponent(safeName)
        var index = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            let filename = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            destination = downloads.appendingPathComponent(filename)
            index += 1
        }
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {}

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let alert = NSAlert()
        alert.messageText = "Download failed"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        if let window { alert.beginSheetModal(for: window) }
    }

    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard origin.protocol == "https", isMessengerHost(origin.host),
              isMessengerHost(webView.url?.host) else {
            decisionHandler(.deny)
            return
        }
        decisionHandler(.prompt)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Message from " + frame.securityOrigin.host
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        guard let window else { completionHandler(); return }
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Confirmation from " + frame.securityOrigin.host
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        guard let window else { completionHandler(false); return }
        alert.beginSheetModal(for: window) { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let alert = NSAlert()
        alert.messageText = "The web content process stopped"
        alert.informativeText = "Reload Messenger to reconnect. An active call may have ended."
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Cancel")
        guard let window else { return }
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { webView.reload() }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard isMain, appDelegate?.selfTest == true else { return }
        webView.evaluateJavaScript("""
            const bannerHidden = getComputedStyle(document.querySelector('[role="banner"]')).display === 'none';
            const mediaAvailable = typeof RTCPeerConnection === 'function' &&
                typeof navigator.mediaDevices?.getUserMedia === 'function';
            const safariIdentified = /Version\\/[0-9.]+ Safari\\//.test(navigator.userAgent);
            window.open('about:blank', 'call-test');
            bannerHidden && mediaAvailable && safariIdentified;
            """) { [weak self] result, error in
            guard let self, let owner = self.appDelegate else { exit(1) }
            guard error == nil, result as? Bool == true, owner.windows.count == 2,
                  let popup = owner.windows.last,
                  popup.webView.configuration.websiteDataStore === webView.configuration.websiteDataStore else {
                print("FAIL: popup creation or shared session")
                exit(1)
            }
            popup.close()
            guard owner.windows.count == 1 else {
                print("FAIL: popup cleanup")
                exit(1)
            }
            print("PASS: Safari identification, WebRTC/media APIs, Facebook banner hidden, window.open, shared session, popup cleanup")
            exit(0)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let selfTest = CommandLine.arguments.contains("--self-test")
    var windows: [BrowserWindow] = []
    var activeBrowser: BrowserWindow? {
        windows.first { $0.window === NSApp.keyWindow } ?? windows.first
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMenu()
        openMainWindow()
        NSApp.activate(ignoringOtherApps: true)
        if selfTest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                print("FAIL: self-test timed out")
                exit(1)
            }
        }
    }

    @objc func openMainWindow() {
        if let existing = windows.first(where: { $0.isMain }) {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = selfTest ? .nonPersistent() : .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = selfTest
        let focusedMessenger = WKUserScript(source: """
            (() => {
                const host = location.hostname.toLowerCase();
                if (host !== 'facebook.com' && !host.endsWith('.facebook.com')) return;
                const style = document.createElement('style');
                style.textContent = `
                    html[data-messenger-lite] { --header-height: 0px !important; }
                    html[data-messenger-lite] [role="banner"] { display: none !important; }
                    html[data-messenger-lite] [aria-label*="conversation details" i],
                    html[data-messenger-lite] [aria-label*="chat details" i],
                    html[data-messenger-lite] [aria-label*="thread details" i],
                    html[data-messenger-lite] [aria-label*="szczegóły rozmowy" i],
                    html[data-messenger-lite] [aria-label*="szczegóły konwersacji" i],
                    html[data-messenger-lite] [aria-label*="szczegóły czatu" i] {
                        display: none !important;
                    }
                `;
                function update() {
                    const root = document.documentElement;
                    if (!root) return;
                    const focused = /^\\/messages(?:\\/|$)/.test(location.pathname);
                    root.toggleAttribute('data-messenger-lite', focused);
                    if (!style.isConnected) root.appendChild(style);
                }
                // Facebook changes conversations without loading a new document.
                new MutationObserver(update).observe(document, { childList: true, subtree: true });
                addEventListener('popstate', update);
                for (const name of ['pushState', 'replaceState']) {
                    const original = history[name];
                    history[name] = function(...args) {
                        const result = original.apply(this, args);
                        update();
                        return result;
                    };
                }
                update();
            })();
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(focusedMessenger)
        let browser = BrowserWindow(configuration: configuration, main: true, owner: self)
        windows.append(browser)
        browser.showWindow(nil)
        if selfTest {
            browser.webView.loadHTMLString("<!doctype html><title>Popup self-test</title><div role='banner'>Facebook</div><main>Chat</main>",
                                           baseURL: URL(string: "https://www.facebook.com/messages/"))
        } else {
            browser.webView.load(URLRequest(url: URL(string: "https://www.facebook.com/messages/")!))
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
    }

    @objc func reload() { activeBrowser?.webView.reload() }
    @objc func back() { activeBrowser?.webView.goBack() }
    @objc func zoomIn() {
        guard let view = activeBrowser?.webView else { return }
        view.pageZoom = min(2, view.pageZoom + 0.1)
    }
    @objc func zoomOut() {
        guard let view = activeBrowser?.webView else { return }
        view.pageZoom = max(0.5, view.pageZoom - 0.1)
    }
    @objc func resetZoom() { activeBrowser?.webView.pageZoom = 1 }

    func makeMenu() {
        let bar = NSMenu()
        NSApp.mainMenu = bar
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem()
            bar.addItem(item)
            let menu = NSMenu(title: title)
            item.submenu = menu
            return menu
        }
        func add(_ menu: NSMenu, _ title: String, _ action: Selector,
                 _ key: String, target: AnyObject? = nil) {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.target = target
        }
        let app = submenu("Messenger Lite")
        add(app, "About Messenger Lite", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), "")
        app.addItem(.separator())
        add(app, "Hide Messenger Lite", #selector(NSApplication.hide(_:)), "h")
        add(app, "Quit Messenger Lite", #selector(NSApplication.terminate(_:)), "q")
        let file = submenu("File")
        add(file, "Open Messenger", #selector(openMainWindow), "n", target: self)
        add(file, "Close Window", #selector(NSWindow.performClose(_:)), "w")
        let edit = submenu("Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"),
                                        ("Copy", "copy:", "c"), ("Paste", "paste:", "v"),
                                        ("Select All", "selectAll:", "a")] {
            add(edit, title, NSSelectorFromString(selector), key)
        }
        let view = submenu("View")
        add(view, "Reload", #selector(reload), "r", target: self)
        add(view, "Close Image Preview", #selector(back), "\u{1b}", target: self)
        add(view, "Zoom In", #selector(zoomIn), "=", target: self)
        add(view, "Zoom Out", #selector(zoomOut), "-", target: self)
        add(view, "Actual Size", #selector(resetZoom), "0", target: self)
        let window = submenu("Window")
        add(window, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        NSApp.windowsMenu = window
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    withExtendedLifetime(delegate) {
        application.run()
    }
}
