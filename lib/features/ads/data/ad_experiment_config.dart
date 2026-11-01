import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AdExperimentFormat { native, banner, interstitial }

class AdExperimentConfig {
  const AdExperimentConfig({
    required this.version,
    required this.nativeEnabled,
    required this.bannerEnabled,
    required this.interstitialEnabled,
    this.androidNativeId = '',
    this.iosNativeId = '',
    this.androidBannerId = '',
    this.iosBannerId = '',
    this.androidInterstitialId = '',
    this.iosInterstitialId = '',
  });

  static const String remoteConfigKey = 'ad_experiments_v1';
  static const AdExperimentConfig disabled = AdExperimentConfig(
    version: '',
    nativeEnabled: false,
    bannerEnabled: false,
    interstitialEnabled: false,
  );

  final String version;
  final bool nativeEnabled;
  final bool bannerEnabled;
  final bool interstitialEnabled;
  final String androidNativeId;
  final String iosNativeId;
  final String androidBannerId;
  final String iosBannerId;
  final String androidInterstitialId;
  final String iosInterstitialId;

  String unitId(AdExperimentFormat format, {required bool android, bool isRelease = kReleaseMode}) {
    final id = switch ((format, android)) {
      (AdExperimentFormat.native, true) => androidNativeId,
      (AdExperimentFormat.native, false) => iosNativeId,
      (AdExperimentFormat.banner, true) => androidBannerId,
      (AdExperimentFormat.banner, false) => iosBannerId,
      (AdExperimentFormat.interstitial, true) => androidInterstitialId,
      (AdExperimentFormat.interstitial, false) => iosInterstitialId,
    };
    if (id.startsWith('ca-app-pub-3940256099942544/')) return '';
    if (!RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(id)) return '';
    if (isRelease) return id;
    final suffix = switch ((format, android)) {
      (AdExperimentFormat.native, true) => '2247696110',
      (AdExperimentFormat.native, false) => '3986624511',
      (AdExperimentFormat.banner, true) => '6300978111',
      (AdExperimentFormat.banner, false) => '2934735716',
      (AdExperimentFormat.interstitial, true) => '1033173712',
      (AdExperimentFormat.interstitial, false) => '4411468910',
    };
    return 'ca-app-pub-3940256099942544/$suffix';
  }

  bool enabled(AdExperimentFormat format) => switch (format) {
    AdExperimentFormat.native => nativeEnabled,
    AdExperimentFormat.banner => bannerEnabled,
    AdExperimentFormat.interstitial => interstitialEnabled,
  };

  factory AdExperimentConfig.parse(String raw) {
    try {
      final Object? value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) return disabled;
      final Object? version = value['version'];
      final Object? native = value['native'];
      final Object? banner = value['banner'];
      final Object? interstitial = value['interstitial'];
      if (version is! String ||
          version.trim().isEmpty ||
          version.length > 64 ||
          native is! bool ||
          banner is! bool ||
          interstitial is! bool) {
        return disabled;
      }
      return AdExperimentConfig(
        version: version,
        nativeEnabled: native,
        bannerEnabled: banner,
        interstitialEnabled: interstitial,
        androidNativeId: value['android_native_id'] is String ? value['android_native_id'] as String : '',
        iosNativeId: value['ios_native_id'] is String ? value['ios_native_id'] as String : '',
        androidBannerId: value['android_banner_id'] is String ? value['android_banner_id'] as String : '',
        iosBannerId: value['ios_banner_id'] is String ? value['ios_banner_id'] as String : '',
        androidInterstitialId: value['android_interstitial_id'] is String
            ? value['android_interstitial_id'] as String
            : '',
        iosInterstitialId: value['ios_interstitial_id'] is String ? value['ios_interstitial_id'] as String : '',
      );
    } on FormatException {
      return disabled;
    }
  }
}
