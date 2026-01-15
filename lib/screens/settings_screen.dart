import 'package:flutter/material.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/dns_service.dart';

import '../widgets/focusable_action_wrapper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DnsProviderType _currentProvider = DnsProviderType.system;
  bool _isPipEnabled = false; // Assuming this was intended to be added as well
  bool _hwDecoding = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await DnsService().init(); // Initialize DNS service first
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentProvider = DnsProviderType.values.firstWhere(
        (e) => e.toString() == prefs.getString('selected_dns_provider'),
        orElse: () => DnsProviderType.system,
      );
      _hwDecoding = prefs.getBool('enable_hw_acceleration') ?? true;
      // _isPipEnabled would also be loaded here if it were saved
    });
    // Check PiP availability (existing logic, if any, would go here)
  }

  Future<void> _updateProvider(DnsProviderType provider) async {
    setState(() => _currentProvider = provider);
    await DnsService().setProvider(provider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'DNS alterado para ${_getProviderName(provider)}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00BFA5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  String _getProviderName(DnsProviderType type) {
    switch (type) {
      case DnsProviderType.system:
        return 'Padrão (Sistema)';
      case DnsProviderType.cloudflare:
        return 'Cloudflare (1.1.1.1)';
      case DnsProviderType.google:
        return 'Google (8.8.8.8)';
      case DnsProviderType.adguard:
        return 'AdGuard (Bloqueio de Ads)';
    }
  }

  String _getProviderDesc(DnsProviderType type) {
    switch (type) {
      case DnsProviderType.system:
        return 'Usa a configuração padrão do dispositivo.';
      case DnsProviderType.cloudflare:
        return 'Rápido e privado.';
      case DnsProviderType.google:
        return 'Confiável e estável.';
      case DnsProviderType.adguard:
        return 'Focado em segurança e sem anúncios.';
    }
  }

  IconData _getProviderIcon(DnsProviderType type) {
    switch (type) {
      case DnsProviderType.system:
        return Icons.settings_ethernet;
      case DnsProviderType.cloudflare:
        return Icons.cloud_queue;
      case DnsProviderType.google:
        return Icons.public;
      case DnsProviderType.adguard:
        return Icons.security;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF141414), // Dark Grey
                  Color(0xFF0F0F1A), // Darkish Blue
                  Color(0xFF1E1E2C), // Slightly lighter
                ],
              ),
            ),
          ),
          // Subtle Patterns
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00BFA5).withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFA5).withOpacity(0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtitle (Original Title removed, Description font increased)
                Text(
                  'Configuração de DNS',
                  style: TextStyle(
                    fontSize: 20, // Increased size for header
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // List of Cards
                ...DnsProviderType.values.map((type) => _buildDnsCard(type)),

                const SizedBox(height: 32),

                // Test DNS Button
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _testDnsResolution,
                    icon: const Icon(Icons.speed, color: Colors.white),
                    label: const Text(
                      'Testar Resolução DNS',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5).withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFF00BFA5),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Player Settings
                const Text(
                  'Player',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                FocusableActionWrapper(
                  showFocusHighlight: true,
                  onTap: () async {
                    setState(() => _hwDecoding = !_hwDecoding);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('enable_hw_acceleration', _hwDecoding);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: SwitchListTile(
                      mouseCursor: SystemMouseCursors.click,
                      title: const Text(
                        'Aceleração de Hardware',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Melhora performance em dispositivos potentes. Desative se houver travamentos na TV.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      value: _hwDecoding,
                      activeColor: const Color(0xFF00BFA5),
                      secondary: const Icon(
                        Icons.memory,
                        color: Color(0xFF00BFA5),
                      ),
                      onChanged: (value) async {
                        setState(() => _hwDecoding = value);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('enable_hw_acceleration', value);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testDnsResolution() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Determine Hostname
      String hostname = 'google.com';
      String testInfos = 'Domínio de Teste: google.com';

      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null && auth.currentUser!.url.isNotEmpty) {
        try {
          final uri = Uri.parse(auth.currentUser!.url);
          if (uri.host.isNotEmpty) {
            hostname = uri.host;
            testInfos = 'Servidor IPTV: $hostname';
          }
        } catch (e) {
          // Fallback to google.com if parsing fails
        }
      }

      final startTime = DateTime.now();
      // Resolve the target hostname
      final ip = await DnsService().resolve(hostname);
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (mounted) {
        Navigator.pop(context); // Close loading

        // Determine status
        final isSystem = _currentProvider == DnsProviderType.system;
        final isOriginal = ip == hostname;

        String message;
        Color color;
        IconData icon;

        if (isOriginal) {
          if (isSystem && ip == hostname) {
            message =
                "$testInfos\n\nUsando DNS do Sistema.\nNão foi possível obter o IP (Nativo).";
            color = Colors.grey;
            icon = Icons.info;
          } else {
            message =
                "$testInfos\n\nFalha ao resolver via DNS Personalizado.\nFallback para Sistema.";
            color = Colors.orange;
            icon = Icons.warning;
          }
        } else {
          message =
              "$testInfos\n\nSucesso! Resolvido via ${_getProviderName(_currentProvider)}.\nIP: $ip\nTempo: ${duration}ms";
          color = const Color(0xFF00BFA5);
          icon = Icons.check_circle;
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                const Text(
                  "Resultado do Teste",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro no teste: $e")));
      }
    }
  }

  Widget _buildDnsCard(DnsProviderType type) {
    final isSelected = _currentProvider == type;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF00BFA5).withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF00BFA5).withOpacity(0.5)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF00BFA5).withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _updateProvider(type),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00BFA5).withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getProviderIcon(type),
                    color: isSelected
                        ? const Color(0xFF00BFA5)
                        : Colors.white70,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getProviderName(type),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getProviderDesc(type),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(
                      Icons.check_circle,
                      color: const Color(0xFF00BFA5),
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
