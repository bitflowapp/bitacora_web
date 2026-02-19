import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumState {
  const PremiumState({
    required this.signedIn,
    required this.isPremium,
    required this.premiumActive,
    required this.trialEndsAt,
    required this.trialStartedAt,
    required this.premiumSource,
  });

  final bool signedIn;
  final bool isPremium;
  final bool premiumActive;
  final DateTime? trialEndsAt;
  final DateTime? trialStartedAt;
  final String premiumSource;

  bool get trialFinished {
    if (trialEndsAt == null) return false;
    return !DateTime.now().toUtc().isBefore(trialEndsAt!);
  }

  int get remainingTrialDays {
    if (trialEndsAt == null) return 0;
    final now = DateTime.now().toUtc();
    if (!now.isBefore(trialEndsAt!)) return 0;
    final remainingHours = trialEndsAt!.difference(now).inHours;
    return ((remainingHours / 24).ceil().clamp(1, 36500)) as int;
  }

  static PremiumState signedOut() {
    return const PremiumState(
      signedIn: false,
      isPremium: false,
      premiumActive: false,
      trialEndsAt: null,
      trialStartedAt: null,
      premiumSource: '',
    );
  }

  factory PremiumState.fromFirestore({
    required bool signedIn,
    required Map<String, dynamic>? data,
  }) {
    final bool isPremium = (data?['isPremium'] as bool?) ?? false;
    final DateTime? trialEndsAt =
        (data?['trialEndsAt'] as Timestamp?)?.toDate().toUtc();
    final DateTime? trialStartedAt =
        (data?['trialStartedAt'] as Timestamp?)?.toDate().toUtc();
    final String premiumSource = (data?['premiumSource'] as String?) ?? '';
    final bool trialActive =
        trialEndsAt != null && DateTime.now().toUtc().isBefore(trialEndsAt);

    return PremiumState(
      signedIn: signedIn,
      isPremium: isPremium,
      premiumActive: isPremium || trialActive,
      trialEndsAt: trialEndsAt,
      trialStartedAt: trialStartedAt,
      premiumSource: premiumSource,
    );
  }
}

class PremiumService {
  PremiumService._();
  static final PremiumService I = PremiumService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<PremiumState> watchCurrentUserPremium() async* {
    await for (final user in _auth.authStateChanges()) {
      if (user == null) {
        yield PremiumState.signedOut();
        continue;
      }

      yield* _firestore.collection('users').doc(user.uid).snapshots().map((
        doc,
      ) {
        return PremiumState.fromFirestore(
          signedIn: true,
          data: doc.data(),
        );
      });
    }
  }
}
