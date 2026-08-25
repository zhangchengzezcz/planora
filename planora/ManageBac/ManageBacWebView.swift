import SwiftUI
import WebKit

struct ManageBacWebView: UIViewRepresentable {
    let session: ManageBacWebSession

    func makeUIView(context: Context) -> WKWebView {
        session.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
