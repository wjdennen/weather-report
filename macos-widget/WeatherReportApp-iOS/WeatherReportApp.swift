import SwiftUI
import WebKit

// The widget extension has to ship inside an app. This app also hosts the web version
// of Weather Report in a full-screen web view.
@main
struct WeatherReportApp: App {
    var body: some Scene {
        WindowGroup {
            WebView(url: URL(string: "https://weather.dennen.dev")!)
                .ignoresSafeArea() // the page pads for the notch/home indicator itself (viewport-fit=cover)
                .background(Color(red: 0.059, green: 0.078, blue: 0.094)) // #0f1418, the page's background
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        // Keep the app's own site in the web view; open anything else (e.g. data-source credits) in Safari.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated, let target = action.request.url,
                  target.host != webView.url?.host else {
                decisionHandler(.allow)
                return
            }
            UIApplication.shared.open(target)
            decisionHandler(.cancel)
        }
    }
}
