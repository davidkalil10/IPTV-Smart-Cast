import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'content_list_screen.dart';
import 'epg_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final now = DateTime.now();
    final formattedDate = DateFormat('hh:mm a MMMM dd, yyyy').format(now);

    if (user == null) return const LoginScreen();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1117), Color(0xFF161B22)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      'IPTV',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      ' SMART CAST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.search, color: Colors.white),
                    const SizedBox(width: 16),
                    const Icon(Icons.notifications, color: Colors.white),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.switch_account,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        auth.logout();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Main Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // TV AO VIVO
                      Expanded(
                        flex: 2,
                        child: _buildMainCard(
                          context,
                          'TV AO VIVO',
                          Icons.tv,
                          [const Color(0xFF00C9FF), const Color(0xFF92FE9D)],
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ContentListScreen(
                                  type: 'live',
                                  title: 'TV AO VIVO',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _buildMainCard(
                                      context,
                                      'FILMES',
                                      Icons.play_circle_fill,
                                      [
                                        const Color(0xFFFF512F),
                                        const Color(0xFFDD2476),
                                      ],
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ContentListScreen(
                                                  type: 'movie',
                                                  title: 'FILMES',
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildMainCard(
                                      context,
                                      'SÉRIES',
                                      Icons.movie_filter,
                                      [
                                        const Color(0xFF8E2DE2),
                                        const Color(0xFF4A00E0),
                                      ],
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ContentListScreen(
                                                  type: 'series',
                                                  title: 'SÉRIES',
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              flex: 1,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const EpgScreen(),
                                        ),
                                      ),
                                      child: _buildSmallCard(
                                        context,
                                        'EPG',
                                        Icons.book,
                                        Colors.green.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildSmallCard(
                                      context,
                                      'MULTI-SCREEN',
                                      Icons.grid_view,
                                      Colors.blueGrey.withOpacity(0.5),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildSmallCard(
                                      context,
                                      'ALCANÇAR',
                                      Icons.history,
                                      Colors.teal.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      'Expiração: ${user.expiryDate != null ? DateFormat('MMMM dd, yyyy').format(user.expiryDate!) : 'Ilimitado'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.shopping_cart,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Buy Premium Version',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    Text(
                      'Conectado: ${user.name}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Color> colors,
    VoidCallback onTap,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available height
        final availableHeight = constraints.maxHeight;
        final iconSize = availableHeight * 0.25; // 25% of card height
        final titleSize = availableHeight * 0.10; // 10% of card height
        final textSize = availableHeight * 0.055; // 5.5% of card height

        return GestureDetector(
          onTap: onTap,
          child: Container(
            // No fixed height here, it will take available space from Expanded/Flex in parent
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: iconSize, color: Colors.white),
                      SizedBox(height: availableHeight * 0.04),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: availableHeight * 0.1),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: availableHeight * 0.04,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ultima atualização: 1 sec ago',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: textSize,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: textSize * 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        return Container(
          // No fixed height
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: availableHeight * 0.3),
              SizedBox(height: availableHeight * 0.05),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: availableHeight * 0.15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
