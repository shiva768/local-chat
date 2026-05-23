// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String getUrlHash() {
  final hash = html.window.location.hash;
  return hash.startsWith('#') ? hash.substring(1) : hash;
}

void setUrlHash(String hash) {
  html.window.history.replaceState(null, '', '#$hash');
}
