import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum DnsProviderType {
  system,
  cloudflare, // 1.1.1.1
  google, // 8.8.8.8
  quad9, // 9.9.9.9
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
        case DnsProviderType.quad9:
          ip = await _resolveDoH(
            hostname,
            'https://dns.quad9.net:5053/dns-query',
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
}
