import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'user_selection_screen.dart';
import 'content_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh(Future<void> Function() refreshAction) async {
    setState(() => _isRefreshing = true);
    // Minumum 1 second delay to show the "working" state visually
    await Future.wait([
      refreshAction(),
      Future.delayed(const Duration(seconds: 1)),
    ]);
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChannelProvider>(context, listen: false);
      // This background check doesn't need to block UI with dimming
      provider.checkAndBackgroundRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    // final now = DateTime.now();

    if (user == null) return const LoginScreen();

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar Personalizado
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20,
              ),
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
                  // Removed unused icons as requested
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
                    icon: const Icon(Icons.switch_account, color: Colors.white),
                    onPressed: () {
                      auth.logout();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserSelectionScreen(),
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
                    Expanded(
                      child: Consumer<ChannelProvider>(
                        builder: (context, provider, _) {
                          return _buildMainCard(
                            context,
                            'TV AO VIVO',
                            Icons.tv,
                            [const Color(0xFF00C9FF), const Color(0xFF92FE9D)],
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ContentListScreen(
                                    title: 'TV ao Vivo',
                                    type: ContentType.live,
                                  ),
                                ),
                              );
                            },
                            lastUpdate: provider.lastLiveUpdate,
                            onRefresh: () async {
                              await _handleRefresh(() async {
                                await provider.loadXtream(
                                  user.url,
                                  user.username,
                                  user.password,
                                  forceRefresh: true,
                                );
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Consumer<ChannelProvider>(
                        builder: (context, provider, _) {
                          return _buildMainCard(
                            context,
                            'FILMES',
                            Icons.play_circle_fill,
                            [const Color(0xFFFF512F), const Color(0xFFDD2476)],
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ContentListScreen(
                                    title: 'Filmes',
                                    type: ContentType.movie,
                                  ),
                                ),
                              );
                            },
                            lastUpdate: provider.lastMovieUpdate,
                            onRefresh: () async {
                              await _handleRefresh(() async {
                                await provider.loadVod(
                                  user.url,
                                  user.username,
                                  user.password,
                                  forceRefresh: true,
                                );
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Consumer<ChannelProvider>(
                        builder: (context, provider, _) {
                          return _buildMainCard(
                            context,
                            'SÉRIES',
                            Icons.movie_filter,
                            [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ContentListScreen(
                                    title: 'Séries',
                                    type: ContentType.series,
                                  ),
                                ),
                              );
                            },
                            lastUpdate: provider.lastSeriesUpdate,
                            onRefresh: () async {
                              await _handleRefresh(() async {
                                await provider.loadSeries(
                                  user.url,
                                  user.username,
                                  user.password,
                                  forceRefresh: true,
                                );
                              });
                            },
                          );
                        },
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
                  Text(
                    'Conectado: ${user.name}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (_isRefreshing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Color> colors,
    VoidCallback onTap, {
    DateTime? lastUpdate,
    VoidCallback? onRefresh,
  }) {
    String timeString = "Nunca atualizado";
    if (lastUpdate != null) {
      final now = DateTime.now();
      final diff = now.difference(lastUpdate);
      if (diff.inSeconds < 60) {
        timeString = "Agora mesmo";
      } else if (diff.inMinutes < 60) {
        timeString = "${diff.inMinutes} min atrás";
      } else if (diff.inHours < 24) {
        timeString = "${diff.inHours} horas atrás";
      } else {
        timeString = "${diff.inDays} dias atrás";
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available height but clamp them
        // to prevent them from becoming huge on tablets/TVs.
        final availableHeight = constraints.maxHeight;

        final iconSize = (availableHeight * 0.25).clamp(40.0, 80.0);
        final titleSize = (availableHeight * 0.10).clamp(18.0, 32.0);
        final textSize = (availableHeight * 0.05).clamp(12.0, 16.0);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Main Click Area (Opens Content without refresh)
              Positioned.fill(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    color: Colors.transparent, // Hit test behavior
                    child: Center(
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
                  ),
                ),
              ),

              // Footer Click Area (Refreshes Content)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onRefresh, // Refresh action
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
                            'Ultima atualização: $timeString',
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
              ),
            ],
          ),
        );
      },
    );
  }
}
