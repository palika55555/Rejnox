// IP klienta pre rate limit: hlavičkám sa verí len od dôveryhodnej proxy
// (Next.js web, Cloudflare Tunnel). Ľavá časť x-forwarded-for je od klienta
// a dá sa podvrhnúť, skutočnú adresu pripisuje proxy na koniec.
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

Request _request(
  String remote, {
  String? forwardedFor,
  String? cfConnectingIp,
}) => Request(
  'POST',
  Uri.parse('http://localhost/auth/login'),
  headers: {
    'x-forwarded-for': ?forwardedFor,
    'cf-connecting-ip': ?cfConnectingIp,
  },
  context: {'shelf.io.connection_info': _Connection(remote)},
);

const _local = {'127.0.0.1'};

void main() {
  test('bez dôveryhodnej proxy sa hlavičky ignorujú', () {
    final request = _request(
      '203.0.113.7',
      forwardedFor: '1.2.3.4',
      cfConnectingIp: '1.2.3.4',
    );
    expect(clientAddress(request), '203.0.113.7');
  });

  test('od dôveryhodnej proxy platí adresa, ktorú pripísala (sprava)', () {
    // Klient podvrhol 1.2.3.4, proxy (napr. Cloudflare) pripísala skutočnú.
    final request = _request(
      '127.0.0.1',
      forwardedFor: '1.2.3.4, 198.51.100.9',
    );
    expect(clientAddress(request, trustedProxies: _local), '198.51.100.9');
  });

  test('dôveryhodná proxy bez hlavičky ostane pri svojej adrese', () {
    final request = _request('127.0.0.1', forwardedFor: ' , ');
    expect(clientAddress(request, trustedProxies: _local), '127.0.0.1');
  });

  test('cudzia adresa nemôže hlavičkou podvrhnúť IP', () {
    final request = _request('203.0.113.7', forwardedFor: '198.51.100.9');
    expect(clientAddress(request, trustedProxies: _local), '203.0.113.7');
  });

  test('nastavená hlavička (CF-Connecting-IP) má prednosť', () {
    final request = _request(
      '127.0.0.1',
      forwardedFor: '1.2.3.4, 10.0.0.5',
      cfConnectingIp: '198.51.100.9',
    );
    expect(
      clientAddress(
        request,
        trustedProxies: _local,
        ipHeader: 'cf-connecting-ip',
      ),
      '198.51.100.9',
    );
  });

  test('bez nastavenej hlavičky sa CF-Connecting-IP ignoruje', () {
    // Server nemusí byť za Cloudflare, vtedy by si ju klient podvrhol.
    final request = _request(
      '127.0.0.1',
      forwardedFor: '198.51.100.9',
      cfConnectingIp: '1.2.3.4',
    );
    expect(clientAddress(request, trustedProxies: _local), '198.51.100.9');
  });

  test('chýbajúca nastavená hlavička spadne späť na x-forwarded-for', () {
    final request = _request('127.0.0.1', forwardedFor: '198.51.100.9');
    expect(
      clientAddress(
        request,
        trustedProxies: _local,
        ipHeader: 'cf-connecting-ip',
      ),
      '198.51.100.9',
    );
  });

  test('TRUSTED_PROXIES a CLIENT_IP_HEADER sa načítajú z prostredia', () {
    final config = AppConfig.load(
      environment: {
        'DATABASE_URL': 'postgres://x@localhost/x',
        'TRUSTED_PROXIES': '127.0.0.1, ::1',
        'CLIENT_IP_HEADER': ' CF-Connecting-IP ',
      },
    );
    expect(config.trustedProxies, {'127.0.0.1', '::1'});
    expect(config.clientIpHeader, 'cf-connecting-ip');
  });

  test('bez CLIENT_IP_HEADER sa žiadna extra hlavička nepoužije', () {
    final config = AppConfig.load(
      environment: {'DATABASE_URL': 'postgres://x@localhost/x'},
    );
    expect(config.clientIpHeader, isNull);
  });
}
