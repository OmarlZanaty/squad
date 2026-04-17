import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/models/user.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/utils/position_translator.dart';
import 'package:squad/screens/player_profile_screen.dart';

class PlayerCard extends StatelessWidget {
  final User player;
  final VoidCallback? onTap;

  const PlayerCard({
    super.key,
    required this.player,
    this.onTap,
  });

  String get _getFullImageUrl {
    if (player.profilePhotoUrl == null || player.profilePhotoUrl!.isEmpty) {
      return '';
    }
    if (player.profilePhotoUrl!.startsWith('http')) {
      return player.profilePhotoUrl!;
    }
    return 'http://187.124.37.68:3000${player.profilePhotoUrl}';
  }

  String _formatNumber(dynamic v, {String? suffix}) {
    if (v == null) return '-';

    // If it's already a number
    if (v is num) {
      final n = v.toDouble();
      final text = (n % 1 == 0) ? n.toInt().toString() : n.toStringAsFixed(1);
      return suffix == null ? text : '$text $suffix';
    }

    // If it's a string
    final s = v.toString().trim();
    if (s.isEmpty) return '-';

    // If string has number inside like "175 cm"
    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(s);
    if (match == null) return s; // fallback show string
    final text = match.group(1)!;

    return suffix == null ? text : '$text $suffix';
  }

