import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ---------------------------------------------------------------------------
// Service shorthand
// ---------------------------------------------------------------------------

final _purchasesService = PurchasesService.instance;

// ---------------------------------------------------------------------------
// Feature data model
// ---------------------------------------------------------------------------

class _FeatureData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureData(this.icon, this.color, this.title, this.subtitle);
}

const List<_FeatureData> _features = [
  _FeatureData(
    JamIcons.picture,
    Colors.pink,
    'Exclusive wallpapers',
    'Browse and download curated wallpapers available only to Prism Premium members',
  ),
  _FeatureData(
    JamIcons.picture,
    Colors.orange,
    'Upload unlimited walls',
    'Share as many wallpapers as you want with the Prism community, no upload limits',
  ),
  _FeatureData(
    JamIcons.instant_picture,
    Color(0xFFCDA000),
    'No restrictions on setups',
    'Create and share setups without any limitations on content or frequency',
  ),
  _FeatureData(
    JamIcons.trophy,
    Colors.amber,
    'Premium-only giveaways',
    'Be entered into exclusive contests and giveaways reserved for Premium members',
  ),
  _FeatureData(
    JamIcons.filter,
    Colors.green,
    'Apply filters on walls',
    'Enhance any wallpaper with a rich set of color and photo filters before setting it',
  ),
  _FeatureData(
    JamIcons.user,
    Colors.blue,
    'PRO badge on your profile',
    'Stand out in the community with a distinctive PRO badge displayed on your profile',
  ),
  _FeatureData(
    JamIcons.upload,
    Colors.indigo,
    'Faster upload reviews',
    'Your uploads get reviewed and published with priority over regular members',
  ),
  _FeatureData(
    JamIcons.stop_sign,
    Colors.purple,
    'Remove Ads',
    'Enjoy a completely ad-free experience throughout the entire app',
  ),
  _FeatureData(
    JamIcons.coffee_cup,
    Colors.deepPurple,
    'Support development',
    'Your subscription directly funds new features, content, and the Prism community',
  ),
];

// ---------------------------------------------------------------------------
// Helpers (mirrors the ones in upgrade.dart)
// ---------------------------------------------------------------------------

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

String _currencySymbol(String code) {
  const symbols = {'INR': '₹', 'USD': '\$', 'EUR': '€', 'GBP': '£', 'AUD': 'A\$', 'CAD': 'C\$', 'JPY': '¥'};
  return symbols[code] ?? code;
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
  return '${NumberFormat.currency(symbol: _currencySymbol(currency), decimalDigits: 0).format(perMonth)}/mo';
}

bool _hasSaleOrIntroOffer(Package package) {
  final intro = package.storeProduct.introductoryPrice;
  final title = package.storeProduct.title.toLowerCase();
  return (intro != null) || title.contains('sale');
}

// ---------------------------------------------------------------------------
// PremiumScreen — top-level entry point (replaces UpgradeScreen)
// ---------------------------------------------------------------------------

class PremiumScreen extends StatefulWidget {
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  bool _offeringsError = false;

  Future<void> _syncPremiumState(CustomerInfo? info) async {
    if (info == null) {
      return;
    }
    final tier = _purchasesService.tierFromCustomerInfo(info);
    await app_state.patchPrismUser(premium: tier.isPaid, subscriptionTier: tier.value);
  }

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

    await _purchasesService.ensureConfigured(app_state.prismUser.id);

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

    await _syncPremiumState(customerInfo);

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
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: Center(child: Loader()),
        ),
      );
    }

    final isPremium = _purchasesService.isPremiumFromCustomerInfo(_customerInfo!);

    // Derive expiry / renewal date from active entitlement
    String? expiryDateLabel;
    if (isPremium) {
      final ultra = _customerInfo!.entitlements.active[PurchaseConstants.entitlementUltra];
      final premium = _customerInfo!.entitlements.active[PurchaseConstants.entitlementPremium];
      final ent = ultra ?? premium;
      if (ent != null && ent.expirationDate != null) {
        final willRenew = ent.willRenew;
        final dt = DateTime.tryParse(ent.expirationDate!);
        if (dt != null) {
          final formatted = DateFormat('d MMMM yyyy').format(dt.toLocal());
          expiryDateLabel = '${willRenew ? 'RENEWS' : 'EXPIRES'} ON $formatted';
        }
      }
    }

    return _PremiumUpsellScreen(
      isPremium: isPremium,
      expiryDateLabel: expiryDateLabel,
      offerings: _offerings,
      offeringsError: _offeringsError,
      onRetry: _fetchData,
      onPremiumUnlocked: _fetchData,
    );
  }
}

