// This file has been superseded by premium_screen.dart (Orbit-inspired redesign).
// Its contents are preserved below for reference.
/*
import 'dart:math';

import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

final _purchasesService = PurchasesService.instance;

Future<bool> onWillPop() async {
  popNavStackIfPossible();
  return true;
}

class UpgradeScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  bool _offeringsError = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _customerInfo = null;
      _offerings = null;
      _offeringsError = false;
    });

    await _purchasesService.ensureConfigured(globals.prismUser.id);

    CustomerInfo? customerInfo;
    try {
      customerInfo = await Purchases.getCustomerInfo();
    } on PlatformException catch (e) {
      logger.d('getCustomerInfo failed: $e');
    }

    Offerings? offerings;
    try {
      offerings = await _purchasesService.getOfferings();
    } on PlatformException catch (e) {
      logger.d('getOfferings failed: $e');
    }

    if (!mounted) return;

    setState(() {
      _customerInfo = customerInfo;
      _offerings = offerings;
      _offeringsError = offerings == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_customerInfo == null) {
      return PopScope(
        onPopInvokedWithResult: (_, __) => onWillPop(),
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: Center(child: Loader()),
        ),
      );
    }

    final isPremium = _purchasesService.isPremiumFromCustomerInfo(_customerInfo!);
    globals.prismUser.premium = isPremium;
    main.prefs.put(main.userHiveKey, globals.prismUser);

    if (isPremium) {
      return ProScreen();
    }

    return UpsellScreen(
      offerings: _offerings,
      offeringsError: _offeringsError,
      onRetry: _fetchData,
      onPremiumUnlocked: _fetchData,
    );
  }
}

class UpsellScreen extends StatefulWidget {
  final Offerings? offerings;
  final bool offeringsError;
  final VoidCallback onRetry;
  final VoidCallback onPremiumUnlocked;

  const UpsellScreen({
    super.key,
    required this.offerings,
    required this.offeringsError,
    required this.onRetry,
    required this.onPremiumUnlocked,
  });

  @override
  _UpsellScreenState createState() => _UpsellScreenState();
}

class _UpsellScreenState extends State<UpsellScreen> {
  // Horizontal scroll controller for the feature chips row
  final ScrollController _chipScrollController = ScrollController();
  // Main page scroll controller — drives the parallax hero
  final ScrollController _mainScrollController = ScrollController();
  double _scrollOffset = 0;
  int _selectedIndex = 0;
  late List<Widget> features;

  @override
  void initState() {
    super.initState();
    features = [
      const SizedBox(width: 30),
      const FeatureChip(icon: JamIcons.picture, text: "Exclusive wallpapers"),
      const FeatureChip(icon: JamIcons.picture, text: "Upload unlimited walls"),
      const FeatureChip(icon: JamIcons.instant_picture, text: "No restrictions on setups"),
      const FeatureChip(icon: JamIcons.trophy, text: "Premium only giveaways"),
      const FeatureChip(icon: JamIcons.filter, text: "Apply filters on walls"),
      const FeatureChip(icon: JamIcons.user, text: "Unique PRO badge on your profile"),
      const FeatureChip(icon: JamIcons.upload, text: "Faster upload reviews"),
      const FeatureChip(icon: JamIcons.stop_sign, text: "Remove Ads"),
      const FeatureChip(icon: JamIcons.coffee_cup, text: "Support development, and content growth"),
    ];
    _mainScrollController.addListener(() {
      if (mounted) {
        setState(() => _scrollOffset = _mainScrollController.offset);
      }
    });
    // Pre-select annual if available, otherwise first package
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final offering = widget.offerings?.all[PurchaseConstants.offeringUltra] ?? widget.offerings?.current;
      if (offering != null && offering.availablePackages.isNotEmpty) {
        final idx = offering.availablePackages.indexWhere((p) => p.packageType == PackageType.annual);
        if (idx >= 0) {
          setState(() => _selectedIndex = idx);
        }
      }
    });
  }

  @override
  void dispose() {
    _chipScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offeringsError || widget.offerings == null) {
      return PopScope(
        onPopInvokedWithResult: (_, __) => onWillPop(),
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Unable to load offerings",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    widget.onRetry();
                  },
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Prefer 'ultra' (subscriptions) by explicit key so the new release always shows
    // monthly + annual packages regardless of what RC marks as is_current.
    // Falls back to the RC current offering as a safety net.
    final offering = widget.offerings!.all[PurchaseConstants.offeringUltra] ?? widget.offerings!.current;
    if (offering == null || offering.availablePackages.isEmpty) {
      return PopScope(
        onPopInvokedWithResult: (_, __) => onWillPop(),
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "No packages available",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: widget.onRetry,
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final packages = offering.availablePackages;
    final selectedPackage = packages[_selectedIndex.clamp(0, packages.length - 1)];

    return PopScope(
      onPopInvokedWithResult: (_, __) => onWillPop(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.error, Theme.of(context).primaryColor],
            stops: const [0.1, 0.6],
          ),
        ),
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SingleChildScrollView(
              controller: _mainScrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroParallaxZone(scrollOffset: _scrollOffset),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(width: 40, height: 40, child: Image.asset("assets/images/prism.png")),
                            const SizedBox(width: 10),
                            Text(
                              "Premium",
                              style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Unlock everything",
                          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                                color: const Color(0xFFE57697),
                              ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 58,
                          child: ListView(
                            controller: _chipScrollController,
                            scrollDirection: Axis.horizontal,
                            children: features,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: List.generate(
                            packages.length,
                            (i) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i < packages.length - 1 ? 12 : 0),
                                child: _PackagePill(
                                  package: packages[i],
                                  isSelected: _selectedIndex == i,
                                  onTap: () => setState(() => _selectedIndex = i),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_perMonthEquivalent(selectedPackage) != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_perMonthEquivalent(selectedPackage)!} when billed ${_packageTypeLabel(selectedPackage.packageType).toLowerCase()}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        PurchaseButton(
                          package: selectedPackage,
                          onPremiumUnlocked: widget.onPremiumUnlocked,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => launchUrl(
                                Uri.parse(PurchaseConstants.termsOfUseUrl),
                              ),
                              child: Text(
                                'Terms of Use',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                    ),
                              ),
                            ),
                            Text(
                              '  ·  ',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                  ),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  logger.d('Restoring purchases');
                                  final customerInfo = await _purchasesService.restore();
                                  if (!context.mounted) return;
                                  final isPremium = _purchasesService.isPremiumFromCustomerInfo(customerInfo);
                                  await _purchasesService.checkAndPersistPremium();
                                  if (isPremium) {
                                    toasts.codeSend("You are now a premium member.");
                                    widget.onPremiumUnlocked();
                                  } else {
                                    toasts.error("There was an error. Please try again later.");
                                  }
                                } on PlatformException catch (e) {
                                  final errorCode = PurchasesErrorHelper.getErrorCode(e);
                                  if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
                                    toasts.error("User cancelled purchase.");
                                  } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
                                    toasts.error("User not allowed to purchase.");
                                  } else {
                                    toasts.error(e.toString());
                                  }
                                }
                              },
                              child: Text(
                                'Restore',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _packageTypeLabel(PackageType type) {
  switch (type) {
    case PackageType.lifetime:
      return 'Lifetime';
    case PackageType.annual:
      return 'Annual';
    case PackageType.monthly:
      return 'Monthly';
    case PackageType.weekly:
      return 'Weekly';
    case PackageType.sixMonth:
      return '6 Months';
    case PackageType.threeMonth:
      return '3 Months';
    case PackageType.twoMonth:
      return '2 Months';
    default:
      return 'Premium';
  }
}

String _currencySymbol(String currencyCode) {
  const symbols = {
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'JPY': '¥',
  };
  return symbols[currencyCode] ?? currencyCode;
}

String? _perMonthEquivalent(Package package) {
  final months = switch (package.packageType) {
    PackageType.annual => 12,
    PackageType.sixMonth => 6,
    PackageType.threeMonth => 3,
    PackageType.twoMonth => 2,
    _ => null,
  };
  if (months == null) return null;
  final perMonth = package.storeProduct.price / months;
  final currency = package.storeProduct.currencyCode;
  return '${NumberFormat.currency(
        symbol: _currencySymbol(currency),
        decimalDigits: 0,
      ).format(perMonth)}/mo';
}

bool _hasSaleOrIntroOffer(Package package) {
  final intro = package.storeProduct.introductoryPrice;
  final title = package.storeProduct.title.toLowerCase();
  return (intro != null) || title.contains('sale');
}

class _PackagePill extends StatelessWidget {
  final Package package;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackagePill({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = _packageTypeLabel(package.packageType);
    final hasSale = _hasSaleOrIntroOffer(package);
    final isAnnual = package.packageType == PackageType.annual;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (colorScheme.error == Colors.black ? colorScheme.secondary : colorScheme.error)
              : Colors.white10,
          border: Border.all(
            color: isSelected
                ? (colorScheme.error == Colors.black ? colorScheme.secondary : colorScheme.error)
                : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.secondary,
                      ),
                ),
                if (isAnnual) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'BEST',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                  ),
                ],
                if (hasSale) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SALE',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              package.storeProduct.priceString,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: colorScheme.secondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class PurchaseButton extends StatefulWidget {
  final Package package;
  final VoidCallback onPremiumUnlocked;

  const PurchaseButton({super.key, required this.package, required this.onPremiumUnlocked});

  @override
  _PurchaseButtonState createState() => _PurchaseButtonState();
}

class _PurchaseButtonState extends State<PurchaseButton> {
  bool _isPurchasing = false;

  Future<void> _purchase() async {
    if (_isPurchasing) return;

    setState(() => _isPurchasing = true);

    try {
      final customerInfo = await _purchasesService.purchase(widget.package);
      if (!mounted) return;

      final isPremium = _purchasesService.isPremiumFromCustomerInfo(customerInfo);
      await _purchasesService.checkAndPersistPremium();

      if (isPremium) {
        toasts.codeSend("You are now a premium member.");
        widget.onPremiumUnlocked();
      } else {
        toasts.error("There was an error, please try again later.");
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        toasts.error("User cancelled purchase.");
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        toasts.error("User not allowed to purchase.");
      } else {
        toasts.error(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = 'Get ${_packageTypeLabel(widget.package.packageType)} for ${widget.package.storeProduct.priceString}';

    return GestureDetector(
      onTap: _isPurchasing ? null : _purchase,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error == Colors.black
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(500),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: _isPurchasing
            ? const Center(
                child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator()),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
      ),
    );
  }
}

class ProScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) => onWillPop(),
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Icon(
                  Icons.star,
                  color: Theme.of(context).colorScheme.error,
                  size: 44.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(
                  "You are a Prism Premium user.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(
                  "You can use the app in all its functionality.\n\nPlease contact us at hash.studios.inc@gmail.com if you have any problem.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ).copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Parallax hero zone — background image + 3 floating wallpaper cards
// ---------------------------------------------------------------------------

class _HeroParallaxZone extends StatefulWidget {
  final double scrollOffset;

  const _HeroParallaxZone({required this.scrollOffset});

  @override
  State<_HeroParallaxZone> createState() => _HeroParallaxZoneState();
}

class _HeroParallaxZoneState extends State<_HeroParallaxZone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _driftCtrl;

  // (left %, top %, phase in radians)
  static const List<(double, double, double)> _cardConfig = [
    (0.06, 0.12, 0.0),
    (0.38, 0.30, 2 * pi / 3),
    (0.65, 0.08, 4 * pi / 3),
  ];

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    super.dispose();
  }

  Widget _wallpaperCard(String url) {
    return Container(
      width: 72,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.white12),
          errorWidget: (_, __, ___) => Container(color: Colors.white12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final heroH = screenH * 0.40;
    // Oversized background avoids blank edges when parallax-shifted
    final bgH = heroH * 1.30;

    final urls = PurchaseConstants.previewWallpaperUrls;

    return ClipRect(
      child: SizedBox(
        height: heroH,
        width: screenW,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ----- background (parallax shift up as user scrolls down) -----
            Positioned(
              top: -(bgH - heroH) / 2 - widget.scrollOffset * 0.35,
              left: 0,
              right: 0,
              child: SizedBox(
                height: bgH,
                child: CachedNetworkImage(
                  imageUrl: PurchaseConstants.defaultHeroImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black),
                  errorWidget: (_, __, ___) => Container(color: Colors.black),
                ),
              ),
            ),

            // ----- floating wallpaper cards -----
            ...List.generate(_cardConfig.length, (i) {
              final (leftFrac, topFrac, phase) = _cardConfig[i];
              return AnimatedBuilder(
                animation: _driftCtrl,
                builder: (_, child) {
                  final t = _driftCtrl.value * 2 * pi + phase;
                  return Positioned(
                    left: screenW * leftFrac + sin(t) * 6,
                    top: heroH * topFrac + sin(t) * 14,
                    child: Transform.rotate(
                      angle: sin(t) * 0.06,
                      child: child,
                    ),
                  );
                },
                child: _wallpaperCard(urls[i % urls.length]),
              );
            }),

            // ----- bottom gradient fade into the page background -----
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: heroH * 0.45,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
                        Theme.of(context).primaryColor,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureChip({required this.icon, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
      child: ActionChip(
        backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        labelPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        avatar: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8.0),
          child: Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        label: Text(
          " $text",
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
        ),
        onPressed: () {},
      ),
    );
  }
}
*/
