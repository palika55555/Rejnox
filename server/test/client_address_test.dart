// IP klienta pre rate limit: hlavičke x-forwarded-for sa verí len od
// dôveryhodnej proxy (webová appka v Next.js volá API zo svojho servera).
import 'dart:io';

import 'package:rejnox_server/src/config.dart';
import 'package:rejnox_server/src/http/middleware.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _Connection implements HttpConnectionInfo {
  _Connection(String address) : remoteAddress = InternetAddress(address);

  @override
  final InternetAddress remoteAddress;

  @override
  int get localPort => 8080;

  @override
  int get remotePort => 50000;
}

Request _request(String remote, {String? forwardedFor}) => Request(
  'POST',
  Uri.parse('http://localhost/auth/login'),
  headers: {'x-forwarded-for': ?forwardedFor},
  context: {'shelf.io.connection_info': _Connection(remote)},
);

void main() {
  test('bez dôveryhodnej proxy sa hlavička ignoruje', () {
    final request = _request('203.0.113.7', forwardedFor: '1.2.3.4');
    expect(clientAddress(request), '203.0.113.7');
  });

  test('od dôveryhodnej proxy sa použije prvá adresa z hlavičky', () {
    final request = _request(
      '127.0.0.1',
      forwardedFor: '198.51.100.9, 10.0.0.1',
    );
    expect(
      clientAddress(request, trustedProxies: {'127.0.0.1'}),
      '198.51.100.9',
    );
  });

  test('dôveryhodná proxy bez hlavičky ostane pri svojej adrese', () {
    final request = _request('127.0.0.1', forwardedFor: '  ');
    expect(clientAddress(request, trustedProxies: {'127.0.0.1'}), '127.0.0.1');
  });

  test('cudzia adresa nemôže hlavičkou podvrhnúť IP', () {
    final request = _request('203.0.113.7', forwardedFor: '198.51.100.9');
    expect(
      clientAddress(request, trustedProxies: {'127.0.0.1'}),
      '203.0.113.7',
    );
  });

  test('TRUSTED_PROXIES sa načíta z prostredia', () {
    final config = AppConfig.load(
      environment: {
        'DATABASE_URL': 'postgres://x@localhost/x',
        'TRUSTED_PROXIES': '127.0.0.1, ::1',
      },
    );
    expect(config.trustedProxies, {'127.0.0.1', '::1'});
  });
}
