class Utils {
  static String convert2vpnUrl(String origin) {
    final uri = Uri.parse(origin);
    var baseUrl = 'https://vpn.just.edu.cn/';
    var lastPath = '';
    var pathSegments = uri.pathSegments.toList();
    if (pathSegments.isNotEmpty) {
      lastPath = pathSegments.removeLast();
    }
    if (pathSegments.isEmpty) {
      baseUrl += ',DanaInfo=${uri.host}';
    } else {
      baseUrl += '${pathSegments.join("/")}/,DanaInfo=${uri.host}';
    }
    if (uri.port != 80) {
      baseUrl += ',Port=${uri.port}';
    }
    if (lastPath.isNotEmpty) {
      baseUrl += '+${lastPath}';
    }
    if (uri.query.isNotEmpty) {
      baseUrl += '?${uri.query}';
    }
    return baseUrl;
  }
}
