import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:squad_player/utils/app_colors.dart';
import 'package:squad_player/services/api_service.dart';
import 'package:squad_player/screens/login_screen.dart';
import 'package:squad_player/providers/language_provider.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:squad_player/utils/app_localizations.dart';

import 'otp_verification_screen.dart';



class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  Timer? _resendTimer;
  final ValueNotifier<bool> _canResendOtp = ValueNotifier(true);
  final ValueNotifier<bool> _isLoadingWhatsapp = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingSms = ValueNotifier(false);
  final ValueNotifier<int> _remainingSeconds = ValueNotifier(60);

  final _formKey = GlobalKey<FormState>();

  // Basic fields
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Player specific fields
  final _fullNameController = TextEditingController();
  final _currentClubController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedPosition;
  String? _selectedCountry;
  DateTime? _selectedBirthDate;

  final List<Map<String, String>> _positions = [
    {'en': 'Goalkeeper', 'ar': 'حارس مرمى'},
    {'en': 'Right Back', 'ar': 'ظهير أيمن'},
    {'en': 'Center Back', 'ar': 'قلب دفاع'},
    {'en': 'Left Back', 'ar': 'ظهير أيسر'},
    {'en': 'Defensive Midfielder', 'ar': 'وسط دفاعي'},
    {'en': 'Central Midfielder', 'ar': 'وسط ميدان'},
    {'en': 'Attacking Midfielder', 'ar': 'وسط هجومي'},
    {'en': 'Right Winger', 'ar': 'جناح أيمن'},
    {'en': 'Left Winger', 'ar': 'جناح أيسر'},
    {'en': 'Striker', 'ar': 'مهاجم صريح'},
  ];

  final List<String> _countries = [
    // ================= Arab Countries =================
    'مصر',
    'السعودية',
    'الإمارات',
    'الكويت',
    'قطر',
    'البحرين',
    'عُمان',
    'الأردن',
    'لبنان',
    'سوريا',
    'العراق',
    'فلسطين',
    'اليمن',
    'ليبيا',
    'السودان',
    'الجزائر',
    'تونس',
    'المغرب',
    'موريتانيا',
    'جيبوتي',
    'الصومال',
    'جزر القمر',

    // ================= Africa =================
    'إثيوبيا',
    'إريتريا',
    'كينيا',
    'أوغندا',
    'تنزانيا',
    'رواندا',
    'بوروندي',
    'جنوب أفريقيا',
    'نيجيريا',
    'غانا',
    'السنغال',
    'الكاميرون',
    'ساحل العاج',
    'مالي',
    'النيجر',
    'تشاد',
    'زيمبابوي',
    'زامبيا',
    'موزمبيق',
    'أنغولا',
    'ناميبيا',
    'بوتسوانا',
    'ليسوتو',
    'إسواتيني',
    'سيشل',
    'موريشيوس',

    // ================= Asia =================
    'تركيا',
    'إيران',
    'أفغانستان',
    'باكستان',
    'الهند',
    'سريلانكا',
    'بنغلاديش',
    'نيبال',
    'الصين',
    'اليابان',
    'كوريا الجنوبية',
    'كوريا الشمالية',
    'تايلاند',
    'ماليزيا',
    'إندونيسيا',
    'سنغافورة',
    'فيتنام',
    'الفلبين',
    'كمبوديا',
    'لاوس',
    'منغوليا',
    'كازاخستان',
    'أوزبكستان',
    'تركمانستان',
    'طاجيكستان',
    'قرغيزستان',

    // ================= Europe =================
    'إيطاليا',
    'إسبانيا',
    'فرنسا',
    'ألمانيا',
    'هولندا',
    'بلجيكا',
    'سويسرا',
    'النمسا',
    'البرتغال',
    'المملكة المتحدة',
    'إيرلندا',
    'السويد',
    'النرويج',
    'الدنمارك',
    'فنلندا',
    'بولندا',
    'التشيك',
    'سلوفاكيا',
    'المجر',
    'رومانيا',
    'بلغاريا',
    'اليونان',
    'صربيا',
    'كرواتيا',
    'سلوفينيا',
    'البوسنة والهرسك',
    'ألبانيا',
    'مقدونيا الشمالية',
    'أوكرانيا',
    'روسيا',
    'بيلاروسيا',
    'لاتفيا',
    'ليتوانيا',
    'إستونيا',
    'مولدوفا',

    // ================= Americas =================
    'الولايات المتحدة',
    'كندا',
    'المكسيك',
    'غواتيمالا',
    'كوبا',
    'جمهورية الدومينيكان',
    'كوستاريكا',
    'بنما',
    'البرازيل',
    'الأرجنتين',
    'تشيلي',
    'كولومبيا',
    'بيرو',
    'فنزويلا',
    'الإكوادور',
    'بوليفيا',
    'باراغواي',
    'أوروغواي',

    // ================= Oceania =================
    'أستراليا',
    'نيوزيلندا',
    'فيجي',
    'بابوا غينيا الجديدة',
    'ساموا',
    'تونغا',
  ];


  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isUnregistered = false;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _currentClubController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _resendTimer?.cancel();
    _canResendOtp.dispose();
    _isLoadingWhatsapp.dispose();
    _isLoadingSms.dispose();
    _remainingSeconds.dispose();
    super.dispose();
  }

  TextDirection _getTextDirection(String text) {
    if (text.isEmpty) return TextDirection.rtl; // default for Arabic UI

    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  // Updated method with Arabic date picker support
  Future<void> _selectBirthDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    DateTime tempDate = _selectedBirthDate ?? DateTime(2000, 1, 1);

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return Theme(
          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light())
                .copyWith(primary: AppColors.primary),
          ),
          child: AlertDialog(
            title: const Text('اختيار تاريخ الميلاد'),
            content: SizedBox(
              width: 340,
              height: 360,
              child: CalendarDatePicker(
                initialDate: tempDate,
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
                onDateChanged: (d) {
                  tempDate = d;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, tempDate),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;

        // More accurate age (handles month/day)
        final now = DateTime.now();
        int age = now.year - picked.year;
        if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        _ageController.text = age.toString();
      });
    }
  }





  // Helper method to format date with Arabic numerals
  String _formatDateArabic(DateTime date) {
    const arabicNumerals = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    String convertToArabicNumerals(int number) {
      return number.toString().split('').map((digit) {
        return arabicNumerals[int.parse(digit)];
      }).join('');
    }

    final year = convertToArabicNumerals(date.year);
    final month = convertToArabicNumerals(date.month);
    final day = convertToArabicNumerals(date.day);

    return '$year/$month/$day';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _showError('يرجى ملء جميع الحقول المطلوبة');
      return;
    }

    if (_selectedPosition == null) {
      _showError('يرجى اختيار المركز');
      return;
    }

    if (_selectedCountry == null) {
      _showError('يرجى اختيار الدولة');
      return;
    }

    if (_selectedBirthDate == null) {
      _showError('يرجى اختيار تاريخ الميلاد');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.register(
        name: _nameController.text.trim(),
        password: _passwordController.text,
        // Additional player data
        country: _selectedCountry!,
        position: _selectedPosition!,
        bio: null,  // Bio will be set later in edit profile
        currentClub: _isUnregistered ? 'غير مقيد' : _currentClubController.text.trim(),
        age: int.parse(_ageController.text),
        weight: int.parse(_weightController.text),
        height: int.parse(_heightController.text),
        fullName: _fullNameController.text.trim(),
        address: _addressController.text.trim(),
        birthDate: _selectedBirthDate!.toIso8601String().split('T')[0],
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Show OTP method selection bottom sheet
        _showOtpMethodBottomSheet();
      } else {
        _showError(result['message'] ?? ( AppLocalizations.of(context)?.tr('error_register_failed') ?? 'Registration failed'));
      }
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showOtpMethodBottomSheet() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 15,
                children: [
                  Text(loc?.tr('select_otp_method') ?? 'Select OTP Method', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ValueListenableBuilder<bool>(
                    valueListenable: _canResendOtp,
                    builder: (context, canResend, child) {
                      if (canResend) return SizedBox.shrink();
                      return ValueListenableBuilder<int>(
                        valueListenable: _remainingSeconds,
                        builder: (context, remaining, child) {
                          return Text(
                            (loc?.tr('resend_in') ?? 'Resend in {count}').replaceAll('{count}', remaining.toString()),
                            style: const TextStyle(fontSize: 16, color: Colors.red),
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoadingSms,
                    builder: (context, isLoading, child) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _canResendOtp,
                        builder: (context, canResend, child) {
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.message_outlined),
                            label: isLoading
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text(
                                  loc?.tr('resending_via_sms') ?? 'Resending via SMS',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                                : Text(
                              loc?.tr('receive_otp_via_sms') ?? 'Receive OTP via SMS',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                            onPressed: canResend ? () => _sendOtp('sms') : null,
                            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48))),
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoadingWhatsapp,
                    builder: (context, isLoading, child) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _canResendOtp,
                        builder: (context, canResend, child) {
                          return ElevatedButton.icon(
                            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                            label: isLoading
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text(
                                  loc?.tr('resending_via_whatsapp') ?? 'Resending via WhatsApp',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                                : Text(
                              loc?.tr('receive_otp_via_whatsapp') ?? 'Receive OTP via WhatsApp',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                            onPressed: canResend ? () => _sendOtp('whatsapp') : null,
                            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48))),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendOtp(String method) async {
    final loc = AppLocalizations.of(context);

    // Validate phone number
    if (_phoneController.text.isEmpty || _phoneController.text.length < 10) {
      _showError(loc?.tr('validation_phone_required') ?? 'Phone number is required');
      return;
    }

    // Start loading
    if (method == 'sms') {
      _isLoadingSms.value = true;
    } else {
      _isLoadingWhatsapp.value = true;
    }

    try {
      final response = await ApiService.sendOtp(
        phone: _phoneController.text.trim(),
        verificationMethod: method,
      );

      if (response['success'] == true) {
        if (method == 'sms') {
          _isLoadingSms.value = false;
        } else {
          _isLoadingWhatsapp.value = false;
        }
        _canResendOtp.value = false;
        _remainingSeconds.value = 60;
        _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          _remainingSeconds.value--;
          if (_remainingSeconds.value <= 0) {
            _canResendOtp.value = true;
            timer.cancel();
          }
        });
        // OTP sent successfully, navigate to verification screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: _phoneController.text.trim(),
              verificationMethod: method,
              fromRegister: true,
            ),
          ),
        );
      } else {
        if (method == 'sms') {
          _isLoadingSms.value = false;
        } else {
          _isLoadingWhatsapp.value = false;
        }
        _canResendOtp.value = true;
        _showError(response['message'] ?? (loc?.tr('error_sending_otp') ?? 'Error sending OTP'));
      }
    } catch (e) {
      if (method == 'sms') {
        _isLoadingSms.value = false;
      } else {
        _isLoadingWhatsapp.value = false;
      }
      _canResendOtp.value = true;
      _showError('${loc?.tr('error') ?? 'Error'}: $e');
    } finally {
      // Stop loading
      if (method == 'sms') {
        _isLoadingSms.value = false;
      } else {
        _isLoadingWhatsapp.value = false;
        _canResendOtp.value = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('تسجيل لاعب جديد'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo_with_white_outline.png',
                    width: 200,
                    height: 200,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'إنشاء حساب لاعب',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),



                const SizedBox(height: 32),

                // Section: Personal Details
                _buildSectionTitle('التفاصيل الشخصية'),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _fullNameController,
                  label: 'الإسم كاملاً ',
                  icon: Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'الاسم بالكامل مطلوب';
                    }

                    String name = v.trim();

                    // ✅ Allow both Arabic AND English letters, plus spaces, hyphens, and apostrophes
                    if (!RegExp(r"^[\u0600-\u06FF a-zA-Z\-\'\s]+$").hasMatch(name)) {
                      return 'الاسم يجب أن يحتوي على حروف فقط (عربي أو إنجليزي)';
                    }

                    // Count the number of words (split by spaces)
                    final words = name.split(RegExp(r'\s+'));

                    // ✅ Validate word count: must be at least 4 words (quadruple or more)
                    if (words.length < 4) {
                      return 'الاسم يجب أن يكون رباعياً على الأقل (4 كلمات أو أكثر)';
                    }

                    // Optional: Ensure each word has at least 2 characters
                    for (var word in words) {
                      if (word.length < 2) {
                        return 'كل كلمة يجب أن تحتوي على حرفين على الأقل';
                      }
                    }

                    return null; // Validation passed
                  },
                ),


                const SizedBox(height: 16),

                _buildTextField(
                  controller: _addressController,
                  label: 'المحافظة - المدينة',
                  icon: Icons.location_on_outlined,
                  keyboardType: TextInputType.streetAddress,
                  maxLines: 2,
                  validator: (v) {
                    if(v != null && v.trim().isNotEmpty) {
                      if ((v.trim().length ?? 11) < 10) {
                        return 'العنوان قصير جداً';
                      }
                    }

                    return null;
                  },
                ),


                const SizedBox(height: 16),

                // Birth Date Picker with Arabic support
                InkWell(
                  onTap: _selectBirthDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '',
                      prefixIcon: Icon(Icons.calendar_today, color: isDark ? AppColors.darkAccent : AppColors.primary),
                    ),
                    child: Consumer<LanguageProvider>(
                      builder: (context, languageProvider, _) {
                        final isArabic = languageProvider.locale.languageCode == 'ar';
                        final isDark = Theme.of(context).brightness == Brightness.dark;

                        String formattedDate;
                        if (_selectedBirthDate == null) {
                          formattedDate = isArabic ? ' تاريخ الميلاد' : 'Date of Birth';
                        } else {
                          formattedDate = isArabic
                              ? _formatDateArabic(_selectedBirthDate!)
                              : '${_selectedBirthDate!.year}/${_selectedBirthDate!.month}/${_selectedBirthDate!.day}';
                        }

                        return Text(
                          formattedDate,
                          style: TextStyle(
                            color: _selectedBirthDate == null
                                ? (isDark ? Colors.grey[400] : AppColors.textSecondary)
                                : (isDark ? Colors.white : Colors.black87),  // ✅ White text in dark mode!
                            fontSize: 16,
                          ),
                          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                        );
                      },
                    ),
                  ),
                ),


                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _weightController,
                        label: 'الوزن (Kg) ',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v!.isEmpty) return 'مطلوب';
                          if (int.tryParse(v) == null) return 'غير صحيح';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _heightController,
                        label: 'الطول (Cm) ',
                        icon: Icons.height_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v!.isEmpty) return 'مطلوب';
                          if (int.tryParse(v) == null) return 'غير صحيح';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),


                // Section: Basic Information

                const SizedBox(height: 32),

                // Section: Player Information
                _buildSectionTitle('معلومات اللاعب'),
                const SizedBox(height: 16),

                // Country Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCountry,
                  decoration: InputDecoration(
                    labelText: 'الدولة ',
                    prefixIcon: Icon(Icons.flag_outlined, color: isDark ? AppColors.darkAccent : AppColors.primary),
                  ),
                  items: _countries.map((country) {
                    return DropdownMenuItem(
                      value: country,
                      child: Text(
                        country,
                        textDirection: TextDirection.rtl,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCountry = value);
                  },
                  validator: (v) => v == null ? 'الدولة مطلوبة' : null,
                ),

                const SizedBox(height: 16),

                // Position Dropdown
                DropdownButtonFormField2<String>(
                  value: _selectedPosition,
                  decoration: InputDecoration(
                    labelText: 'المركز ',
                    prefixIcon: Icon(
                      Icons.sports_soccer,
                      color: isDark ? AppColors.darkAccent : AppColors.primary,
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    elevation: 0,
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    overlayColor: MaterialStatePropertyAll(Colors.transparent),
                  ),
                  items: _positions.map((position) {
                    return DropdownMenuItem<String>(
                      value: position['en'],
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          position['ar']!,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedPosition = value);
                  },
                  validator: (v) => v == null ? 'المركز مطلوب' : null,
                ),


                const SizedBox(height: 16),

                // Current Club field with checkbox
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _currentClubController,
                        label: 'النادى الحالى ',
                        icon: Icons.shield_outlined,
                        readOnly: _isUnregistered,
                        validator: (v) {
                          if (!_isUnregistered && v!.isEmpty) {
                            return 'النادى الحالى مطلوب';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Checkbox(
                          value: _isUnregistered,
                          activeColor: isDark ? AppColors.darkAccent : AppColors.primary,
                          onChanged: (value) {
                            setState(() {
                              _isUnregistered = value ?? false;
                              if (_isUnregistered) {
                                _currentClubController.text = 'غير مقيد';
                              } else {
                                _currentClubController.clear();
                              }
                            });
                          },
                        ),
                        const Text(
                          'غير مقيد',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),


                const SizedBox(height: 32),
                _buildSectionTitle('معلومات الحساب'),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _nameController,
                  label: 'إسم الشهرة ',
                  icon: Icons.person_outline,
                  validator: (v) => v!.isEmpty ? 'الاسم مطلوب' : null,
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _phoneController,
                  label: 'رقم التليفون ',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  validator: (v) {
                    if (v!.isEmpty) return 'رقم التليفون مطلوب';
                    if (v.length < 10) return 'رقم التليفون غير صحيح';
                    return null;
                  },
                ),

                const SizedBox(height: 16),


                _buildTextField(
                  controller: _passwordController,
                  label: 'كلمة السر ',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return 'كلمة السر مطلوبة';
                    if (v.length < 8) return 'كلمة السر قصيرة جداً (8 على الأقل)';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'تأكيد كلمة السر ',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirmPassword,
                  textDirection: TextDirection.ltr,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return 'تأكيد كلمة السر مطلوب';
                    if (v != _passwordController.text) return 'كلمات السر غير متطابقة';
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Register Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkAccent : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'إنشاء حساب',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'لديك حساب بالفعل؟ ',
                      style: TextStyle(color: isDark ? Colors.grey[400] : AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          color: isDark ? AppColors.darkAccent : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkAccent : AppColors.primary,
      ),
      textDirection: TextDirection.rtl,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
    TextDirection? textDirection,
    List<TextInputFormatter>? inputFormatters, // ✅ الحل هنا
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StatefulBuilder(
      builder: (context, setState) {
        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,

          textDirection: _getTextDirection(controller.text),

          textAlign: _getTextDirection(controller.text) == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.left,

          onChanged: (_) => setState(() {}), // 🔥 أهم سطر

          inputFormatters: inputFormatters,

          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(
              icon,
              color: isDark ? AppColors.darkAccent : AppColors.primary,
            ),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        );
      },
    );
  }

}