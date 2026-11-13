import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/navigation/browser_app_link.dart';

Uri _handoff(String url) =>
    Uri.parse('kaizenteams://open?url=${Uri.encodeComponent(url)}');

void main() {
  test(
    'restores trusted HTTPS destinations without changing tokens or fragments',
    () {
      for (final host in [
        'app.kaizenteams.ai',
        'dev.kaizenteams.ai',
        'api.kaizenteams.ai',
      ]) {
        for (final path in [
          '/shared/paygrades/Public-ID_123?source=share',
          '/shared/seat-profile/id',
          '/shared/lms/id',
          '/verify_token/Header.Payload.Signature',
          '/organization/Org-ID/ltc/assigned-track/Track-ID',
          '/auth/password-reset/confirm?token=A%2BB%26C',
          '/auth/google/callback?code=A%2BB&state=State-123#fragment',
        ]) {
          final url = 'https://$host$path';
          expect(resolveBrowserAppLink(_handoff(url)).toString(), url);
        }
      }
    },
  );

  test(
    'ordinary HTTPS and existing custom-scheme links pass through unchanged',
    () {
      for (final url in [
        'https://dev.kaizenteams.ai/shared/paygrades/id',
        'kaizenteams://onboarding/password?image=profile',
        'kaizenteams://setting',
        'kaizenteams://settings',
      ]) {
        final uri = Uri.parse(url);
        expect(resolveBrowserAppLink(uri), same(uri));
      }
    },
  );

  test('rejects untrusted or malformed destinations and nested handoffs', () {
    for (final url in [
      '',
      '/shared/paygrades/id',
      'http://app.kaizenteams.ai/shared/paygrades/id',
      'https://example.com/shared/paygrades/id',
      'https://app.kaizenteams.ai.example.com/shared/paygrades/id',
      'https://user@app.kaizenteams.ai/shared/paygrades/id',
      'https://app.kaizenteams.ai:444/shared/paygrades/id',
      'https://[invalid',
      'kaizenteams://onboarding',
      _handoff('https://app.kaizenteams.ai/shared/paygrades/id').toString(),
    ]) {
      expect(resolveBrowserAppLink(_handoff(url)), isNull, reason: url);
    }
  });

  test('rejects missing, duplicate and ambiguous wrapper destinations', () {
    final handoff = _handoff('https://app.kaizenteams.ai/shared/paygrades/id');
    for (final uri in [
      Uri.parse('kaizenteams://open'),
      Uri.parse('$handoff&url=https%3A%2F%2Fdev.kaizenteams.ai'),
      handoff.replace(path: '/onboarding'),
      handoff.replace(userInfo: 'user'),
      handoff.replace(port: 443),
      handoff.replace(fragment: 'url=https://example.com'),
    ]) {
      expect(resolveBrowserAppLink(uri), isNull);
    }
  });
}
