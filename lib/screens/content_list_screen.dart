import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../providers/auth_provider.dart';
import '../models/channel.dart';
import '../widgets/channel_grid_item.dart';

enum SortOption { defaultSort, topAdded, az, za }

class ContentListScreen extends StatefulWidget {
  final String type; // 'live', 'movie', 'series'
  final String title;

  const ContentListScreen({super.key, required this.type, required this.title});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  String _selectedCategory = 'TODOS';
  String _categorySearchQuery = '';
  String _contentSearchQuery = '';
  bool _isContentSearchVisible = false;
  SortOption _currentSort = SortOption.defaultSort;

  final TextEditingController _categorySearchController =
      TextEditingController();
  final TextEditingController _contentSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContent();
    });
  }

  @override
  void dispose() {
    _categorySearchController.dispose();
    _contentSearchController.dispose();
    super.dispose();
  }

  void _loadContent() {
    final auth = context.read<AuthProvider>();
    final provider = context.read<ChannelProvider>();
    final user = auth.currentUser;

    if (user != null) {
      if (widget.type == 'live') {
        provider.loadXtream(user.url, user.username, user.password);
      } else if (widget.type == 'movie') {
        provider.loadVod(user.url, user.username, user.password);
      } else if (widget.type == 'series') {
        provider.loadSeries(user.url, user.username, user.password);
      }
    }
  }

  List<String> _getCategories(List<Channel> channels) {
    if (channels.isEmpty) return ['TODOS', 'FAVORITOS'];
    final categories = channels.map((c) => c.category).toSet().toList();
    categories.sort((a, b) => a.compareTo(b));
    return ['TODOS', 'FAVORITOS', ...categories];
  }

  List<Channel> _getFilteredChannels(List<Channel> channels) {
    // 1. Filter
    var filtered = channels.where((channel) {
      bool matchesCategory = false;
      if (_selectedCategory == 'TODOS') {
        matchesCategory = true;
      } else if (_selectedCategory == 'FAVORITOS') {
        matchesCategory = channel.isFavorite;
      } else {
        matchesCategory = channel.category == _selectedCategory;
      }

      final matchesSearch =
          _contentSearchQuery.isEmpty ||
          channel.name.toLowerCase().contains(
            _contentSearchQuery.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();

    // 2. Sort
    switch (_currentSort) {
      case SortOption.az:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.za:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.topAdded:
        filtered = filtered.reversed.toList();
        break;
      case SortOption.defaultSort:
      default:
        break;
    }

    return filtered;
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        SortOption tempSort = _currentSort;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.sort, color: Colors.blue),
                  SizedBox(width: 12),
                  Text(
                    'Ordenar de acordo com :',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRadioTile(
                    'Padrão',
                    SortOption.defaultSort,
                    tempSort,
                    setState,
                  ),
                  _buildRadioTile(
                    'Top Adicionado',
                    SortOption.topAdded,
                    tempSort,
                    setState,
                  ),
                  _buildRadioTile('A-Z', SortOption.az, tempSort, setState),
                  _buildRadioTile('Z-A', SortOption.za, tempSort, setState),
                ],
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'FECHAR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    this.setState(() {
                      _currentSort = tempSort;
                    });
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'SALVAR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRadioTile(
    String title,
    SortOption value,
    SortOption groupValue,
    StateSetter setState,
  ) {
    return RadioListTile<SortOption>(
      title: Text(
        title,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
      activeColor: Colors.blue,
      value: value,
      groupValue: groupValue,
      contentPadding: EdgeInsets.zero,
      onChanged: (val) => setState(() => groupValue = val!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Consumer<ChannelProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null) {
              return Center(
                child: Text(
                  provider.error!,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final allCategories = _getCategories(provider.channels);

            final filteredCategories = allCategories.where((cat) {
              return _categorySearchQuery.isEmpty ||
                  cat.toLowerCase().contains(
                    _categorySearchQuery.toLowerCase(),
                  );
            }).toList();

            final displayedContent = _getFilteredChannels(provider.channels);

            return Row(
              children: [
                // Left Sidebar (Categories)
                Container(
                  width: 300,
                  color: const Color(0xFF101010),
                  child: Column(
                    children: [
                      // Header Left
                      Container(
                        height: 60,
                        color: const Color(0xFF101010),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        child: TextField(
                          controller: _categorySearchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Pesquisa em categorias',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: Colors.grey[850],
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _categorySearchQuery = value),
                        ),
                      ),

                      Expanded(
                        child: ListView.separated(
                          itemCount: filteredCategories.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: Colors.grey[800]),
                          itemBuilder: (context, index) {
                            final category = filteredCategories[index];
                            final isSelected = category == _selectedCategory;

                            int count = 0;
                            if (category == 'FAVORITOS') {
                              count = provider.channels
                                  .where((c) => c.isFavorite)
                                  .length;
                            } else if (category == 'TODOS') {
                              count = provider.channels.length;
                            } else {
                              count = provider.channels
                                  .where((c) => c.category == category)
                                  .length;
                            }

                            return Container(
                              color: isSelected
                                  ? const Color(0xFF00838F)
                                  : Colors
                                        .transparent, // Cyan 800 for selection
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 0,
                                ),
                                title: Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[300],
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                selected: isSelected,
                                onTap: () => setState(
                                  () => _selectedCategory = category,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Content (Grid)
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: Column(
                      children: [
                        // Header Right
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[800]!),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Centered Title
                              if (!_isContentSearchVisible)
                                Center(
                                  child: Text(
                                    _selectedCategory.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                              // Right Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (_isContentSearchVisible)
                                    Expanded(
                                      child: TextField(
                                        controller: _contentSearchController,
                                        autofocus: true,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Procurar ${_selectedCategory}...',
                                          hintStyle: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                          border: InputBorder.none,
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        onChanged: (value) => setState(
                                          () => _contentSearchQuery = value,
                                        ),
                                      ),
                                    ),

                                  if (!_isContentSearchVisible)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.search,
                                        size: 28,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => setState(
                                        () => _isContentSearchVisible = true,
                                      ),
                                    ),

                                  if (_isContentSearchVisible)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _contentSearchQuery = '';
                                          _contentSearchController.clear();
                                          _isContentSearchVisible = false;
                                        });
                                      },
                                    ),

                                  const SizedBox(width: 8),

                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      size: 28,
                                      color: Colors.white,
                                    ),
                                    color: Colors.grey[900],
                                    onSelected: (value) {
                                      if (value == 'refresh') {
                                        _loadContent();
                                      } else if (value == 'sort') {
                                        _showSortDialog();
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'sort',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.sort,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Ordenar',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'refresh',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.refresh,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Atualizar Lista',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Grid
                        Expanded(
                          child: displayedContent.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Nenhum conteúdo',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;
                                    double maxExtent;

                                    // Responsive Breakpoints
                                    if (width < 600) {
                                      maxExtent = 160; // Phone (3-ish columns)
                                    } else if (width < 1200) {
                                      maxExtent = 200; // Tablet (4-5 columns)
                                    } else {
                                      maxExtent =
                                          260; // TV / Desktop (Large posters)
                                    }

                                    return GridView.builder(
                                      padding: const EdgeInsets.all(16),
                                      gridDelegate:
                                          SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: maxExtent,
                                            childAspectRatio: 0.65,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                          ),
                                      itemCount: displayedContent.length,
                                      itemBuilder: (context, index) {
                                        return ChannelGridItem(
                                          channel: displayedContent[index],
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
