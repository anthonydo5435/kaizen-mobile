/// Restores the HTTPS destination from the website's explicit "Open app" action.
/// Ordinary app links pass through unchanged; malformed wrappers are ignored.
Uri? resolveBrowserAppLink(Uri uri) {
  if (uri.scheme != 'kaizenteams' || uri.host != 'open') return uri;

  final destinations = uri.queryParametersAll['url'];
  if (uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.path.isNotEmpty ||
      uri.hasFragment ||
      destinations == null ||
      destinations.length != 1) {
    return null;
  }

  final destination = Uri.tryParse(destinations.single);
  const hosts = {
    'app.kaizenteams.ai',
    'dev.kaizenteams.ai',
    'api.kaizenteams.ai',
  };
  if (destination == null ||
      destination.scheme != 'https' ||
      !hosts.contains(destination.host) ||
      destination.port != 443 ||
      destination.userInfo.isNotEmpty) {
    return null;
  }

  return destination;
}
