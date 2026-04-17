import 'package:flutter/material.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/models/user.dart';
import 'package:squad/screens/player_profile_screen.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/services/api_service.dart';
class AllPlayersScreen extends StatefulWidget {
  final List<User> players;

  const AllPlayersScreen({super.key, required this.players});

  @override
  State<AllPlayersScreen> createState() => _AllPlayersScreenState();
}

class _AllPlayersScreenState extends State<AllPlayersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _filteredPlayers = [];
  bool _isSearching = false;
  String? _expandedFilter; // 'position' | 'country' | 'age' | null

  List<User> _allPlayers = [];
  bool _isLoading = true;

  String? _selectedPosition;
  String? _selectedCountry;
  String? _selectedAgeRange;

  // null = not chosen yet (no selection)
// _ALL = user explicitly chose "All"
  static const String _ALL = '__ALL__';

  late List<String> _positions = [];
  late List<String> _countries = [];
  final List<String> _ageRanges = ['-15', '15~20', '+20']; // ✅ same as Home

  final ExpansionTileController _posCtrl = ExpansionTileController();
  final ExpansionTileController _countryCtrl = ExpansionTileController();
  final ExpansionTileController _ageCtrl = ExpansionTileController();

  String? _positionLabel(AppLocalizations? loc) {
    if (_selectedPosition == null) return null; // not chosen
    if (_selectedPosition == _ALL) return loc?.tr('all') ?? 'All';
    return _translatePosition(_selectedPosition, loc);
  }

  String? _countryLabel(AppLocalizations? loc) {
    if (_selectedCountry == null) return null;
    if (_selectedCountry == _ALL) return loc?.tr('all') ?? 'All';
    return _translateCountry(_selectedCountry, loc);
  }

  String? _ageLabel(AppLocalizations? loc) {
    if (_selectedAgeRange == null) return null;
    if (_selectedAgeRange == _ALL) return loc?.tr('all') ?? 'All';
    return _selectedAgeRange;
  }

  Future<void> _loadAllPlayers() async {
    try {
      final token = await AuthService.getToken();

      final players = await ApiService.getPlayers(
        token: token!,
        sort: 'new',
        limit: 100000, // or any big number
      );

      setState(() {
        _allPlayers = players.where((u) => u.type == 'player').toList();
        _filteredPlayers = _allPlayers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading all players: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _filteredPlayers = widget.players;
    _searchController.addListener(_onSearchChanged);
    _initializeFilterOptions();
    _loadAllPlayers();
  }

  void _initializeFilterOptions() {
    // Extract unique positions and countries from players
    _positions = widget.players
        .where((p) => p.position != null && p.position!.isNotEmpty)
        .map((p) => p.position!)
        .toSet()
        .toList();

    _countries = widget.players
        .where((p) => p.country != null && p.country!.isNotEmpty)
        .map((p) => p.country!)
        .toSet()
        .toList();

    _positions.sort();
    _countries.sort();
  }


  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // POSITION TRANSLATION HELPER
  String _translatePosition(String? position, AppLocalizations? loc) {
    if (position == null || position.isEmpty) return '';

    final positionMap = {
      'Goalkeeper': loc?.tr('goalkeeper') ?? 'Goalkeeper',
      'Right Back': loc?.tr('right_back') ?? 'Right Back',
      'Left Back': loc?.tr('left_back') ?? 'Left Back',
      'Center Back': loc?.tr('center_back') ?? 'Center Back',
      'Defensive Midfielder': loc?.tr('defensive_midfielder') ?? 'Defensive Midfielder',
      'Central Midfielder': loc?.tr('central_midfielder') ?? 'Central Midfielder',
      'Attacking Midfielder': loc?.tr('attacking_midfielder') ?? 'Attacking Midfielder',
      'Right Winger': loc?.tr('right_winger') ?? 'Right Winger',
      'Left Winger': loc?.tr('left_winger') ?? 'Left Winger',
      'Striker': loc?.tr('striker') ?? 'Striker',
      'Forward': loc?.tr('forward') ?? 'Forward',
      'Defender': loc?.tr('defender') ?? 'Defender',
      'Midfielder': loc?.tr('midfielder') ?? 'Midfielder',
      'Winger': loc?.tr('winger') ?? 'Winger',
    };

    return positionMap[position] ?? position;
  }

  // COUNTRY TRANSLATION HELPER
  String _translateCountry(String? country, AppLocalizations? loc) {
    if (country == null || country.isEmpty) return '';

    final countryMap = {
      'Egypt': loc?.tr('egypt') ?? 'Egypt',
      'Saudi Arabia': loc?.tr('saudi_arabia') ?? 'Saudi Arabia',
      'UAE': loc?.tr('uae') ?? 'UAE',
      'Qatar': loc?.tr('qatar') ?? 'Qatar',
      'Kuwait': loc?.tr('kuwait') ?? 'Kuwait',
      'Bahrain': loc?.tr('bahrain') ?? 'Bahrain',
      'Oman': loc?.tr('oman') ?? 'Oman',
      'Jordan': loc?.tr('jordan') ?? 'Jordan',
      'Lebanon': loc?.tr('lebanon') ?? 'Lebanon',
      'Syria': loc?.tr('syria') ?? 'Syria',
      'Iraq': loc?.tr('iraq') ?? 'Iraq',
      'Palestine': loc?.tr('palestine') ?? 'Palestine',
      'Morocco': loc?.tr('morocco') ?? 'Morocco',
      'Algeria': loc?.tr('algeria') ?? 'Algeria',
      'Tunisia': loc?.tr('tunisia') ?? 'Tunisia',
    };

    return countryMap[country] ?? country;
  }

  int _getPlayerAge(User player) {
    if (player.birthDate == null) return 0;
    try {
      final birthDate = DateTime.parse(player.birthDate!);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  bool _matchesAgeRange(int age) {
    if (_selectedAgeRange == null || _selectedAgeRange == _ALL) return true;

    switch (_selectedAgeRange) {
      case '-15':
        return age > 0 && age < 15;
      case '15~20':
        return age >= 15 && age <= 20;
      case '+20':
        return age > 20;
      default:
        return true;
    }
  }



  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredPlayers = widget.players.where((p) {
        // search match (optional)
        final nameMatch = p.name.toLowerCase().contains(query);
        final posMatch = (p.position ?? '').toLowerCase().contains(query);
        final countryMatch = (p.country ?? '').toLowerCase().contains(query);
        final searchOk = query.isEmpty || nameMatch || posMatch || countryMatch;

        final positionOk =
            _selectedPosition == null ||
                _selectedPosition == _ALL ||
                (p.position ?? '').trim().toLowerCase() ==
                    _selectedPosition!.trim().toLowerCase();

        final countryOk =
            _selectedCountry == null ||
                _selectedCountry == _ALL ||
                (p.country ?? '').trim().toLowerCase() ==
                    _selectedCountry!.trim().toLowerCase();

        final age = _getPlayerAge(p);
        final ageOk = _matchesAgeRange(age);

        return searchOk && positionOk && countryOk && ageOk;
      }).toList();

      _isSearching =
          query.isNotEmpty ||
              (_selectedPosition != null && _selectedPosition != _ALL) ||
              (_selectedCountry != null && _selectedCountry != _ALL) ||
              (_selectedAgeRange != null && _selectedAgeRange != _ALL);
    });
  }

  void _openAllPlayersFiltersSheet() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.60,
              minChildSize: 0.35,
              maxChildSize: 0.90,
              builder: (context, scrollController) {
                return Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                loc?.tr('filters') ?? 'Filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedPosition = null;
                                  _selectedCountry = null;
                                  _selectedAgeRange = null;
                                  _searchController.clear();
                                });
                                _applyFilters();
                                setModalState(() {});
                              },
                              child: Text(loc?.tr('clear') ?? 'Clear'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ===== Position =====
                        ExpansionTile(
                          controller: _posCtrl,
                          tilePadding: EdgeInsets.zero,
                          onExpansionChanged: (expanded) {
                            if (expanded) {
                              _countryCtrl.collapse();
                              _ageCtrl.collapse();
                              setModalState(() => _expandedFilter = 'position');
                            } else {
                              if (_expandedFilter == 'position') {
                                setModalState(() => _expandedFilter = null);
                              }
                            }
                          },
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc?.tr('position') ?? 'Position'),
                              if (_selectedPosition != null)
                                _selectedLine(
                                  isDark: isDark,
                                  text: _positionLabel(loc) ?? '',
                                  onClear: () {
                                    setState(() => _selectedPosition = null);
                                    _applyFilters();
                                    setModalState(() {});
                                  },
                                ),
                            ],
                          ),
                          children: [
                            _FilterOptionTile(
                              title: loc?.tr('all') ?? 'All',
                              selected: _selectedPosition == _ALL,
                              onTap: () {
                                setState(() => _selectedPosition = _ALL);
                                _applyFilters();
                                _posCtrl.collapse();
                                setModalState(() => _expandedFilter = null);
                              },
                            ),
                            ..._positions.map((p) => _FilterOptionTile(
                              title: _translatePosition(p, loc),
                              selected: _selectedPosition == p,
                              onTap: () {
                                setState(() => _selectedPosition = p);
                                _applyFilters();
                                _posCtrl.collapse();
                                setModalState(() => _expandedFilter = null);
                              },
                            )),
                          ],
                        ),

                        const Divider(),

                        // ===== Country =====
                        ExpansionTile(
                          controller: _countryCtrl,
                          tilePadding: EdgeInsets.zero,
                          onExpansionChanged: (expanded) {
                            if (expanded) {
                              _posCtrl.collapse();
                              _ageCtrl.collapse();
                              setModalState(() => _expandedFilter = 'country');
                            } else {
                              if (_expandedFilter == 'country') {
                                setModalState(() => _expandedFilter = null);
                              }
                            }
                          },
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc?.tr('country') ?? 'Country'),
                              if (_selectedCountry != null)
                                _selectedLine(
                                  isDark: isDark,
                                  text: _countryLabel(loc) ?? '',
                                  onClear: () {
                                    setState(() => _selectedCountry = null);
                                    _applyFilters();
                                    setModalState(() {});
                                  },
                                ),
                            ],
                          ),
                          children: [
                            _FilterOptionTile(
                              title: loc?.tr('all') ?? 'All',
                              selected: _selectedCountry == _ALL,
                              onTap: () {
                                setState(() => _selectedCountry = _ALL);
                                _applyFilters();
                                _countryCtrl.collapse();
                                setModalState(() => _expandedFilter = null);
                              },
                            ),
                            ..._countries.map((c) => _FilterOptionTile(
                              title: _translateCountry(c, loc),
                              selected: _selectedCountry == c,
                              onTap: () {
                                setState(() => _selectedCountry = c);
                                _applyFilters();
                                _countryCtrl.collapse();
                                setModalState(() => _expandedFilter = null);
                              },
                            )),
                          ],
                        ),

                        const Divider(),

                        // ===== Age =====
                        ExpansionTile(
                          controller: _ageCtrl,
                          tilePadding: EdgeInsets.zero,
                          onExpansionChanged: (expanded) {
                            if (expanded) {
                              _posCtrl.collapse();
                              _countryCtrl.collapse();
                              setModalState(() => _expandedFilter = 'age');
                            } else {
                              if (_expandedFilter == 'age') {
                                setModalState(() => _expandedFilter = null);
                              }
                            }
                          },
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc?.tr('age') ?? 'Age'),
                              if (_selectedAgeRange != null)
                                _selectedLine(
                                  isDark: isDark,
                                  text: _ageLabel(loc) ?? '',
                                  onClear: () {
                                    setState(() => _selectedAgeRange = null);
                                    _applyFilters();
                                    setModalState(() {});
                                  },
                                ),
                            ],
                          ),
                          children: [
                            _FilterOptionTile(
                              title: loc?.tr('all') ?? 'All',
                              selected: _selectedAgeRange == _ALL,
                              onTap: () {
                                setState(() => _selectedAgeRange = _ALL);
                                _applyFilters();
                                _ageCtrl.collapse();
                                setModalState(() => _expandedFilter = null);
                              },
                            ),
                            ..._ageRanges.map((a) => _FilterOptionTile(
                              title: a,
                              selected: _selectedAgeRange == a,
                              onTap: () {
                                setState(() => _selectedAgeRange = a);
                                _applyFilters();
                                _ageCtrl.collapse();
                                setModalState(() => _expandedFilter = null);
                              },
                            )),
                          ],
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _applyFilters();
                              Navigator.pop(sheetContext);
                            },
                            child: Text(loc?.tr('done') ?? 'Done'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedPosition = null;
      _selectedCountry = null;
      _selectedAgeRange = null;
      _filteredPlayers = _allPlayers;
      _isSearching = false;
    });
    _applyFilters(); // ✅ ensures list refresh

  }

  String _getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'http://187.124.37.68:3000$url';
  }

  Widget _selectedLine({
    required bool isDark,
    required String text,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc?.tr('all_players') ?? 'All Players',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.cardDark : Colors.white,
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: loc?.tr('search_for_player') ?? 'Search for player...',
                hintStyle: TextStyle(color: AppColors.grey),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _isSearching
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),

          // Filter Toggle Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredPlayers.length} ${loc?.tr('player_count') ?? 'players'}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.grey,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: [
                    if (_isSearching)
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.clear, size: 18),
                        label: Text(loc?.tr('clear') ?? 'Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color: _isSearching ? AppColors.primary : AppColors.grey,
                      ),
                      onPressed: _openAllPlayersFiltersSheet,
                    ),

                  ],
                ),
              ],
            ),
          ),