  String _getCountryFlag(String? country) {
    if (country == null) return '';

    final Map<String, String> countryFlags = {
      // Africa
      'Egypt': '🇪🇬',
      'مصر': '🇪🇬',
      'Tunisia': '🇹🇳',
      'تونس': '🇹🇳',
      'South Africa': '🇿🇦',
      'جنوب أفريقيا': '🇿🇦',
      'Morocco': '🇲🇦',
      'المغرب': '🇲🇦',
      'Algeria': '🇩🇿',
      'الجزائر': '🇩🇿',
      'Nigeria': '🇳🇬',
      'نيجيريا': '🇳🇬',
      'Senegal': '🇸🇳',
      'السنغال': '🇸🇳',
      'Ghana': '🇬🇭',
      'غانا': '🇬🇭',
      'Cameroon': '🇨🇲',
      'الكاميرون': '🇨🇲',
      'Ivory Coast': '🇨🇮',
      'ساحل العاج': '🇨🇮',
      'Libya': '🇱🇾',
      'ليبيا': '🇱🇾',
      'Sudan': '🇸🇩',
      'السودان': '🇸🇩',
      'Ethiopia': '🇪🇹',
      'إثيوبيا': '🇪🇹',
      'Kenya': '🇰🇪',
      'كينيا': '🇰🇪',
      'Tanzania': '🇹🇿',
      'تنزانيا': '🇹🇿',
      'Uganda': '🇺🇬',
      'أوغندا': '🇺🇬',
      'Mali': '🇲🇱',
      'مالي': '🇲🇱',
      'Burkina Faso': '🇧🇫',
      'بوركينا فاسو': '🇧🇫',
      'Guinea': '🇬🇳',
      'غينيا': '🇬🇳',
      'Zambia': '🇿🇲',
      'زامبيا': '🇿🇲',
      'Zimbabwe': '🇿🇼',
      'زيمبابوي': '🇿🇼',
      'Congo': '🇨🇬',
      'الكونغو': '🇨🇬',
      'DR Congo': '🇨🇩',
      'الكونغو الديمقراطية': '🇨🇩',
      'Angola': '🇦🇴',
      'أنغولا': '🇦🇴',
      'Mozambique': '🇲🇿',
      'موزمبيق': '🇲🇿',
      'Gabon': '🇬🇦',
      'الغابون': '🇬🇦',
      'Mauritania': '🇲🇷',
      'موريتانيا': '🇲🇷',
      'Benin': '🇧🇯',
      'بنين': '🇧🇯',
      'Togo': '🇹🇬',
      'توغو': '🇹🇬',
      'Niger': '🇳🇪',
      'النيجر': '🇳🇪',
      'Chad': '🇹🇩',
      'تشاد': '🇹🇩',
      'Rwanda': '🇷🇼',
      'رواندا': '🇷🇼',
      'Burundi': '🇧🇮',
      'بوروندي': '🇧🇮',
      'Somalia': '🇸🇴',
      'الصومال': '🇸🇴',
      'Eritrea': '🇪🇷',
      'إريتريا': '🇪🇷',
      'Djibouti': '🇩🇯',
      'جيبوتي': '🇩🇯',
      'Comoros': '🇰🇲',
      'جزر القمر': '🇰🇲',
      'Mauritius': '🇲🇺',
      'موريشيوس': '🇲🇺',
      'Madagascar': '🇲🇬',
      'مدغشقر': '🇲🇬',
      'Malawi': '🇲🇼',
      'مالاوي': '🇲🇼',
      'Botswana': '🇧🇼',
      'بوتسوانا': '🇧🇼',
      'Namibia': '🇳🇦',
      'ناميبيا': '🇳🇦',
      'Lesotho': '🇱🇸',
      'ليسوتو': '🇱🇸',
      'Eswatini': '🇸🇿',
      'إسواتيني': '🇸🇿',
      'Cape Verde': '🇨🇻',
      'الرأس الأخضر': '🇨🇻',
      'Gambia': '🇬🇲',
      'غامبيا': '🇬🇲',
      'Guinea-Bissau': '🇬🇼',
      'غينيا بيساو': '🇬🇼',
      'Liberia': '🇱🇷',
      'ليبيريا': '🇱🇷',
      'Sierra Leone': '🇸🇱',
      'سيراليون': '🇸🇱',
      'Central African Republic': '🇨🇫',
      'جمهورية أفريقيا الوسطى': '🇨🇫',
      'Equatorial Guinea': '🇬🇶',
      'غينيا الاستوائية': '🇬🇶',
      'Sao Tome and Principe': '🇸🇹',
      'ساو تومي وبرينسيبي': '🇸🇹',
      'Seychelles': '🇸🇨',
      'سيشل': '🇸🇨',
      'South Sudan': '🇸🇸',
      'جنوب السودان': '🇸🇸',

      // Middle East
      'Saudi Arabia': '🇸🇦',
      'السعودية': '🇸🇦',
      'UAE': '🇦🇪',
      'United Arab Emirates': '🇦🇪',
      'الإمارات': '🇦🇪',
      'Qatar': '🇶🇦',
      'قطر': '🇶🇦',
      'Kuwait': '🇰🇼',
      'الكويت': '🇰🇼',
      'Bahrain': '🇧🇭',
      'البحرين': '🇧🇭',
      'Oman': '🇴🇲',
      'عمان': '🇴🇲',
      'Yemen': '🇾🇪',
      'اليمن': '🇾🇪',
      'Iraq': '🇮🇶',
      'العراق': '🇮🇶',
      'Syria': '🇸🇾',
      'سوريا': '🇸🇾',
      'Jordan': '🇯🇴',
      'الأردن': '🇯🇴',
      'Lebanon': '🇱🇧',
      'لبنان': '🇱🇧',
      'Palestine': '🇵🇸',
      'فلسطين': '🇵🇸',
      'Iran': '🇮🇷',
      'إيران': '🇮🇷',
      'Turkey': '🇹🇷',
      'تركيا': '🇹🇷',
      'Israel': '🇮🇱',
      'إسرائيل': '🇮🇱',

      // Europe
      'England': '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
      'إنجلترا': '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
      'United Kingdom': '🇬🇧',
      'UK': '🇬🇧',
      'بريطانيا': '🇬🇧',
      'Scotland': '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
      'اسكتلندا': '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
      'Wales': '🏴󠁧󠁢󠁷󠁬󠁳󠁿',
      'ويلز': '🏴󠁧󠁢󠁷󠁬󠁳󠁿',
      'France': '🇫🇷',
      'فرنسا': '🇫🇷',
      'Germany': '🇩🇪',
      'ألمانيا': '🇩🇪',
      'Spain': '🇪🇸',
      'إسبانيا': '🇪🇸',
      'Italy': '🇮🇹',
      'إيطاليا': '🇮🇹',
      'Portugal': '🇵🇹',
      'البرتغال': '🇵🇹',
      'Netherlands': '🇳🇱',
      'هولندا': '🇳🇱',
      'Belgium': '🇧🇪',
      'بلجيكا': '🇧🇪',
      'Switzerland': '🇨🇭',
      'سويسرا': '🇨🇭',
      'Austria': '🇦🇹',
      'النمسا': '🇦🇹',
      'Poland': '🇵🇱',
      'بولندا': '🇵🇱',
      'Czech Republic': '🇨🇿',
      'التشيك': '🇨🇿',
      'Greece': '🇬🇷',
      'اليونان': '🇬🇷',
      'Sweden': '🇸🇪',
      'السويد': '🇸🇪',
      'Norway': '🇳🇴',
      'النرويج': '🇳🇴',
      'Denmark': '🇩🇰',
      'الدنمارك': '🇩🇰',
      'Finland': '🇫🇮',
      'فنلندا': '🇫🇮',
      'Ireland': '🇮🇪',
      'أيرلندا': '🇮🇪',
      'Russia': '🇷🇺',
      'روسيا': '🇷🇺',
      'Ukraine': '🇺🇦',
      'أوكرانيا': '🇺🇦',
      'Croatia': '🇭🇷',
      'كرواتيا': '🇭🇷',
      'Serbia': '🇷🇸',
      'صربيا': '🇷🇸',
      'Romania': '🇷🇴',
      'رومانيا': '🇷🇴',
      'Hungary': '🇭🇺',
      'المجر': '🇭🇺',
      'Bulgaria': '🇧🇬',
      'بلغاريا': '🇧🇬',
      'Slovakia': '🇸🇰',
      'سلوفاكيا': '🇸🇰',
      'Slovenia': '🇸🇮',
      'سلوفينيا': '🇸🇮',
      'Bosnia': '🇧🇦',
      'البوسنة': '🇧🇦',
      'Albania': '🇦🇱',
      'ألبانيا': '🇦🇱',
      'North Macedonia': '🇲🇰',
      'مقدونيا الشمالية': '🇲🇰',
      'Montenegro': '🇲🇪',
      'الجبل الأسود': '🇲🇪',
      'Kosovo': '🇽🇰',
      'كوسوفو': '🇽🇰',
      'Iceland': '🇮🇸',
      'أيسلندا': '🇮🇸',
      'Luxembourg': '🇱🇺',
      'لوكسمبورغ': '🇱🇺',
      'Malta': '🇲🇹',
      'مالطا': '🇲🇹',
      'Cyprus': '🇨🇾',
      'قبرص': '🇨🇾',
      'Estonia': '🇪🇪',
      'إستونيا': '🇪🇪',
      'Latvia': '🇱🇻',
      'لاتفيا': '🇱🇻',
      'Lithuania': '🇱🇹',
      'ليتوانيا': '🇱🇹',
      'Belarus': '🇧🇾',
      'بيلاروسيا': '🇧🇾',
      'Moldova': '🇲🇩',
      'مولدوفا': '🇲🇩',
      'Georgia': '🇬🇪',
      'جورجيا': '🇬🇪',
      'Armenia': '🇦🇲',
      'أرمينيا': '🇦🇲',
      'Azerbaijan': '🇦🇿',
      'أذربيجان': '🇦🇿',

      // Americas
      'USA': '🇺🇸',
      'United States': '🇺🇸',
      'أمريكا': '🇺🇸',
      'الولايات المتحدة': '🇺🇸',
      'Canada': '🇨🇦',
      'كندا': '🇨🇦',
      'Mexico': '🇲🇽',
      'المكسيك': '🇲🇽',
      'Brazil': '🇧🇷',
      'البرازيل': '🇧🇷',
      'Argentina': '🇦🇷',
      'الأرجنتين': '🇦🇷',
      'Colombia': '🇨🇴',
      'كولومبيا': '🇨🇴',
      'Chile': '🇨🇱',
      'تشيلي': '🇨🇱',
      'Peru': '🇵🇪',
      'بيرو': '🇵🇪',
      'Venezuela': '🇻🇪',
      'فنزويلا': '🇻🇪',
      'Ecuador': '🇪🇨',
      'الإكوادور': '🇪🇨',
      'Uruguay': '🇺🇾',
      'أوروغواي': '🇺🇾',
      'Paraguay': '🇵🇾',
      'باراغواي': '🇵🇾',
      'Bolivia': '🇧🇴',
      'بوليفيا': '🇧🇴',
      'Cuba': '🇨🇺',
      'كوبا': '🇨🇺',
      'Jamaica': '🇯🇲',
      'جامايكا': '🇯🇲',
      'Haiti': '🇭🇹',
      'هايتي': '🇭🇹',
      'Dominican Republic': '🇩🇴',
      'جمهورية الدومينيكان': '🇩🇴',
      'Costa Rica': '🇨🇷',
      'كوستاريكا': '🇨🇷',
      'Panama': '🇵🇦',
      'بنما': '🇵🇦',
      'Honduras': '🇭🇳',
      'هندوراس': '🇭🇳',
      'El Salvador': '🇸🇻',
      'السلفادور': '🇸🇻',
      'Guatemala': '🇬🇹',
      'غواتيمالا': '🇬🇹',
      'Nicaragua': '🇳🇮',
      'نيكاراغوا': '🇳🇮',
      'Trinidad and Tobago': '🇹🇹',
      'ترينيداد وتوباغو': '🇹🇹',

      // Asia
      'China': '🇨🇳',
      'الصين': '🇨🇳',
      'Japan': '🇯🇵',
      'اليابان': '🇯🇵',
      'South Korea': '🇰🇷',
      'كوريا الجنوبية': '🇰🇷',
      'North Korea': '🇰🇵',
      'كوريا الشمالية': '🇰🇵',
      'India': '🇮🇳',
      'الهند': '🇮🇳',
      'Pakistan': '🇵🇰',
      'باكستان': '🇵🇰',
      'Bangladesh': '🇧🇩',
      'بنغلاديش': '🇧🇩',
      'Indonesia': '🇮🇩',
      'إندونيسيا': '🇮🇩',
      'Malaysia': '🇲🇾',
      'ماليزيا': '🇲🇾',
      'Thailand': '🇹🇭',
      'تايلاند': '🇹🇭',
      'Vietnam': '🇻🇳',
      'فيتنام': '🇻🇳',
      'Philippines': '🇵🇭',
      'الفلبين': '🇵🇭',
      'Singapore': '🇸🇬',
      'سنغافورة': '🇸🇬',
      'Myanmar': '🇲🇲',
      'ميانمار': '🇲🇲',
      'Cambodia': '🇰🇭',
      'كمبوديا': '🇰🇭',
      'Sri Lanka': '🇱🇰',
      'سريلانكا': '🇱🇰',
      'Nepal': '🇳🇵',
      'نيبال': '🇳🇵',
      'Afghanistan': '🇦🇫',
      'أفغانستان': '🇦🇫',
      'Uzbekistan': '🇺🇿',
      'أوزبكستان': '🇺🇿',
      'Kazakhstan': '🇰🇿',
      'كازاخستان': '🇰🇿',
      'Turkmenistan': '🇹🇲',
      'تركمانستان': '🇹🇲',
      'Tajikistan': '🇹🇯',
      'طاجيكستان': '🇹🇯',
      'Kyrgyzstan': '🇰🇬',
      'قيرغيزستان': '🇰🇬',
      'Mongolia': '🇲🇳',
      'منغوليا': '🇲🇳',
      'Laos': '🇱🇦',
      'لاوس': '🇱🇦',
      'Brunei': '🇧🇳',
      'بروناي': '🇧🇳',
      'Maldives': '🇲🇻',
      'المالديف': '🇲🇻',
      'Bhutan': '🇧🇹',
      'بوتان': '🇧🇹',
      'Timor-Leste': '🇹🇱',
      'تيمور الشرقية': '🇹🇱',

      // Oceania
      'Australia': '🇦🇺',
      'أستراليا': '🇦🇺',
      'New Zealand': '🇳🇿',
      'نيوزيلندا': '🇳🇿',
      'Fiji': '🇫🇯',
      'فيجي': '🇫🇯',
      'Papua New Guinea': '🇵🇬',
      'بابوا غينيا الجديدة': '🇵🇬',
      'Samoa': '🇼🇸',
      'ساموا': '🇼🇸',
      'Tonga': '🇹🇴',
      'تونغا': '🇹🇴',
      'Vanuatu': '🇻🇺',
      'فانواتو': '🇻🇺',
      'Solomon Islands': '🇸🇧',
      'جزر سليمان': '🇸🇧',
    };

    return countryFlags[country] ?? '🌍';
  }

