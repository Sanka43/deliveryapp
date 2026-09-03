import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens a PayHere checkout by loading the backend's server-hosted,
/// self-submitting checkout page. Shared by the rides and orders checkouts —
/// both use the same PayHere merchant integration.
///
/// The checkout HTML is rendered server-side (`payHereCheckoutPage` in
/// `functions/src/payHere.ts`) and loaded here via a real `https://` URL —
/// not built inline as a `data:` URI — because PayHere authorizes checkout
/// requests per calling *domain*. Loading one shared Cloud Functions URL
/// means mnd.lk web and every mobile app hit PayHere from the same origin,
/// so a single "Domain" entry in the PayHere merchant dashboard covers all
/// of them instead of needing one per app.
///
/// On web this is a same-tab redirect via `url_launcher` instead of an
/// in-app WebView — `webview_flutter` has no Flutter Web implementation, so
/// pushing the WebView route there throws a `MissingPluginException`.
Future<bool> launchPayHereCheckout(
  BuildContext context, {
  required String checkoutPageUrl,
}) async {
  if (checkoutPageUrl.trim().isEmpty) {
    return false;
  }
  if (kIsWeb) {
    final Uri? uri = Uri.tryParse(checkoutPageUrl);
    if (uri == null) {
      return false;
    }
    return launchUrl(uri, webOnlyWindowName: '_self');
  }
  final bool? opened = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => _PayHereWebViewPage(checkoutPageUrl: checkoutPageUrl),
    ),
  );
  return opened ?? false;
}

class _PayHereWebViewPage extends StatefulWidget {
  const _PayHereWebViewPage({required this.checkoutPageUrl});

  final String checkoutPageUrl;

  @override
  State<_PayHereWebViewPage> createState() => _PayHereWebViewPageState();
}

class _PayHereWebViewPageState extends State<_PayHereWebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.checkoutPageUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (!didPop) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PayHere Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
