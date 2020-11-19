import 'dart:async';

import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

final List<String> supportPurchase = ['support', 'support_more', 'support_max'];

class StudioList extends StatefulWidget {
  const StudioList();
  @override
  _StudioListState createState() => _StudioListState();
}

class _StudioListState extends State<StudioList> {
  final InAppPurchaseConnection _iap = InAppPurchaseConnection.instance;
  bool _available = true;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  StreamSubscription _subscription;

  Future<void> _initialize() async {
    _available = await _iap.isAvailable();
    if (_available) {
      final List<Future> futures = [_getProducts(), _getPastPurchases()];
      await Future.wait(futures);
      _subscription = _iap.purchaseUpdatedStream.listen(
        (data) => setState(
          () {
            _purchases.addAll(data);
            _verifyPurchase(data[data.length - 1].productID);
          },
        ),
      );
    }
  }

  Future<void> onSupport(BuildContext context) async {
    showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(20),
          ),
        ),
        content: Container(
          height: 200,
          width: 250,
          child: Center(
            child: ListView.builder(
                itemCount: 3,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(
                      index == 0
                          ? JamIcons.coffee
                          : index == 1
                              ? Icons.fastfood
                              : JamIcons.pizza_slice,
                      color: Theme.of(context).accentColor,
                    ),
                    title: Text(
                      index == 0
                          ? "Tea"
                          : index == 1
                              ? "Burger"
                              : "Pan Pizza",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                    onTap: index == 0
                        ? () async {
                            HapticFeedback.vibrate();
                            Navigator.of(context).pop();
                            _buyProduct(_products.firstWhere(
                                (element) => element.id == 'support'));
                          }
                        : index == 1
                            ? () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();
                                _buyProduct(_products.firstWhere(
                                    (element) => element.id == 'support_more'));
                              }
                            : () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();
                                _buyProduct(_products.firstWhere(
                                    (element) => element.id == 'support_max'));
                              },
                  );
                }),
          ),
        ),
      ),
    );
  }

  Future<void> _getProducts() async {
    final Set<String> ids = Set.from(supportPurchase);
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    setState(() {
      _products = response.productDetails;
    });
  }

  Future<void> _getPastPurchases() async {
    final QueryPurchaseDetailsResponse response =
        await _iap.queryPastPurchases();
    setState(() {
      _purchases = response.pastPurchases;
    });
  }

  PurchaseDetails _hasPurchased(String productID) {
    return _purchases.firstWhere((purchase) => purchase.productID == productID,
        orElse: () => null);
  }

  void _verifyPurchase(String productID) {
    final PurchaseDetails purchase = _hasPurchased(productID);
    if (purchase != null) {
      if (purchase.status == PurchaseStatus.purchased) {
        toasts.codeSend("Thanks for your support! It means a lot.");
      }
    } else {
      toasts.error("Invalid Purchase!");
    }
  }

  void _buyProduct(ProductDetails prod) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: prod);
    _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  @override
  void initState() {
    _initialize();
    super.initState();
  }

  @override
  void dispose() {
    if (_subscription != null) _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
            leading: const Icon(
              JamIcons.coffee,
            ),
            title: Text(
              "Buy us a cup of tea",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Support us if you like what we do",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              onSupport(context);
            }),
      ],
    );
  }
}
