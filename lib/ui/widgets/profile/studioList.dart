import 'dart:async';

import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

final List<String> supportPurchase = ['support', 'support_more', 'support_max'];

class StudioList extends StatefulWidget {
  final ScrollController scrollController;
  StudioList({this.scrollController});
  @override
  _StudioListState createState() => _StudioListState();
}

class _StudioListState extends State<StudioList> {
  InAppPurchaseConnection _iap = InAppPurchaseConnection.instance;
  bool _available = true;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  StreamSubscription _subscription;

  void _initialize() async {
    _available = await _iap.isAvailable();
    if (_available) {
      List<Future> futures = [_getProducts(), _getPastPurchases()];
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

  void onSupport(BuildContext context) async {
    showDialog(
      context: context,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
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
                          : index == 1 ? Icons.fastfood : JamIcons.pizza_slice,
                      color: Theme.of(context).accentColor,
                    ),
                    title: Text(
                      index == 0 ? "Tea" : index == 1 ? "Burger" : "Pan Pizza",
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
    Set<String> ids = Set.from(supportPurchase);
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

  void _verifyPurchase(String productID) {
    PurchaseDetails purchase = _hasPurchased(productID);
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hash Studios',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).accentColor,
              ),
            ),
          ),
        ),
        ListTile(
            leading: Icon(
              JamIcons.luggage,
            ),
            title: new Text(
              "Wanna work with us?",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "We are recruiting Flutter developers",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              launch("https://forms.gle/nSt4QtiQVVaZvhdA8");
            }),
        ListTile(
            leading: Icon(
              JamIcons.coffee,
            ),
            title: new Text(
              "Buy us a cup of tea",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "Support us if you like what we do",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              onSupport(context);
            }),
        ExpansionTile(
          // onExpansionChanged: (value) {
          //   if (value)
          //     Future.delayed(Duration(milliseconds: 200)).then((value) =>
          //         widget.scrollController.animateTo(
          //             widget.scrollController.position.maxScrollExtent + 10000,
          //             duration: Duration(milliseconds: 300),
          //             curve: Curves.fastOutSlowIn));
          // },
          leading: Icon(
            JamIcons.users,
          ),
          title: new Text(
            "Meet the awesome team",
            style: TextStyle(
                color: Theme.of(context).accentColor,
                fontWeight: FontWeight.w500,
                fontFamily: "Proxima Nova"),
          ),
          subtitle: Text(
            "Check out the cool devs!",
            style:
                TextStyle(fontSize: 12, color: Theme.of(context).accentColor),
          ),
          children: [
            ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage("assets/images/AB.jpg"),
                ),
                title: new Text(
                  "LiquidatorCoder",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Abhay Maurya",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  launch("https://github.com/LiquidatorCoder");
                }),
            ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage("assets/images/AK.jpg"),
                ),
                title: new Text(
                  "CodeNameAkshay",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Akshay Maurya",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  launch("https://github.com/codenameakshay");
                }),
            ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage("assets/images/PT.jpg"),
                ),
                title: new Text(
                  "1-2-ka-4-4-2-ka-1",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Pratyush Tiwari",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  launch("https://github.com/1-2-ka-4-4-2-ka-1");
                }),
            ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage("assets/images/AY.jpeg"),
                ),
                title: new Text(
                  "MrHYDRA-6469",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Arpit Yadav",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  launch("https://github.com/MrHYDRA-6469");
                }),
            ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage("assets/images/AT.jpg"),
                ),
                title: new Text(
                  "AyushTevatia99",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Ayush Tevatia",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  launch("https://github.com/AyushTevatia99");
                }),
          ],
        ),
      ],
    );
  }
}
