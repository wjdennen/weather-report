import SwiftUI
import WebKit

// Escape hatch for when the native screen can't load weather: the same site the web app is served from.
struct WebFallbackView: View {
    let retryNative: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: retryNative) {
                    Label("Try native view again", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(hex: "0f1418"))
            WebView(url: URL(string: "https://weather.dennen.dev")!)
        }
        .background(Color(hex: "0f1418").ignoresSafeArea())
        .foregroundStyle(.white)
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