/*          // Filters Section
          // Filters Section (VERTICAL)
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              color: isDark ? AppColors.cardDark : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // POSITION
                  Text(
                    loc?.tr('position') ?? 'Position',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(loc?.tr('all') ?? 'All'),
                        selected: _selectedPosition == null,
                        onSelected: (_) {
                          setState(() => _selectedPosition = null);
                          _applyFilters();
                        },
                      ),
                      ..._positions.map((position) => FilterChip(
                        label: Text(_translatePosition(position, loc)),
                        selected: _selectedPosition == position,
                        onSelected: (_) {
                          setState(() => _selectedPosition = position);
                          _applyFilters();
                        },
                      )),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // COUNTRY
                  Text(
                    loc?.tr('country') ?? 'Country',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(loc?.tr('all') ?? 'All'),
                        selected: _selectedCountry == null,
                        onSelected: (_) {
                          setState(() => _selectedCountry = null);
                          _applyFilters();
                        },
                      ),
                      ..._countries.map((country) => FilterChip(
                        label: Text(_translateCountry(country, loc)),
                        selected: _selectedCountry == country,
                        onSelected: (_) {
                          setState(() => _selectedCountry = country);
                          _applyFilters();
                        },
                      )),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // AGE
                  Text(
                    loc?.tr('age') ?? 'Age',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(loc?.tr('all') ?? 'All'),
                        selected: _selectedAgeRange == null,
                        onSelected: (_) {
                          setState(() => _selectedAgeRange = null);
                          _applyFilters();
                        },
                      ),
                      ..._ageRanges.map((ageRange) => FilterChip(
                        label: Text(ageRange),
                        selected: _selectedAgeRange == ageRange,
                        onSelected: (_) {
                          setState(() => _selectedAgeRange = ageRange);
                          _applyFilters();
                        },
                      )),
                    ],
                  ),
                ],
              ),
            ),*/


          // Players List
          Expanded(
            child: _filteredPlayers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: isDark ? Colors.white30 : AppColors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc?.tr('no_players_found') ?? 'No players found',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredPlayers.length,
              itemBuilder: (context, index) {
                final player = _filteredPlayers[index];
                final loc = AppLocalizations.of(context);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: player.profilePhotoUrl != null
                          ? NetworkImage(_getFullImageUrl(player.profilePhotoUrl))
                          : null,
                      child: player.profilePhotoUrl == null
                          ? Text(
                        player.name.isNotEmpty ? player.name[0].toUpperCase() : 'P',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                        ),
                      )
                          : null,
                    ),
                    title: Text(
                      player.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (player.position != null)
                          Row(
                            children: [
                              Icon(
                                Icons.sports_soccer,
                                size: 14,
                                color: isDark ? Colors.white60 : AppColors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _translatePosition(player.position, loc),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        if (player.country != null)
                          Row(
                            children: [
                              Icon(
                                Icons.flag,
                                size: 14,
                                color: isDark ? Colors.white60 : AppColors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _translateCountry(player.country, loc),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: isDark ? Colors.white60 : AppColors.grey,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerProfileScreen(userId: player.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class _FilterOptionTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _FilterOptionTile({
    Key? key,
    required this.title,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        onTap();
        FocusScope.of(context).unfocus();
      },
      child: SizedBox(
        width: double.infinity,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(isDark ? 0.25 : 0.12)
                : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primary, size: 18)
              else
                Icon(
                  Icons.circle_outlined,
                  color: isDark ? Colors.white30 : Colors.black26,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