  String _getClubName(BuildContext context) {
    // Use actual currentClub from database first
    if (player.currentClub != null && player.currentClub!.isNotEmpty) {
      return player.currentClub!;
    }

    // Fallback: try to extract from bio if currentClub is not set
    if (player.bio != null && player.bio!.isNotEmpty) {
      final bioLower = player.bio!.toLowerCase();
      if (bioLower.contains('al ahly') || bioLower.contains('ahly')) return AppLocalizations.of(context)?.tr('al_ahly') ?? 'Al Ahly';
      if (bioLower.contains('zamalek')) return AppLocalizations.of(context)?.tr('zamalek') ?? 'Zamalek';
      if (bioLower.contains('future')) return AppLocalizations.of(context)?.tr('future') ?? 'Future';
      if (bioLower.contains('ismaily')) return AppLocalizations.of(context)?.tr('ismaily') ?? 'Ismaily';
      if (bioLower.contains('pyramids')) return AppLocalizations.of(context)?.tr('pyramids') ?? 'Pyramids';
      if (bioLower.contains('enppi')) return 'ENPPI';
      if (bioLower.contains('smouha')) return AppLocalizations.of(context)?.tr('smouha') ?? 'Smouha';
      if (bioLower.contains('ceramica')) return 'Ceramica Cleopatra';
      if (bioLower.contains('eastern company')) return 'Eastern Company';
      if (bioLower.contains('national bank')) return 'National Bank';
      if (bioLower.contains('pharco')) return 'Pharco';
      if (bioLower.contains('el gouna')) return 'El Gouna';
    }
    return AppLocalizations.of(context)?.tr('club') ?? 'Club';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('✅ PlayerCard tapped id=${player.id}');
        onTap?.call(); // ✅ CALL THE CALLBACK FROM CATEGORY SCREEN
      },
      child: Container(
        width: 320,
        height: 240,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // TOP SECTION WITH IMAGE ON LEFT AND INFO ON RIGHT
            Expanded(
              child: Stack(
                children: [
                  // MAIN LAYOUT: Image Left, Info Right (Force LTR)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        // LEFT SIDE - PLAYER IMAGE
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                          child: Container(
                            width: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _getFullImageUrl.isNotEmpty
                                  ? Image.network(
                                _getFullImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.secondaryCardDark : const Color(0xFFE0E0E0),
                                  child: const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white24,
                                  ),
                                ),
                              )
                                  : Container(
                                color: Theme.of(context).brightness == Brightness.dark ? AppColors.secondaryCardDark : const Color(0xFFE0E0E0),
                                child: const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // RIGHT SIDE - PLAYER INFO
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 12,
                              right: 8,
                              left: 6,
                              bottom: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // Player Name
                                Text(
                                  player.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 6),

                                // Country Name with Flag
                                if (player.country != null)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)?.tr(player.country!.toLowerCase().replaceAll(' ', '_')) ?? player.country!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getCountryFlag(player.country),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 6),


                                const Spacer(),

                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),

            // BOTTOM SECTION - 4 STAT BOXES (Position, Club, Height, Weight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  // Position Box
                  _buildStatBox(
                    context,
                    label: AppLocalizations.of(context)?.tr('position') ?? 'المركز',
                    value: player.position != null ? (AppLocalizations.of(context)?.tr(PositionTranslator.toTranslationKey(player.position)) ?? player.position!) : '-',
                  ),

                  const SizedBox(width: 4),

                  // Club Box
                  _buildStatBox(
                    context,
                    label: AppLocalizations.of(context)?.tr('club') ?? 'النادي',
                    value: _getClubName(context),
                  ),

                  const SizedBox(width: 4),

                  // Height Box
                  _buildStatBox(
                    context,
                    label: AppLocalizations.of(context)?.tr('height') ?? 'الطول',
                    value: _formatNumber(player.height, suffix: ''),
                  ),

                  const SizedBox(width: 4),

                  // Weight Box
                  _buildStatBox(
                    context,
                    label: AppLocalizations.of(context)?.tr('weight') ?? 'الوزن',
                    value: _formatNumber(player.weight, suffix: ''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(
      BuildContext context, {
        required String label,
        required String value,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.backgroundDark
              : const Color(0xFF26A69A), // ✅ Light mode color
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? AppColors.secondaryCardDark
                : const Color(0xFF1F8F84), // darker teal border
            width: 1,
          ),

        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white60 : Colors.white.withOpacity(0.85),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),

            // Value
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.white, // white on teal
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

}