// ---------------------------------------------------------------------------
// _PremiumUpsellScreen — main UI
// ---------------------------------------------------------------------------

class _PremiumUpsellScreen extends StatefulWidget {
  final bool isPremium;
  final String? expiryDateLabel;
  final Offerings? offerings;
  final bool offeringsError;
  final VoidCallback onRetry;
  final VoidCallback onPremiumUnlocked;

  const _PremiumUpsellScreen({
    required this.isPremium,
    required this.expiryDateLabel,
    required this.offerings,
    required this.offeringsError,
    required this.onRetry,
    required this.onPremiumUnlocked,
  });

  @override
  State<_PremiumUpsellScreen> createState() => _PremiumUpsellScreenState();
}

class _PremiumUpsellScreenState extends State<_PremiumUpsellScreen> {
  int _selectedIndex = 0;

  void _onPackageSelected(int index, List<Package> packages) {
    if (index < 0 || index >= packages.length) {
      return;
    }
    final Package selectedPackage = packages[index];
    setState(() => _selectedIndex = index);
    analytics.logEvent(
      name: 'subscription_package_selected',
      parameters: <String, Object>{
        'source': 'premium_screen',
        'product_id': selectedPackage.storeProduct.identifier,
        'package_type': selectedPackage.packageType.name,
        'price': selectedPackage.storeProduct.price,
        'currency': selectedPackage.storeProduct.currencyCode,
      },
    );
  }

