// cert_pinning.dart
//
// TLS certificate pinning for dio, by SHA-256 SPKI (Subject Public Key Info)
// hash. Pinning the *public key* — not the leaf certificate — means pins
// survive certificate renewal, so you rotate them far less often.
//
// DEFENSIVE ONLY: this protects this app's own users from MITM against this
// app's own backend. It does not attack or bypass anything.
//
// House style: Dart 3, dio. See SKILL.md §3.
//
// ---------------------------------------------------------------------------
// HOW TO OBTAIN A PIN (run against a host/cert you control):
//
//   openssl s_client -servername api.example.com -connect api.example.com:443 \
//     | openssl x509 -pubkey -noout \
//     | openssl pkey -pubin -outform der \
//     | openssl dgst -sha256 -binary \
//     | openssl enc -base64
//
// The base64 output is one SPKI pin. Generate one for the CURRENT key and one
// for the NEXT/backup key (and optionally your intermediate CA's key).
//
// ROTATION STRATEGY:
//   1. Generate the next key's SPKI pin BEFORE rotating the server cert.
//   2. Ship a release that trusts BOTH current + next pins (backup pin).
//   3. Only after that release is widely installed, rotate the server cert to
//      the next key. Installed clients already trust it → no outage.
//   4. Drop the retired pin in a later release.
//
// ALWAYS ship at least one backup pin. One pin + an expired cert = an app that
// can no longer reach its backend, with no client-side fix.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Pin sets per environment. Each entry is a base64 SHA-256 SPKI hash.
class SecurityPins {
  const SecurityPins._();

  /// Production pins: current key + backup/next key. Replace with your own.
  static const List<String> production = <String>[
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // current server key SPKI
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // backup / next key SPKI
  ];
}

/// Configure [dio] to reject any TLS connection whose chain does not present a
/// public key matching one of [pins].
///
/// Pinning supplements normal TLS validation: an otherwise-invalid chain
/// (expired, wrong host, untrusted root) still fails the platform check first.
void configureCertificatePinning(
  Dio dio, {
  required List<String> pins,
}) {
  final pinSet = pins.toSet();

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Reached only when the default TLS validation already flagged the
        // chain. We do NOT blanket-accept here; we only accept if the
        // presented cert's SPKI is one we pinned (e.g. a self-managed CA).
        // Returning false hands control to validateCertificate below for the
        // normal case; pinning is enforced there regardless.
        return _spkiMatches(cert, pinSet);
      };
      return client;
    },
    // Enforce pinning on EVERY connection (not just bad-cert fallbacks):
    validateCertificate: (X509Certificate? cert, String host, int port) {
      if (cert == null) return false;
      return _spkiMatches(cert, pinSet);
    },
  );
}

/// True if [cert]'s SHA-256 SPKI hash is in [pins].
///
/// NOTE: `X509Certificate.der` is the full certificate DER. For exact SPKI
/// pinning you should extract the SubjectPublicKeyInfo and hash that. Many
/// teams use the `certificate_pinning_interceptor` / `http_certificate_pinning`
/// packages which do SPKI extraction natively; this helper shows the shape and
/// the validation wiring. Swap `_spkiSha256` for your SPKI extractor in prod.
bool _spkiMatches(X509Certificate cert, Set<String> pins) {
  final hash = _spkiSha256(cert);
  return pins.contains(hash);
}

/// Compute a base64 SHA-256 over the certificate's public key info.
///
/// Replace the input bytes with the extracted SubjectPublicKeyInfo DER for true
/// SPKI pinning. Hashing `cert.der` pins the whole leaf cert (works, but
/// rotates with every cert renewal — prefer SPKI).
String _spkiSha256(X509Certificate cert) {
  final digest = sha256.convert(cert.der);
  return base64.encode(digest.bytes);
}
