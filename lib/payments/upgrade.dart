import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ScrollController _scrollController = ScrollController();
  late List<Widget> features;

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

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
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

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
              child: SizedBox(
                height: MediaQuery.of(context).size.height - (globals.notchSize ?? 24),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 420,
                      width: MediaQuery.of(context).size.width,
                      child: CachedNetworkImage(
                        imageUrl: PurchaseConstants.defaultHeroImageUrl,
                        fit: BoxFit.fitHeight,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Spacer(flex: 12),
                        Row(
                          children: [
                            const SizedBox(width: 30),
                            SizedBox(width: 40, height: 40, child: Image.asset("assets/images/prism.png")),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Premium",
                                style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(width: 30),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                "Unlock everything",
                                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                                      color: const Color(0xFFE57697),
                                    ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                          width: MediaQuery.of(context).size.width,
                          height: 58,
                          child: GestureDetector(
                            onTap: _scrollToBottom,
                            child: ListView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              children: features,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ...offering.availablePackages.map(
                          (package) => _PackageCard(
                            package: package,
                            onPremiumUnlocked: widget.onPremiumUnlocked,
                          ),
                        ),
                        _RestoreButton(onPremiumUnlocked: widget.onPremiumUnlocked),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.8,
                          child: Text(
                            "By purchasing this product you will be able to access the Prism premium functionalities on all the devices logged into your Google account.",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
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

bool _hasSaleOrIntroOffer(Package package) {
  final intro = package.storeProduct.introductoryPrice;
  final title = package.storeProduct.title.toLowerCase();
  return (intro != null) || title.contains('sale');
}

class _PackageCard extends StatelessWidget {
  final Package package;
  final VoidCallback onPremiumUnlocked;

  const _PackageCard({required this.package, required this.onPremiumUnlocked});

  @override
  Widget build(BuildContext context) {
    final label = _packageTypeLabel(package.packageType);
    final hasSale = _hasSaleOrIntroOffer(package);

    return Column(
      children: [
        Container(
          width: MediaQuery.of(context).size.width * 0.8,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.error == Colors.black
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.error,
              width: 4,
            ),
            color: const Color(0x15ffffff),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (hasSale)
                    Text(
                      'SALE',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
              const Spacer(flex: 4),
              Text(
                package.storeProduct.priceString,
                style: Theme.of(context).textTheme.displaySmall!.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
        PurchaseButton(
          package: package,
          onPremiumUnlocked: onPremiumUnlocked,
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 18.0),
      child: GestureDetector(
        onTap: _isPurchasing ? null : _purchase,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error == Colors.black
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(500),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _isPurchasing
              ? const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator()))
              : Text(
                  'Purchase',
                  style: Theme.of(context).textTheme.displaySmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}

class _RestoreButton extends StatelessWidget {
  final VoidCallback onPremiumUnlocked;

  const _RestoreButton({required this.onPremiumUnlocked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18.0),
      child: GestureDetector(
        onTap: () async {
          try {
            logger.d('Restoring purchases');
            final customerInfo = await _purchasesService.restore();
            if (!context.mounted) return;

            final isPremium = _purchasesService.isPremiumFromCustomerInfo(customerInfo);
            await _purchasesService.checkAndPersistPremium();

            if (isPremium) {
              toasts.codeSend("You are now a premium member.");
              onPremiumUnlocked();
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
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error == Colors.black
                ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(500),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            'Restore',
            style: Theme.of(context).textTheme.displaySmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.error == Colors.black
                      ? Colors.white
                      : Theme.of(context).primaryColor,
                ),
            textAlign: TextAlign.center,
          ),
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
