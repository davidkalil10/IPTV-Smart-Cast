import 'package:flutter/material.dart';
import 'dart:ui'; // For BackdropFilter
import '../services/dns_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DnsProviderType _currentProvider = DnsProviderType.system;

  @override
  void initState() {
    super.initState();
    _loadCurrentProvider();
  }

  Future<void> _loadCurrentProvider() async {
    await DnsService().init();
    setState(() => _currentProvider = DnsService().currentProvider);
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
      case DnsProviderType.quad9:
        return 'Quad9 (9.9.9.9)';
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
      case DnsProviderType.quad9:
        return 'Focado em segurança.';
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
      case DnsProviderType.quad9:
        return Icons.security;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Configurações de DNS'),
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
                  'Otimize sua conexão escolhendo um servidor DNS de alta performance.',
                  style: TextStyle(
                    fontSize: 18, // Increased from 14
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // List of Cards
                ...DnsProviderType.values.map((type) => _buildDnsCard(type)),
              ],
            ),
          ),
        ],
      ),
    );
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
