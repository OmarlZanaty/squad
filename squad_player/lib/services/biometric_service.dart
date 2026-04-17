import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> canUseBiometrics() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final biometrics = await _auth.getAvailableBiometrics();

      // debug
      // ignore: avoid_print
      print('BIO: isSupported=$isSupported canCheck=$canCheck biometrics=$biometrics');

      return isSupported && canCheck && biometrics.isNotEmpty;
    } catch (e) {
      // ignore: avoid_print
      print('BIO: canUseBiometrics error: $e');
      return false;
    }
  }

  static Future<bool> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
      );
      // ignore: avoid_print
      print('BIO: authenticate result=$ok');
      return ok;
    } catch (e) {
      // ignore: avoid_print
      print('BIO: authenticate error: $e');
      return false;
    }
  }
}
