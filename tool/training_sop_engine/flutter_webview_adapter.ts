// Built alongside the pinned upstream adapter in src/adapters/.
import { WebViewAdapter as EngineWebViewAdapter } from './webview';

export class WebViewAdapter extends EngineWebViewAdapter {
  override send(message: Parameters<EngineWebViewAdapter['send']>[0]): void {
    // Flutter registers TiptapBridge on both platforms. The package's synthetic
    // webkit.messageHandlers.TiptapEngine alias can disappear when WKWebView
    // refreshes its handlers, so never depend on it for editing events/replies.
    if (window.TiptapBridge) window.TiptapBridge.postMessage(JSON.stringify(message));
    else super.send(message);
  }
}
