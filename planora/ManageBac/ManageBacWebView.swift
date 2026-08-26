import SwiftUI
import WebKit

#if os(iOS)
struct ManageBacWebView: UIViewRepresentable {
    let session: ManageBacWebSession

    func makeUIView(context: Context) -> WKWebView {
        session.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
#elseif os(macOS)
struct ManageBacWebView: NSViewRepresentable {
    let session: ManageBacWebSession

    func makeNSView(context: Context) -> WKWebView {
        session.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) { }
}
#endif
