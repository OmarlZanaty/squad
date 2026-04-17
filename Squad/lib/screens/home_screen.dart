import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:squad/utils/app_localizations.dart';  // <-- ADD THIS
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/models/user.dart';
import 'package:squad/widgets/player_card.dart';
import 'package:squad/widgets/ad_card.dart';
import 'package:squad/widgets/app_bottom_bar.dart';
import 'package:squad/widgets/app_top_bar.dart';
import 'package:squad/screens/player_profile_screen.dart';
import 'package:squad/screens/search_screen.dart';
import 'package:squad/screens/login_screen.dart';
import 'package:squad/screens/category_players_screen.dart';
import 'package:squad/screens/feed_screen.dart';
import 'package:squad/screens/settings_screen.dart';
import 'package:squad/screens/chat_screen.dart';
import 'package:squad/screens/main_screen.dart';
import 'package:squad/screens/profile_screen.dart';
import 'package:squad/screens/all_players_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad/models/home_ad.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentBottomNavIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final PageController _adPageController = PageController(viewportFraction: 0.85);
  int _currentAdPage = 0;
  Timer? _adTimer;
  List<HomeAd> _ads = [];
  bool _adsLoading = false;
  final Set<int> _viewedProfiles = {}; // ✅ ADD THIS
  // PageControllers for each player section
  final PageController _vipPageController = PageController(viewportFraction: 0.85);
  final PageController _newPageController = PageController(viewportFraction: 0.85);
  final PageController _followedPageController = PageController(viewportFraction: 0.85);
  final PageController _viewedPageController = PageController(viewportFraction: 0.85);
  int _totalPlayersCount = 0;
  List<User> _mostActionsPlayers = [];
  int _page = 1;
  final int _limit = 10;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<User> _youthPlayers = [];
  List<User> _juniorPlayers = [];
  List<User> _localProsPlayers = [];

  final ScrollController _scrollController = ScrollController();

  String? _expandedFilter; // 'position' | 'country' | 'age' | null

  void _resetPositionOnCollapse() {
    if (_selectedPosition != null) {
      setState(() => _selectedPosition = null);
      _applyHomeFilters();
    }
  }

  void _resetCountryOnCollapse() {
    if (_selectedCountry != null) {
      setState(() => _selectedCountry = null);
      _applyHomeFilters();
    }
  }



  Future<void> _savePlayersToCache(List<User> players) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = players.map((p) => p.toJson()).toList();

    await prefs.setString(
      'cached_players',
      jsonEncode(jsonList),
    );
  }

  Future<List<User>> _loadPlayersFromCache() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonString = prefs.getString('cached_players');
    if (jsonString == null) return [];

    final mostActive = await ApiService.getMostActivePlayers(
      token: _token!,
      limit: 100,
    );

    setState(() {
      _mostActionsPlayers = mostActive;
    });

    try {
      final List decoded = jsonDecode(jsonString);
      return decoded.map((e) => User.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _loadTotalPlayersCount() async {
    if (_token == null) return;

    try {
      final players = await ApiService.getPlayers(
        token: _token!,
        limit: 100000, // 🔥 big number to get all
        offset: 0,
      );

      debugPrint("🔥 PLAYERS LENGTH: ${players.length}");

      if (!mounted) return;

      setState(() {
        _totalPlayersCount = players.length;
      });

    } catch (e) {
      debugPrint("❌ total count error: $e");
    }
  }

  Future<void> _openPlayerStore() async {
    // ✅ choose link per platform
    final uri = Uri.parse(
      Theme.of(context).platform == TargetPlatform.iOS
          ? 'https://apps.apple.com/eg/app/%D9%84%D8%A7%D8%B9%D8%A8-%D8%A5%D8%B3%D9%83%D9%88%D8%A7%D8%AF/id6756811939?l=ar'
          : 'https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad_player',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('❌ Could not launch $uri');
    }
  }

  void _resetAgeOnCollapse() {
    if (_selectedAgeRange != null) {
      setState(() => _selectedAgeRange = null);
      _applyHomeFilters();
    }
  }

  Future<void> _loadAds() async {
    setState(() => _adsLoading = true);
    try {
      final list = await ApiService.getHomeAds();
      if (!mounted) return;

      // ✅ keep only first 3 slots, sorted by slot
      list.sort((a, b) => a.slot.compareTo(b.slot));
      final top3 = list.take(3).toList();

      setState(() {
        _ads = top3;
        _adsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _adsLoading = false);
    }
  }


  bool _isProfileComplete(User u) {
    bool isFilled(String? v) {
      final s = (v ?? '').trim();
      // Treat empty strings or the literal string "null" as missing
      return s.isNotEmpty && s.toLowerCase() != 'null';
    }

    final type = (u.type ?? '').trim().toLowerCase();

    // ✅ Guests and scouts: only require a profile photo, no need for country/position.
    // In this watcher app you log in as guest or scout, and those fields are not stored,
    // so requiring them would always show the “complete your profile” dialog.
    if (type == 'guest' || type == 'scout') {
      return isFilled(u.profilePhotoUrl);
    }

    // ✅ Players and other roles: require photo, country, and position
    return isFilled(u.profilePhotoUrl);
  }



  // ---------------- FILTERS (HOME) ----------------
  String? _selectedPosition;
  String? _selectedCountry;
  String? _selectedAgeRange;
// null = not chosen yet (no selection)
// _ALL = user explicitly chose "All"
  static const String _ALL = '__ALL__';

  late List<String> _positions = [];
  late List<String> _countries = [];
  final List<String> _ageRanges = ['-15', '15~20', '+20'];


  final GlobalKey _allPlayersKey = GlobalKey();
  late final loc = AppLocalizations.of(context);


  List<User> _filteredAllPlayers = [];
  bool _isFiltering = false;


  int _currentVipPage = 0;
  int _currentNewPage = 0;
  int _currentFollowedPage = 0;
  int _currentViewedPage  = 0;

  Timer? _vipTimer;
  Timer? _newTimer;
  Timer? _followedTimer;
  Timer? _viewedTimer;

  List<User> _allPlayers = [];
  List<User> _vipPlayers = [];
  List<User> _newPlayers = [];
  List<User> _mostFollowedPlayers = [];
  List<User> _mostViewedPlayers  = [];
  Map<int, int> _localProfileOpens = {}; // userId -> opens count

  bool _isLoading = false;
  String? _token;
  bool _hasSearchText = false;

  List<User> _allPlayersFull = [];


  String? _positionLabel(AppLocalizations? loc) {
    if (_selectedPosition == null) return null; // not chosen
    if (_selectedPosition == _ALL) return loc?.tr('all') ?? 'All';
    return _translatePosition(_selectedPosition, loc);
  }

  String? _countryLabel(AppLocalizations? loc) {
    if (_selectedCountry == null) return null; // not chosen
    if (_selectedCountry == _ALL) return loc?.tr('all') ?? 'All';
    return _translateCountry(_selectedCountry, loc);
  }

  String? _ageLabel(AppLocalizations? loc) {
    if (_selectedAgeRange == null) return null; // not chosen
    if (_selectedAgeRange == _ALL) return loc?.tr('all') ?? 'All';
    return _selectedAgeRange;
  }

  bool _profileCheckShown = false;

  Future<void> _checkProfileCompletion() async {
    if (_token == null || _profileCheckShown) return;

    try {
      final res = await ApiService.getProfile(_token!);

      // ✅ DEBUG: see what you actually get
      debugPrint('👤 getProfile raw response: $res');

      // ✅ Handle common shapes:
      // A) { success:true, data:{...} }
      // B) { id:..., name:... }  (direct user object)
      // C) { success:true, user:{...} }
      final dynamic rawUser =
      (res is Map && res['data'] != null) ? res['data']
          : (res is Map && res['user'] != null) ? res['user']
          : res;

      if (rawUser is! Map<String, dynamic>) {
        debugPrint('❌ getProfile: user payload is not a Map');
        return;
      }

      final me = User.fromJson(rawUser);

      debugPrint('👤 me.profilePhotoUrl="${me.profilePhotoUrl}" country="${me.country}" position="${me.position}"');

      final incomplete = !_isProfileComplete(me);

      if (!incomplete) return;

      if (!mounted) return;
      _profileCheckShown = true;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(
            loc?.tr('complete_profile_title') ?? 'Complete your profile',
          ),
          content: Text(
            loc?.tr('complete_profile_message') ??
                'Please upload a profile photo and complete your information to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc?.tr('later') ?? 'Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                _profileCheckShown = false;
                await _checkProfileCompletion();
              },
              child: Text(loc?.tr('go_to_profile') ?? 'Go to profile'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ _checkProfileCompletion error: $e');
    }
  }


  Future<void> _openPlayerProfile(User player) async {
    debugPrint('✅ Open profile id=${player.id}');

    // ✅ prevent duplicate views in same session
    if (!_viewedProfiles.contains(player.id)) {
      _viewedProfiles.add(player.id);

      try {
        if (_token != null) {
          await ApiService.incrementProfileView(
            token: _token!,
            userId: player.id,
          );
        }
      } catch (e) {
        debugPrint('incrementProfileView error: $e');
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfileScreen(userId: player.id),
      ),
    );

    if (mounted) {
      await _loadPlayers();
    }
  }

  Widget _buildSloganFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _openPlayerStore,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardDark
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign, color: AppColors.primary.withOpacity(0.9), size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'إضغط هنا لو انت لاعب',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 18,          // ✅ bigger
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary, // ✅ main color
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_ios, color: AppColors.primary.withOpacity(0.9), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _clearPosition() {
    setState(() => _selectedPosition = null);
    _applyHomeFilters();
  }

  void _clearCountry() {
    setState(() => _selectedCountry = null);
    _applyHomeFilters();
  }

  void _clearAge() {
    setState(() => _selectedAgeRange = null);
    _applyHomeFilters();
  }

  void _onScroll() {
    print("SCROLL: ${_scrollController.position.pixels}");

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      print("LOAD MORE TRIGGERED");
      _loadMorePlayers();
    }
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
            onTap: onClear, // ✅ clear without closing sheet
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

  Future<void> _loadMorePlayers() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    await Future.delayed(const Duration(milliseconds: 300)); // smooth

    final start = _allPlayers.length;
    final end = start + _limit;

    if (start >= _allPlayersFull.length) {
      _hasMore = false;
    } else {
      final nextChunk = _allPlayersFull.sublist(
        start,
        end > _allPlayersFull.length
            ? _allPlayersFull.length
            : end,
      );

      setState(() {
        _allPlayers.addAll(nextChunk);
        _filteredAllPlayers = List<User>.from(_allPlayers);
      });
    }

    setState(() => _isLoadingMore = false);
  }



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    _startAdAutoScroll();
    _startCategoryAutoScroll();

    _searchController.addListener(() {
      _hasSearchText = _searchController.text.isNotEmpty;
      _applyHomeFilters(); // already rebuilds
    });
  }


  Future<void> _openHomeFiltersSheet() async {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // snapshot current committed values (for initial draft only)
    final String? initialPos = _selectedPosition;
    final String? initialCountry = _selectedCountry;
    final String? initialAge = _selectedAgeRange;
    final String initialQuery = _searchController.text;

    final result = await showModalBottomSheet<HomeFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // draft state lives ONLY here
        String? draftPos = initialPos;
        String? draftCountry = initialCountry;
        String? draftAge = initialAge;
        String draftQuery = initialQuery;

        final posCtrl = ExpansionTileController();
        final countryCtrl = ExpansionTileController();
        final ageCtrl = ExpansionTileController();

        bool suppressResetOnCollapse = false;
        String? expandedFilter;

        Future<void> collapseOthers(String keep) async {
          suppressResetOnCollapse = true;
          if (keep != 'position') posCtrl.collapse();
          if (keep != 'country') countryCtrl.collapse();
          if (keep != 'age') ageCtrl.collapse();
          await Future.delayed(const Duration(milliseconds: 50));
          suppressResetOnCollapse = false;
        }

        void collapseSafely(ExpansionTileController ctrl) {
          suppressResetOnCollapse = true;
          ctrl.collapse();
        }

        String? draftPositionLabel() {
          if (draftPos == null) return null;
          if (draftPos == _ALL) return loc?.tr('all') ?? 'All';
          return _translatePosition(draftPos, loc);
        }

        String? draftCountryLabel() {
          if (draftCountry == null) return null;
          if (draftCountry == _ALL) return loc?.tr('all') ?? 'All';
          return _translateCountry(draftCountry, loc);
        }

        String? draftAgeLabel() {
          if (draftAge == null) return null;
          if (draftAge == _ALL) return loc?.tr('all') ?? 'All';
          return draftAge;
        }

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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),

                            // ✅ CLEAR NOW COMMITS (no more "clear but old still there")
                            TextButton(
                              onPressed: () {
                                Navigator.pop(
                                  sheetContext,
                                  const HomeFilterResult(
                                    applied: true,
                                    position: null,
                                    country: null,
                                    age: null,
                                    query: '',
                                  ),
                                );
                              },
                              child: Text(loc?.tr('clear') ?? 'Clear'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ===== Position =====
                        ExpansionTile(
                          controller: posCtrl,
                          tilePadding: EdgeInsets.zero,
                          onExpansionChanged: (expanded) async {
                            if (expanded) {
                              await collapseOthers('position');
                              setModalState(() => expandedFilter = 'position');
                            } else {
                              if (expandedFilter == 'position') {
                                setModalState(() => expandedFilter = null);
                              }
                              if (!suppressResetOnCollapse) {
                                setModalState(() => draftPos = null);
                              }
                              suppressResetOnCollapse = false;
                            }
                          },
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc?.tr('position') ?? 'Position'),
                              if (draftPos != null)
                                _selectedLine(
                                  isDark: isDark,
                                  text: draftPositionLabel() ?? '',
                                  onClear: () => setModalState(() => draftPos = null),
                                ),
                            ],
                          ),
                          children: [
                            _FilterOptionTile(
                              title: loc?.tr('all') ?? 'All',
                              selected: draftPos == _ALL,
                              onTap: () {
                                setModalState(() => draftPos = _ALL);
                                collapseSafely(posCtrl);
                                setModalState(() => expandedFilter = null);
                              },
                            ),
                            ..._positions.map(
                                  (p) => _FilterOptionTile(
                                title: _translatePosition(p, loc),
                                selected: draftPos == p,
                                onTap: () {
                                  setModalState(() => draftPos = p);
                                  collapseSafely(posCtrl);
                                  setModalState(() => expandedFilter = null);
                                },
                              ),
                            ),
                          ],
                        ),

                        const Divider(),

                        // ===== Country =====
                        ExpansionTile(
                          controller: countryCtrl,
                          tilePadding: EdgeInsets.zero,
                          onExpansionChanged: (expanded) async {
                            if (expanded) {
                              await collapseOthers('country');
                              setModalState(() => expandedFilter = 'country');
                            } else {
                              if (expandedFilter == 'country') {
                                setModalState(() => expandedFilter = null);
                              }
                              if (!suppressResetOnCollapse) {
                                setModalState(() => draftCountry = null);
                              }
                              suppressResetOnCollapse = false;
                            }
                          },
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc?.tr('country') ?? 'Country'),
                              if (draftCountry != null)
                                _selectedLine(
                                  isDark: isDark,
                                  text: draftCountryLabel() ?? '',
                                  onClear: () => setModalState(() => draftCountry = null),
                                ),
                            ],
                          ),
                          children: [
                            _FilterOptionTile(
                              title: loc?.tr('all') ?? 'All',
                              selected: draftCountry == _ALL,
                              onTap: () {
                                setModalState(() => draftCountry = _ALL);
                                collapseSafely(countryCtrl);
                                setModalState(() => expandedFilter = null);
                              },
                            ),
                            ..._countries.map(
                                  (c) => _FilterOptionTile(
                                title: _translateCountry(c, loc),
                                selected: draftCountry == c,
                                onTap: () {
                                  setModalState(() => draftCountry = c);
                                  collapseSafely(countryCtrl);
                                  setModalState(() => expandedFilter = null);
                                },
                              ),
                            ),
                          ],
                        ),

                        const Divider(),

                        // ===== Age =====
                        ExpansionTile(
                          controller: ageCtrl,
                          tilePadding: EdgeInsets.zero,
                          onExpansionChanged: (expanded) async {
                            if (expanded) {
                              await collapseOthers('age');
                              setModalState(() => expandedFilter = 'age');
                            } else {
                              if (expandedFilter == 'age') {
                                setModalState(() => expandedFilter = null);
                              }
                              if (!suppressResetOnCollapse) {
                                setModalState(() => draftAge = null);
                              }
                              suppressResetOnCollapse = false;
                            }
                          },
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc?.tr('age') ?? 'Age'),
                              if (draftAge != null)
                                _selectedLine(
                                  isDark: isDark,
                                  text: draftAgeLabel() ?? '',
                                  onClear: () => setModalState(() => draftAge = null),
                                ),
                            ],
                          ),
                          children: [
                            _FilterOptionTile(
                              title: loc?.tr('all') ?? 'All',
                              selected: draftAge == _ALL,
                              onTap: () {
                                setModalState(() => draftAge = _ALL);
                                collapseSafely(ageCtrl);
                                setModalState(() => expandedFilter = null);
                              },
                            ),
                            ..._ageRanges.map(
                                  (a) => _FilterOptionTile(
                                title: a,
                                selected: draftAge == a,
                                onTap: () {
                                  setModalState(() => draftAge = a);
                                  collapseSafely(ageCtrl);
                                  setModalState(() => expandedFilter = null);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                sheetContext,
                                HomeFilterResult(
                                  applied: true,
                                  position: draftPos,
                                  country: draftCountry,
                                  age: draftAge,
                                  query: draftQuery,
                                ),
                              );
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

    // dismissed (back / swipe) => do NOTHING (no restoring old, no messing state)
    if (result == null || result.applied != true) return;

    // ✅ commit ONCE هنا فقط
    setState(() {
      _selectedPosition = result.position;
      _selectedCountry = result.country;
      _selectedAgeRange = result.age;
      _searchController.text = result.query;
    });

    _applyHomeFilters();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          initialPlayers: List<User>.from(_filteredAllPlayers),
          initialQuery: _searchController.text.trim(),
        ),
      ),
    );
  }


  void _startAdAutoScroll() {
    _adTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final count = _ads.isNotEmpty ? _ads.length : 3;
      if (count <= 1) return;

      _currentAdPage = (_currentAdPage + 1) % count;

      if (_adPageController.hasClients) {
        _adPageController.animateToPage(
          _currentAdPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  void _startCategoryAutoScroll() {

    // ✅ prevent duplicates
    _vipTimer?.cancel();
    _newTimer?.cancel();
    _followedTimer?.cancel();
    _viewedTimer?.cancel();


    // VIP Players auto-scroll
    _vipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_vipPlayers.isNotEmpty) {
        final maxPage = (_vipPlayers.length > 10 ? 10 : _vipPlayers.length) - 1;

        if (_currentVipPage < maxPage) {
          _currentVipPage++;
        } else {
          _currentVipPage = 0;
        }
        if (_vipPageController.hasClients) {
          _vipPageController.animateToPage(
            _currentVipPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    // New Players auto-scroll
    _newTimer = Timer.periodic(const Duration(seconds: 4, milliseconds: 500), (timer) {
      if (_newPlayers.isNotEmpty) {
        final maxPage = (_newPlayers.length > 10 ? 10 : _newPlayers.length) - 1;
        if (_currentNewPage < maxPage) {
          _currentNewPage++;
        } else {
          _currentNewPage = 0;
        }
        if (_newPageController.hasClients) {
          _newPageController.animateToPage(
            _currentNewPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    // Most Followed Players auto-scroll
    _followedTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_mostFollowedPlayers.length > 1) {
        final maxPage = (_mostFollowedPlayers.length > 10 ? 10 : _mostFollowedPlayers.length) - 1;
        if (_currentFollowedPage < maxPage) {
          _currentFollowedPage++;
        } else {
          _currentFollowedPage = 0;
        }
        if (_followedPageController.hasClients) {
          _followedPageController.animateToPage(
            _currentFollowedPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });


    // Most Viewed Players auto-scroll ✅
    _viewedTimer = Timer.periodic(const Duration(seconds: 5, milliseconds: 500), (timer) {
      if (_mostViewedPlayers.isNotEmpty) {
        final maxPage = (_mostViewedPlayers.length > 10 ? 10 : _mostViewedPlayers.length) - 1;
        if (_currentViewedPage < maxPage) {
          _currentViewedPage++;
        } else {
          _currentViewedPage = 0;
        }
        if (_viewedPageController.hasClients) {
          _viewedPageController.animateToPage(
            _currentViewedPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });

  }

  Future<void> _loadData() async {
    _token = await AuthService.getToken();

    debugPrint('🔑 token exists? ${_token != null}');

    // ✅ Ads are public, load always (or only when token exists if you want)
    await _loadAds();

    if (_token != null) {
      await _checkProfileCompletion();
      _loadPlayers();

      // ✅ ADD THIS
      _loadTotalPlayersCount();

    }
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
    } catch (_) {
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

  Future<void> _incLocalProfileOpen(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'profile_open_$userId';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);

    _localProfileOpens[userId] = current + 1;
    _rebuildMostViewedPlayers();
  }

  Future<void> _loadLocalProfileOpens() async {
    final prefs = await SharedPreferences.getInstance();

    final map = <int, int>{};
    for (final p in _allPlayers) {
      map[p.id] = prefs.getInt('profile_open_${p.id}') ?? 0;
    }

    _localProfileOpens = map;
    _rebuildMostViewedPlayers();
  }

  void _rebuildMostViewedPlayers() {
    // فقط اللي اتفتح بروفايلهم مرة أو أكثر
    final list = _allPlayers
        .where((u) => (_localProfileOpens[u.id] ?? 0) > 0)
        .toList();

    // لو مفيش أي views: نخليها فاضية (مش fallback)
    if (list.isEmpty) {
      if (!mounted) return;
      setState(() => _mostViewedPlayers = []);
      return;
    }

    list.sort((a, b) {
      final av = _localProfileOpens[a.id] ?? 0;
      final bv = _localProfileOpens[b.id] ?? 0;
      return bv.compareTo(av);
    });

    if (!mounted) return;
    setState(() {
      _mostViewedPlayers = list;
    });
  }



  void _applyHomeFilters() {
    final query = _searchController.text.toLowerCase().trim();

    // 🧠 calculate first
    final filtered = _allPlayers.where((p) {
      final nameMatch = p.name.toLowerCase().contains(query);
      final posMatch = (p.position ?? '').toLowerCase().contains(query);
      final countryMatch = (p.country ?? '').toLowerCase().contains(query);

      final searchOk = query.isEmpty || nameMatch || posMatch || countryMatch;

      final positionOk =
          _selectedPosition == null ||
              _selectedPosition == _ALL ||
              (p.position ?? '').toLowerCase() ==
                  _selectedPosition!.toLowerCase();

      final countryOk =
          _selectedCountry == null ||
              _selectedCountry == _ALL ||
              (p.country ?? '').toLowerCase() ==
                  _selectedCountry!.toLowerCase();

      final ageOk = _matchesAgeRange(_getPlayerAge(p));

      return searchOk && positionOk && countryOk && ageOk;
    }).toList();

    final isFiltering =
        query.isNotEmpty ||
            (_selectedPosition != null && _selectedPosition != _ALL) ||
            (_selectedCountry != null && _selectedCountry != _ALL) ||
            (_selectedAgeRange != null && _selectedAgeRange != _ALL);

    // 🎯 one rebuild
    setState(() {
      _filteredAllPlayers = filtered;
      _isFiltering = isFiltering;
    });
  }

  void _resetHomeFilters() {
    setState(() {
      _selectedPosition = null;
      _selectedCountry = null;
      _selectedAgeRange = null;
      _searchController.clear();
      _filteredAllPlayers = List<User>.from(_allPlayers);
      _isFiltering = false;
    });
  }


  Future<void> _loadPlayers() async {
    if (_token == null) return;

    _page = 1;
    _hasMore = true;

    // ✅ 1. LOAD CACHE FIRST
    final cachedPlayers = await _loadPlayersFromCache();

    if (cachedPlayers.isNotEmpty) {
      final cachedAll =
      cachedPlayers.where((u) => u.type == 'player').toList();

      // ✅ build sections from cache
      final cachedVip =
      cachedAll.where((u) => u.isVip).toList()
        ..sort((a, b) =>
            (b.followersCount ?? 0).compareTo(a.followersCount ?? 0));

      final cachedNew = List<User>.from(cachedAll)
        ..sort((a, b) {
          final aDate = a.createdAt;
          final bDate = b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

      final cachedFollowed = cachedAll
          .where((u) => (u.followersCount ?? 0) > 0)
          .toList()
        ..sort((a, b) =>
            (b.followersCount ?? 0).compareTo(a.followersCount ?? 0));

      setState(() {
        _allPlayers = cachedAll;
        _filteredAllPlayers = List<User>.from(cachedAll);

        // ✅ IMPORTANT: restore sections
        _vipPlayers = cachedVip;
        _newPlayers = cachedNew;

        // ✅ ADD THESE
        _mostFollowedPlayers = cachedFollowed;
        _mostViewedPlayers = cachedAll.take(10).toList();

        _isLoading = false;
      });

      _applyHomeFilters();
    }

    // ✅ 2. SHOW LOADING FOR API
    if (cachedPlayers.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final players = await ApiService.getPlayers(
        token: _token!,
        sort: 'new',
        limit: 100, // 🔥 load more once
        offset: 0,
      );

      // ✅ SAVE CACHE (THIS IS YOUR QUESTION)
      await _savePlayersToCache(players);

      final allPlayers =
      players.where((u) => u.type == 'player').toList();

      _allPlayersFull = allPlayers;

      final mostViewed = await ApiService.getMostViewedPlayers(
        token: _token!,
        limit: 100,
      );

      final mostFollowed = allPlayers
          .where((u) => (u.followersCount ?? 0) > 0)
          .toList()
        ..sort((a, b) =>
            (b.followersCount ?? 0).compareTo(a.followersCount ?? 0));

      final positions = allPlayers
          .where((p) => (p.position ?? '').isNotEmpty)
          .map((p) => p.position!)
          .toSet()
          .toList();

      final countries = allPlayers
          .where((p) => (p.country ?? '').isNotEmpty)
          .map((p) => p.country!)
          .toSet()
          .toList()
        ..sort();

      final newPlayers = List<User>.from(allPlayers)
        ..sort((a, b) {
          final aDate = a.createdAt;
          final bDate = b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

      final vipPlayers = allPlayers
          .where((u) => u.isVip)
          .toList()
        ..sort((a, b) =>
            (b.followersCount ?? 0).compareTo(a.followersCount ?? 0));

      if (!mounted) return;

      setState(() {
        _allPlayers = allPlayers.take(_limit).toList();  // Keep only 10 for categories
        _filteredAllPlayers = allPlayers;  // ✅ Load ALL for filter

        _positions = positions;
        _countries = countries;


        _isFiltering = false;

        _newPlayers = newPlayers;
        _vipPlayers = vipPlayers;

        _mostViewedPlayers = mostViewed;
        _mostFollowedPlayers = mostFollowed;

        _isLoading = false;
      });

      _applyHomeFilters();

    } catch (e) {
      debugPrint('❌ Error loading players: $e');

      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }



  String _getFullImageUrl(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;

    // ApiService.baseUrl = http://187.124.37.68:3000/api
    final base = ApiService.baseUrl; // include import if needed
    final origin = base.replaceAll(RegExp(r'/api/?$'), ''); // -> http://187.124.37.68:3000

    if (u.startsWith('/')) return '$origin$u';
    return '$origin/$u';
  }

  static const List<String> _positionOrder = [
    'Goalkeeper',
    'Center Back',
    'Right Back',
    'Left Back',
    'Defensive Midfielder',
    'Central Midfielder',
    'Attacking Midfielder',
    'Right Winger',
    'Left Winger',
    'Striker',
    'Forward',
  ];


  String _norm(String s) {
    return s
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // collapse spaces
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }

  void _sortPositions() {
    _positions.sort((a, b) {
      final ai = _positionOrder.indexOf(a);
      final bi = _positionOrder.indexOf(b);

      final ar = ai == -1 ? 999 : ai;
      final br = bi == -1 ? 999 : bi;

      if (ar != br) return ar.compareTo(br);
      return a.compareTo(b); // fallback
    });

    print('POSITIONS SORTED => $_positions');
  }



  // ==================== POSITION TRANSLATION HELPER ====================
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

  // ==================== COUNTRY TRANSLATION HELPER ====================
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _vipTimer?.cancel();
      _newTimer?.cancel();
      _followedTimer?.cancel();
      _viewedTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startCategoryAutoScroll();
    }
  }

  @override
  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    _searchController.dispose();
    _adPageController.dispose();
    _adTimer?.cancel();

    _scrollController.dispose();

    // Dispose category controllers and timers
    _vipPageController.dispose();
    _newPageController.dispose();
    _followedPageController.dispose();
    _viewedPageController.dispose();
    _viewedTimer?.cancel();
    _vipTimer?.cancel();
    _newTimer?.cancel();
    _followedTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const AppTopBar(),
      body: Column(
        children: [

          const SizedBox(height: 16),

          _buildSearchBar(),

          const SizedBox(height: 16),

          // ✅ 🔥 FIXED SLOGAN (NOT SCROLLING)
          _buildSloganFooter(),

          const SizedBox(height: 16),

                // Scrollable Content
      Expanded(
        child: SafeArea(
          bottom: true,
          child: RefreshIndicator(
                    onRefresh: _loadPlayers,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [


                        SliverToBoxAdapter(child: _buildAdsSection()),

                        SliverToBoxAdapter(child: SizedBox(height: 24)),

                        // 🥇 Featured
                        SliverToBoxAdapter(
                          child: _buildPlayerSection(
                            title: '🥇${AppLocalizations.of(context)?.tr('featured_players') ?? 'Featured Players'}',
                            players: _vipPlayers.take(10).toList(),
                            allPlayers: _vipPlayers,
                            pageController: _vipPageController,
                          ),
                        ),


                        SliverToBoxAdapter(child: SizedBox(height: 24)),


                        SliverToBoxAdapter(
                          child: _buildPlayerSection(
                            title: '${AppLocalizations.of(context)?.tr('new_players') ?? 'New Players'}',
                            players: _newPlayers.take(10).toList(),
                            allPlayers: _newPlayers,
                            pageController: _newPageController,
                          ),
                        ),

                        SliverToBoxAdapter(child: SizedBox(height: 24)),

                        SliverToBoxAdapter(
                          child: _buildPlayerSection(
                            title: '${AppLocalizations.of(context)?.tr('most_viewed') ?? 'Most Viewed'}',
                            players: _mostViewedPlayers.take(10).toList(),
                            allPlayers: _mostViewedPlayers,
                            pageController: _viewedPageController,
                          ),
                        ),

                        SliverToBoxAdapter(child: SizedBox(height: 24)),

                        SliverToBoxAdapter(
                          child: _buildPlayerSection(
                            title: '${AppLocalizations.of(context)?.tr('most_actions') ?? 'Most Actions'}',
                            players: _mostActionsPlayers.take(10).toList(),
                            allPlayers: _mostActionsPlayers,
                            pageController: _viewedPageController,
                          ),
                        ),

                        SliverToBoxAdapter(child: SizedBox(height: 24)),

                        SliverToBoxAdapter(
                          child: _buildPlayerSection(
                            title: '${AppLocalizations.of(context)?.tr('most_followed') ?? 'Most Followed'}',
                            players: _mostFollowedPlayers.take(10).toList(),
                            allPlayers: _mostFollowedPlayers,
                            pageController: _followedPageController,
                          ),
                        ),

                        SliverToBoxAdapter(child: SizedBox(height: 24)),

                        // 🔹 Youth Team (منتخب الناشئين)
                        SliverToBoxAdapter(
                          child: _buildPlayerSection(
                            title: AppLocalizations.of(context)?.tr('youth_team') ?? 'منتخب الناشئين',
                            players: _youthPlayers.take(10).toList(),
                            allPlayers: _youthPlayers,
                            pageController: PageController(viewportFraction: 0.85),
                          ),
                        ),

                        SliverToBoxAdapter(child: SizedBox(height: 24)),

// 🔹 Junior Team (منتخب الشباب)
                        SliverToBoxAdapter(
                          child: _buildPlayerSection(
                            title: AppLocalizations.of(context)?.tr('junior_team') ?? 'منتخب الشباب',
                            players: _juniorPlayers.take(10).toList(),
                            allPlayers: _juniorPlayers,
                            pageController: PageController(viewportFraction: 0.85),
                          ),
                        ),

                        SliverToBoxAdapter(child: SizedBox(height: 24)),

// 🔥 LAST SECTION (IMPORTANT)
                        SliverToBoxAdapter(
                          child: _buildPlayerSection(
                            title: AppLocalizations.of(context)?.tr('local_professionals') ?? 'محترفين محليين',
                            players: _localProsPlayers.take(10).toList(),
                            allPlayers: _localProsPlayers,
                            pageController: PageController(viewportFraction: 0.85),
                          ),
                        ),


                        SliverToBoxAdapter(child: SizedBox(height: 24)),

                        SliverToBoxAdapter(
                          child: _buildAllPlayersFooter(),
                        ),

/*                        // 👇 All Players List (IMPORTANT)
                        _buildAllPlayersList(),*/

                        SliverToBoxAdapter(child: SizedBox(height: 20)),

                      ],
                    )
                  ),
                 )
                ),
              ],
            ),
          // ✅ Bottom slogan (above bottom navigation bar)
    );
  }

      //bottomNavigationBar: const AppBottomBar(currentIndex: 2),

  Widget _buildAllPlayersFooter() {

    debugPrint("🎯 BUILD FOOTER → count = $_totalPlayersCount");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllPlayersScreen(
                  players: _allPlayersFull, // ✅ IMPORTANT
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          // 🔥 BIG TITLE
          Text(
            AppLocalizations.of(context)?.tr('all_players') ?? 'All Players',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          // 🔥 ANIMATED COUNT
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: _totalPlayersCount),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return AnimatedScale(
                scale: 1.1,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 9),

          // optional subtitle
              Image.asset(
                'assets/images/Arrow.png',
                width: 50,
                height: 50,
              ),
        ],
      ),
        ));
  }

  // ==================== SEARCH BAR ====================
  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            // 🔍 Search icon (static)
            const Icon(Icons.search, color: AppColors.primary),
            const SizedBox(width: 12),

            // 📝 Tap area → SearchScreen
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(
                        // Don't pass initialPlayers - will use API search
                        initialQuery: _searchController.text.trim(),
                      ),
                    ),
                  );
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)
                        ?.tr('search_for_player') ??
                        'Search for player...',
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 🎛️ FILTER ICON (THIS WAS MISSING)
            InkWell(
              onTap: _openHomeFiltersSheet,
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.filter_list,
                      size: 24,
                      color: AppColors.grey,
                    ),
                  ),

                  // 🔴 active filters indicator
                  if (_isFiltering)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  // ==================== ADS SECTION ====================
  // ==================== ADS SECTION ====================
  Widget _buildAdsSection() {
    // ✅ fallback placeholders if backend still empty
    final fallback = [
      HomeAd(slot: 1, title: 'انضم إلى الاسكواد', subtitle: 'اكتشف أفضل المواهب الكروية', imageUrl: null),
      HomeAd(slot: 2, title: 'كن كشافاً محترفاً', subtitle: 'Search for rising stars', imageUrl: null),
      HomeAd(slot: 3, title: 'مواهب مصرية', subtitle: 'Best players in Egypt', imageUrl: null),
    ];

    final list = _ads.isNotEmpty ? _ads : fallback;

    return SizedBox(
      height: 160,
      child: PageView.builder(
        controller: _adPageController,
        itemCount: list.length,
        onPageChanged: (index) {
          setState(() => _currentAdPage = index);
        },
        itemBuilder: (context, index) {
          final ad = list[index];

          // ✅ use imageUrl (and turn relative into absolute)
          final raw = (ad.finalImageUrl ?? ad.imageUrl ?? '').trim();
          final img = raw.isEmpty ? null : _getFullImageUrl(raw);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AdCard(
              title: ad.title,
              subtitle: ad.subtitle,
              imageUrl: img, // ✅ null => default asset
              onTap: () {
                // Optional later: open linkUrl
              },
            ),
          );
        },
      ),
    );
  }

  // ==================== PLAYER SECTION ====================
  Widget _buildPlayerSection({
    required String title,
    Widget? iconWidget,          // ✅ NEW (image or anything)
    IconData? categoryIcon,       // ✅ used only for CategoryPlayersScreen
    Color? iconColor,
    required List<User> players,
    required List<User> allPlayers,
    required PageController pageController,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header (always visible)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (iconWidget != null) ...[
                    SizedBox(width: 40, height: 44, child: iconWidget),
                    const SizedBox(width: 8),
                  ],

                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: players.isEmpty
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryPlayersScreen(
                        categoryTitle: title,
                        players: allPlayers,
                        categoryIcon: categoryIcon ?? Icons.people,
                        categoryColor: iconColor ?? AppColors.primary,
                      ),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)?.tr('view_all') ?? 'View All',
                  style: TextStyle(
                    color: players.isEmpty
                        ? (isDark ? Colors.white30 : Colors.black26)
                        : (isDark ? AppColors.darkModeAccent : AppColors.primary),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Body
        if (players.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Text(
                // keep your existing key, but nicer message for "Most Viewed" etc.
                AppLocalizations.of(context)?.tr('no_players_yet') ??
                    (AppLocalizations.of(context)?.tr('no_vip_players') ??
                        'No players yet'),
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black45,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: pageController,
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: PlayerCard(
                    player: player,
                    // ✅ ONE source of truth: increment + open + refresh
                    onTap: () => _openPlayerProfile(player),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }


// ==================== ALL PLAYERS LIST ====================
/*  Widget _buildAllPlayersList() {
    if (_allPlayers.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final displayPlayers = _allPlayers;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index >= displayPlayers.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final player = displayPlayers[index];

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.cardDark
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => _openPlayerProfile(player),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // 👤 Player Image
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: player.profilePhotoUrl != null
                          ? CachedNetworkImageProvider(
                        _getFullImageUrl(player.profilePhotoUrl),
                      )
                          : null,
                      backgroundColor: Colors.grey.shade300,
                    ),

                    const SizedBox(width: 12),

                    // 📄 Player Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ NAME
                          Text(
                            player.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // ✅ POSITION
                          if (player.position != null)
                            Text(
                              _translatePosition(player.position, loc),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),

                          const SizedBox(height: 4),

                          // ✅ COUNTRY
                          if (player.country != null)
                            Text(
                              _translateCountry(player.country, loc),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 👉 ACTION / BUTTON
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: displayPlayers.length + (_isLoadingMore ? 1 : 0),
      ),
    );
  }*/


  // ==================== BOTTOM NAVIGATION ====================
  Widget _buildBottomNavigationBar() {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'الرئيسية',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.article_outlined,
                activeIcon: Icons.article,
                label: 'المنشورات',
                index: 1,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedScreen()),
                  );
                },
              ),
              _buildNavItem(
                icon: Icons.message_outlined,
                activeIcon: Icons.message,
                label: 'الرسائل',
                index: 2,
                onTap: () {
                  // Navigate to Messages tab in MainScreen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 3)),
                  );
                },
              ),
              _buildNavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'الإعدادات',
                index: 3,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    VoidCallback? onTap,
  }) {
    final isActive = _currentBottomNavIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _currentBottomNavIndex = index);
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryVeryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.grey,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.primary : AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الإعدادات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('تسجيل الخروج'),
              onTap: () async {
                await AuthService.logout();
                if (mounted) {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ],
        ),
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
        child: SizedBox( // ✅ makes whole row tappable
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
    ));
  }
}
class HomeFilterResult {
  final bool applied; // true if user wants to commit
  final String? position;
  final String? country;
  final String? age;
  final String query;

  const HomeFilterResult({
    required this.applied,
    required this.position,
    required this.country,
    required this.age,
    required this.query,
  });
}
