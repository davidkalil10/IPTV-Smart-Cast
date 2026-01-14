import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum DnsProviderType {
  system,
  cloudflare, // 1.1.1.1
  google, // 8.8.8.8
  adguard, // AdGuard
}

class DnsService {
  static const String _prefKey = 'selected_dns_provider';

  // Singleton
  static final DnsService _instance = DnsService._internal();
  factory DnsService() => _instance;
  DnsService._internal();

  DnsProviderType _currentProvider = DnsProviderType.system;
  DnsProviderType get currentProvider => _currentProvider;

  // Initialize from prefs
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _currentProvider = DnsProviderType.values.firstWhere(
        (e) => e.toString() == saved,
        orElse: () => DnsProviderType.system,
      );
    }
  }

  Future<void> setProvider(DnsProviderType provider) async {
    _currentProvider = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, provider.toString());
  }

  /// Resolves a hostname to an IP address using the selected provider.
  /// Returns the original hostname if resolution fails or if using System DNS.
  Future<String> resolve(String hostname) async {
    if (_currentProvider == DnsProviderType.system) {
      try {
        final addresses = await InternetAddress.lookup(hostname);
        if (addresses.isNotEmpty) {
          // Prefer IPv4
          final ipv4 = addresses.firstWhere(
            (a) => a.type == InternetAddressType.IPv4,
            orElse: () => addresses.first,
          );
          final ip = ipv4.address;
          print('✅ DNS (System): $hostname -> $ip');
          return ip;
        }
      } catch (e) {
        print('❌ DNS Error (System): $e');
      }
      return hostname;
    }

    try {
      String? ip;
      switch (_currentProvider) {
        case DnsProviderType.cloudflare:
          ip = await _resolveDoH(
            hostname,
            'https://cloudflare-dns.com/dns-query',
          );
          break;
        case DnsProviderType.google:
          ip = await _resolveDoH(hostname, 'https://dns.google/resolve');
          break;
        case DnsProviderType.adguard:
          ip = await _resolveDoHBinary(
            hostname,
            'https://dns.adguard.com/dns-query',
          );
          break;

        default:
          return hostname;
      }

      if (ip != null && ip.isNotEmpty) {
        print('✅ DNS ($_currentProvider): $hostname -> $ip');
        return ip;
      }
    } catch (e) {
      print('❌ DNS Error ($_currentProvider): $e');
    }

    // Fallback to original hostname (System DNS) if custom resolution fails
    return hostname;
  }

  Future<String?> _resolveDoH(String hostname, String dohUrl) async {
    try {
      // Cloudflare/Quad9 accept standard DoH format, Google usually JSON API
      // We'll use the Google JSON API format which is widely supported or standard DoH
      // Actually, standard DoH (RFC 8484) needs binary packets usually,
      // but many providers offer a JSON API for simplicity.

      // Let's use the JSON APIs for simplicity as they don't require binary packet construction

      String url;
      if (dohUrl.contains('cloudflare')) {
        url = 'https://cloudflare-dns.com/dns-query?name=$hostname&type=A';
      } else if (dohUrl.contains('google')) {
        url = 'https://dns.google/resolve?name=$hostname&type=A';
      } else if (dohUrl.contains('quad9')) {
        // Quad9 usually supports standard DoH, let's try a JSON compatible endpoint if available
        // or just fallback to Cloudflare/Google structure if they support it.
        // For safety/compatibility in this snippet, let's stick to Cloudflare/Google JSON APIs.
        // Quad9 JSON API: https://dns.quad9.net:5053/dns-query?name=example.com (DOH often different)
        // Let's skip Quad9 JSON implementation for now to avoid complexity and sticking to known working JSON APIs.
        return null;
      } else {
        return null;
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/dns-json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('Answer')) {
          final List<dynamic> answers = data['Answer'];
          for (var answer in answers) {
            // type 1 is A Record (IPv4)
            if (answer['type'] == 1) {
              return answer['data'];
            }
          }
        }
      }
    } catch (e) {
      print('DNS DoH Error: $e');
    }
    return null;
  }

  Future<String?> _resolveDoHBinary(String hostname, String dohUrl) async {
    try {
      final packet = _buildDnsQuery(hostname);
      // print('📦 DoH Request: ${packet.length} bytes to $dohUrl');

      final response = await http.post(
        Uri.parse(dohUrl),
        headers: {
          'Content-Type': 'application/dns-message',
          'Accept': 'application/dns-message',
          'User-Agent': 'IPTV_Smart_Cast/1.0',
        },
        body: packet,
      );

      if (response.statusCode == 200) {
        // print('📦 DoH Response: ${response.bodyBytes.length} bytes');
        return _parseDnsResponse(response.bodyBytes);
      } else {
        print('❌ Binary DoH Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Binary DoH Error: $e');
    }
    return null;
  }

  Uint8List _buildDnsQuery(String hostname) {
    // Basic DNS Header and Question for A Record
    final List<int> packet = [];

    // ID (random)
    final id = DateTime.now().millisecondsSinceEpoch & 0xFFFF;
    packet.addAll([id >> 8, id & 0xFF]);

    // Flags (Standard Query, Recursion Desired) 0x0100
    packet.addAll([0x01, 0x00]);

    // QDCOUNT (1)
    packet.addAll([0x00, 0x01]);
    // ANCOUNT (0)
    packet.addAll([0x00, 0x00]);
    // NSCOUNT (0)
    packet.addAll([0x00, 0x00]);
    // ARCOUNT (0)
    packet.addAll([0x00, 0x00]);

    // QNAME
    for (final part in hostname.split('.')) {
      if (part.isEmpty) continue;
      final bytes = utf8.encode(part);
      packet.add(bytes.length);
      packet.addAll(bytes);
    }
    packet.add(0x00); // Root label

    // QTYPE (A = 1)
    packet.addAll([0x00, 0x01]);
    // QCLASS (IN = 1)
    packet.addAll([0x00, 0x01]);

    return Uint8List.fromList(packet);
  }

  String? _parseDnsResponse(Uint8List response) {
    try {
      final data = ByteData.sublistView(response);

      // Skip Header (12 bytes)
      int offset = 12;

      // Skip Question Section
      // Name is variable length, ends with 0 or pointer
      while (true) {
        if (offset >= response.length) return null;
        final len = response[offset];
        if (len == 0) {
          offset++;
          break;
        } else if ((len & 0xC0) == 0xC0) {
          // Pointer, skip 2 bytes
          offset += 2;
          break;
        } else {
          offset += len + 1;
        }
      }

      // Skip QTYPE (2) and QCLASS (2)
      offset += 4;

      // Answer Section
      // We expect at least one answer
      // But we need to parse until we find an A record (Type 1)
      // Answer format: NAME (var), TYPE (2), CLASS (2), TTL (4), RDLENGTH (2), RDATA (var)

      while (offset < response.length) {
        // Check Name
        if (offset >= response.length) return null;
        final len = response[offset];
        if (len == 0) {
          offset++;
        } else if ((len & 0xC0) == 0xC0) {
          offset += 2;
        } else {
          // Just skip name logic roughly
          int tempOffset = offset;
          while (true) {
            if (tempOffset >= response.length) break;
            final l = response[tempOffset];
            if (l == 0) {
              tempOffset++;
              break;
            }
            if ((l & 0xC0) == 0xC0) {
              tempOffset += 2;
              break;
            }
            tempOffset += l + 1;
          }
          offset = tempOffset;
        }

        // TYPE
        if (offset + 10 > response.length) return null;
        final type = data.getUint16(offset);
        final rdLength = data.getUint16(offset + 8);

        offset += 10;

        if (type == 1 && rdLength == 4) {
          // Found A Record
          if (offset + 4 > response.length) return null;
          final ip =
              '${response[offset]}.${response[offset + 1]}.${response[offset + 2]}.${response[offset + 3]}';
          return ip;
        } else {
          // Skip RDATA
          offset += rdLength;
        }
      }
    } catch (e) {
      print('DNS Parse Error: $e');
    }
    return null;
  }
}
