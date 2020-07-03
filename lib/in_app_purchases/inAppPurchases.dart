import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

final String testID = 'support';

class IAPWidget extends StatefulWidget {
  @override
  _IAPWidgetState createState() => _IAPWidgetState();
}

class _IAPWidgetState extends State<IAPWidget> {
  InAppPurchaseConnection _iap = InAppPurchaseConnection.instance;
  bool _available = true;

  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  StreamSubscription _subscription;

  @override
  void initState() {
    _initialize();
    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _initialize() async {
    _available = await _iap.isAvailable();
    if (_available) {
      List<Future> futures = [_getProducts(), _getPastPurchases()];
      await Future.wait(futures);
      _verifyPurchase();
      _subscription = _iap.purchaseUpdatedStream.listen((data) => setState(() {
            print("Supported");
            _purchases.addAll(data);
            _verifyPurchase();
          }));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Support Us'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var prod in _products) ...[
              Text(
                prod.title,
                style: Theme.of(context).textTheme.headline2,
              ),
              Text(
                prod.description,
                style: Theme.of(context).textTheme.headline3,
              ),
              Text(
                prod.price,
                style: TextStyle(color: Colors.greenAccent, fontSize: 60),
              ),
              FlatButton(
                onPressed: () {
                  _buyProduct(prod);
                },
                child: Text('Buy it'),
                color: Colors.lightGreen,
              )
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _getProducts() async {
    Set<String> ids = Set.from([testID]);
    ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    setState(() {
      _products = response.productDetails;
    });
  }

  Future<void> _getPastPurchases() async {
    QueryPurchaseDetailsResponse response = await _iap.queryPastPurchases();
    setState(() {
      _purchases = response.pastPurchases;
    });
  }

  PurchaseDetails _hasPurchased(String productID) {
    return _purchases.firstWhere((purchase) => purchase.productID == productID,
        orElse: () => null);
  }

  void _verifyPurchase() {
    PurchaseDetails purchase = _hasPurchased(testID);
    if (purchase != null && purchase.status == PurchaseStatus.purchased) {}
  }

  void _buyProduct(ProductDetails prod) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: prod);
    _iap.buyConsumable(purchaseParam: purchaseParam);
  }
}
