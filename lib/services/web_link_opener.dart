import 'web_link_opener_stub.dart' if (dart.library.html) 'web_link_opener_web.dart' as impl;

bool openWebLinkSelf(String url) => impl.openWebLinkSelf(url);