  List<Package> _packages() {
    if (widget.offerings == null) return const [];
    final offering =
        widget.offerings!.all[PurchaseConstants.offeringV3Default] ??
        widget.offerings!.all[PurchaseConstants.offeringUltra] ??
        widget.offerings!.current;
    return offering?.availablePackages ?? const [];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pkgs = _packages();
      if (pkgs.isNotEmpty) {
        final idx = pkgs.indexWhere((p) => p.packageType == PackageType.annual);
        if (idx >= 0) setState(() => _selectedIndex = idx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final packages = _packages();
    final selectedPackage = packages.isNotEmpty ? packages[_selectedIndex.clamp(0, packages.length - 1)] : null;

    return PopScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        // Sticky purchase CTA
        bottomSheet: _StickyBottomSheet(
          isPremium: widget.isPremium,
          selectedPackage: selectedPackage,
          onPremiumUnlocked: widget.onPremiumUnlocked,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              // Header: "UPGRADE TO / PRISM PREMIUM / AND UNLOCK EVERY FEATURE"
              _UpgradeHeader(isPremium: widget.isPremium, expiryDateLabel: widget.expiryDateLabel),
              const SizedBox(height: 20),
              const _StarDivider(),
              // Package pills — hidden when already premium or no offerings
              if (!widget.isPremium && packages.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _PackagePillRow(
                    packages: packages,
                    selectedIndex: _selectedIndex,
                    onTap: (i) => _onPackageSelected(i, packages),
                  ),
                ),
                if (selectedPackage != null && _perMonthEquivalent(selectedPackage) != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Text(
                      '${_perMonthEquivalent(selectedPackage)!} when billed '
                      '${_packageTypeLabel(selectedPackage.packageType).toLowerCase()}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const _StarDivider(),
              ],
              // Offerings error / no packages warning (non-premium only)
              if (!widget.isPremium && (widget.offeringsError || packages.isEmpty)) ...[
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Text(
                        widget.offeringsError ? 'Unable to load packages' : 'No packages available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _StarDivider(),
              ],
              const SizedBox(height: 8),
              // Feature list
              _FeatureSection(isPremium: widget.isPremium),
              // Bottom padding to clear the sticky sheet
              const SizedBox(height: 180),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _UpgradeHeader
// ---------------------------------------------------------------------------

class _UpgradeHeader extends StatelessWidget {
  final bool isPremium;
  final String? expiryDateLabel;

  const _UpgradeHeader({required this.isPremium, this.expiryDateLabel});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: secondary.withValues(alpha: 0.6),
      letterSpacing: 1.2,
      wordSpacing: 2,
      fontWeight: FontWeight.w300,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(isPremium ? 'UPGRADED TO' : 'UPGRADE TO', textAlign: TextAlign.center, style: labelStyle),
          const SizedBox(height: 6),
          ShaderMask(
            shaderCallback: (bounds) =>
                const LinearGradient(colors: [Color(0xFFE57697), Colors.white]).createShader(bounds),
            child: Text(
              'PRISM PREMIUM',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white, // required for ShaderMask to work
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPremium ? (expiryDateLabel ?? 'ACTIVE SUBSCRIPTION') : 'AND UNLOCK EVERY FEATURE',
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StarDivider
// ---------------------------------------------------------------------------

class _StarDivider extends StatelessWidget {
  const _StarDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.25);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.star, size: 14, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4)),
          ),
          Expanded(child: Divider(color: color)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PackagePillRow
// ---------------------------------------------------------------------------

class _PackagePillRow extends StatelessWidget {
  final List<Package> packages;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _PackagePillRow({required this.packages, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(packages.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < packages.length - 1 ? 12 : 0),
            child: _PackagePill(package: packages[i], isSelected: selectedIndex == i, onTap: () => onTap(i)),
          ),
        );
      }),
    );
  }
}

class _PackagePill extends StatelessWidget {
  final Package package;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackagePill({required this.package, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = _packageTypeLabel(package.packageType);
    final hasSale = _hasSaleOrIntroOffer(package);
    final isAnnual = package.packageType == PackageType.annual;
    final cs = Theme.of(context).colorScheme;
    final accentColor = cs.error == Colors.black ? cs.secondary : cs.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white10,
          border: Border.all(color: isSelected ? accentColor : Colors.white24, width: isSelected ? 2 : 1),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.secondary),
                ),
                if (isAnnual) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      'BEST',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ],
                if (hasSale) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      'SALE',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              package.storeProduct.priceString,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FeatureSection
// ---------------------------------------------------------------------------

class _FeatureSection extends StatelessWidget {
  final bool isPremium;

  const _FeatureSection({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return CupertinoListSection.insetGrouped(
      backgroundColor: Theme.of(context).primaryColor,
      header: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isPremium ? 'UNLOCKED FEATURES' : 'FEATURES',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 14,
              letterSpacing: 1.2,
              wordSpacing: 2,
              color: secondary.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: secondary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
      dividerMargin: 0,
      children: _features.map((f) => _FeatureTile(data: f)).toList(),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final _FeatureData data;

  const _FeatureTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return CupertinoListTile(
      backgroundColor: Colors.transparent,
      backgroundColorActivated: secondary.withValues(alpha: 0.08),
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: data.color, borderRadius: BorderRadius.circular(7)),
        child: Icon(data.icon, size: 16, color: Colors.white),
      ),
      title: Text(
        data.title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: secondary),
      ),
      subtitle: Text(
        data.subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondary.withValues(alpha: 0.6), height: 1.4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StickyBottomSheet
// ---------------------------------------------------------------------------

class _StickyBottomSheet extends StatelessWidget {
  final bool isPremium;
  final Package? selectedPackage;
  final VoidCallback onPremiumUnlocked;

  const _StickyBottomSheet({required this.isPremium, required this.selectedPackage, required this.onPremiumUnlocked});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        border: Border(top: BorderSide(color: secondary.withValues(alpha: 0.12))),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      child: isPremium
          ? Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Theme.of(context).colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "You're on Prism Premium",
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: secondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedPackage != null)
                  _PurchaseCTAButton(package: selectedPackage!, onPremiumUnlocked: onPremiumUnlocked)
                else
                  const SizedBox(height: 52),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(PurchaseConstants.termsOfUseUrl)),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      child: Text(
                        'Terms of Use',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: secondary.withValues(alpha: 0.55)),
                      ),
                    ),
                    Text(
                      '·',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondary.withValues(alpha: 0.4)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () async {
                        analytics.logEvent(
                          name: 'subscription_restore_started',
                          parameters: <String, Object>{'source': 'premium_screen'},
                        );
                        try {
                          logger.d('Restoring purchases');
                          final info = await _purchasesService.restore();
                          if (!context.mounted) return;
                          final ok = _purchasesService.isPremiumFromCustomerInfo(info);
                          await _purchasesService.checkAndPersistPremium(
                            conversionContext: const SubscriptionConversionContext(
                              source: 'premium_screen_restore',
                              productId: 'unknown_product',
                              packageType: 'restore',
                              currency: 'unknown_currency',
                              price: 0,
                            ),
                          );
                          analytics.logEvent(
                            name: 'subscription_restore_result',
                            parameters: <String, Object>{
                              'source': 'premium_screen',
                              'result': ok ? 'success' : 'not_entitled',
                            },
                          );
                          if (ok) {
                            toasts.codeSend('You are now a premium member.');
                            onPremiumUnlocked();
                          } else {
                            toasts.error('There was an error. Please try again later.');
                          }
                        } on PlatformException catch (e) {
                          analytics.logEvent(
                            name: 'subscription_restore_result',
                            parameters: <String, Object>{
                              'source': 'premium_screen',
                              'result': 'failure',
                              'error_code': e.code,
                              'error_message': e.message ?? '',
                            },
                          );
                          final code = PurchasesErrorHelper.getErrorCode(e);
                          if (code == PurchasesErrorCode.purchaseCancelledError) {
                            toasts.error('User cancelled.');
                          } else if (code == PurchasesErrorCode.purchaseNotAllowedError) {
                            toasts.error('Purchase not allowed.');
                          } else {
                            toasts.error(e.toString());
                          }
                        }
                      },
                      child: Text(
                        'Restore',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: secondary.withValues(alpha: 0.55)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PurchaseCTAButton
// ---------------------------------------------------------------------------

class _PurchaseCTAButton extends StatefulWidget {
  final Package package;
  final VoidCallback onPremiumUnlocked;

  const _PurchaseCTAButton({required this.package, required this.onPremiumUnlocked});

  @override
  State<_PurchaseCTAButton> createState() => _PurchaseCTAButtonState();
}

class _PurchaseCTAButtonState extends State<_PurchaseCTAButton> {
  bool _isPurchasing = false;

  Future<void> _purchase() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);
    analytics.logEvent(
      name: 'subscription_purchase_started',
      parameters: <String, Object>{
        'source': 'premium_screen',
        'product_id': widget.package.storeProduct.identifier,
        'package_type': widget.package.packageType.name,
        'price': widget.package.storeProduct.price,
        'currency': widget.package.storeProduct.currencyCode,
      },
    );
    try {
      final customerInfo = await _purchasesService.purchase(widget.package);
      if (!mounted) return;
      final isPremium = _purchasesService.isPremiumFromCustomerInfo(customerInfo);
      await _purchasesService.checkAndPersistPremium(
        conversionContext: SubscriptionConversionContext(
          source: 'premium_screen',
          productId: widget.package.storeProduct.identifier,
          packageType: widget.package.packageType.name,
          price: widget.package.storeProduct.price,
          currency: widget.package.storeProduct.currencyCode,
        ),
      );
      analytics.logEvent(
        name: 'subscription_purchase_result',
        parameters: <String, Object>{
          'source': 'premium_screen',
          'product_id': widget.package.storeProduct.identifier,
          'package_type': widget.package.packageType.name,
          'result': isPremium ? 'success' : 'not_entitled',
        },
      );
      if (isPremium) {
        toasts.codeSend('You are now a premium member.');
        widget.onPremiumUnlocked();
      } else {
        toasts.error('There was an error, please try again later.');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      analytics.logEvent(
        name: 'subscription_purchase_result',
        parameters: <String, Object>{
          'source': 'premium_screen',
          'product_id': widget.package.storeProduct.identifier,
          'package_type': widget.package.packageType.name,
          'result': 'failure',
          'error_code': e.code,
          'error_message': e.message ?? '',
        },
      );
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        toasts.error('User cancelled purchase.');
      } else if (code == PurchasesErrorCode.purchaseNotAllowedError) {
        toasts.error('User not allowed to purchase.');
      } else {
        toasts.error(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = cs.error == Colors.black ? cs.secondary : cs.error;
    final label = 'Get ${_packageTypeLabel(widget.package.packageType)} for ${widget.package.storeProduct.priceString}';

    return GestureDetector(
      onTap: _isPurchasing ? null : _purchase,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(500)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: _isPurchasing
            ? const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20, color: Theme.of(context).primaryColor),
                ],
              ),
      ),
    );
  }
}
