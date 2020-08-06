import 'dart:async';

import 'package:Prism/analytics/purchase_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:in_app_purchase/in_app_purchase.dart';

void premiumPopUp(BuildContext context, Function func) {
  // final List<String> premiumPurchase = ['prism_pro'];
  // void createPremiumFirestore(bool premium) async {
  //   Firestore firestore = Firestore.instance;
  //   var uid = main.prefs.get("id");
  //   await firestore.collection("users").document(uid).updateData({
  //     "premium": premium,
  //   });
  // }

  // InAppPurchaseConnection iap = InAppPurchaseConnection.instance;
  // bool _available = true;

  // List<ProductDetails> products = [];
  // List<PurchaseDetails> purchases = [];
  // StreamSubscription subscription;

  // Future<void> getProducts() async {
  //   Set<String> ids = Set.from(premiumPurchase);
  //   ProductDetailsResponse response = await iap.queryProductDetails(ids);
  //   products = response.productDetails;
  //   print("products:${products[0].title}");
  // }

  // Future<void> getPastPurchases() async {
  //   QueryPurchaseDetailsResponse response = await iap.queryPastPurchases();
  //   purchases = response.pastPurchases;
  //   print("purchases:$purchases");
  // }

  // void cancelSubscription() {
  //   subscription.cancel();
  // }

  // PurchaseDetails hasPurchased(String productID) {
  //   return purchases.firstWhere((purchase) => purchase.productID == productID,
  //       orElse: () => null);
  // }

  void _verifyPurchase(String productID) async {
    PurchaseDetails purchase = hasPurchased(productID);
    if (purchase != null) {
      if (purchase.status == PurchaseStatus.purchased) {
        if (!purchase.billingClientPurchase.isAcknowledged)
          await iap.completePurchase(purchase);
        toasts.premiumSuccess();
        main.prefs.put("premium", true);
        createPremiumFirestore(true);
        cancelSubscription();
        Navigator.pop(context);
        func();
      }
    } else {
      toasts.error("Invalid Purchase!");
      main.prefs.put("premium", false);
      createPremiumFirestore(false);
      cancelSubscription();
      Navigator.pop(context);
    }
  }

  // Future<void> buyProduct(ProductDetails prod) {
  //   final PurchaseParam purchaseParam = PurchaseParam(productDetails: prod);
  //   iap.buyNonConsumable(purchaseParam: purchaseParam);
  // }

  void initialize() async {
    available = await iap.isAvailable();
    if (available) {
      List<Future> futures = [getProducts(), getPastPurchases()];
      await Future.wait(futures);
      subscription = iap.purchaseUpdatedStream.listen(
        (data) {
          purchases.addAll(data);
          _verifyPurchase(data[data.length - 1].productID);
        },
      );
    }
  }

  Dialog loaderDialog = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .7,
      height: MediaQuery.of(context).size.height * .3,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    ),
  );
  Dialog premiumPopUp = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).primaryColor),
        width: MediaQuery.of(context).size.width * .78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 150,
              width: MediaQuery.of(context).size.width * .78,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                  color: Theme.of(context).hintColor),
              child: FlareActor(
                "assets/animations/Premium.flr",
                isPaused: false,
                alignment: Alignment.center,
                animation: "premium",
              ),
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                  child: Text(
                    'PREMIUM UNLOCKS:',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 20,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.instant_picture,
                  size: 22,
                  color: Color(0xFFE57697),
                ),
                SizedBox(
                  width: 20,
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "The ability to view setups.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.filter,
                  size: 22,
                  color: Color(0xFFE57697),
                ),
                SizedBox(
                  width: 20,
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "Download or set variants of wallpapers.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.user,
                  size: 22,
                  color: Color(0xFFE57697),
                ),
                SizedBox(
                  width: 20,
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "Get PRO badge in front of your profile.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.clock,
                  size: 22,
                  color: Color(0xFFE57697),
                ),
                SizedBox(
                  width: 20,
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "Get uploads reviewed instantly.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                ),
                Icon(
                  JamIcons.coffee,
                  size: 22,
                  color: Color(0xFFE57697),
                ),
                SizedBox(
                  width: 20,
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "Support development of the app.",
                    style: Theme.of(context)
                        .textTheme
                        .headline6
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            // SizedBox(
            //   height: 10,
            // ),
            // Row(
            //   crossAxisAlignment: CrossAxisAlignment.center,
            //   mainAxisAlignment: MainAxisAlignment.start,
            //   children: [
            //     SizedBox(
            //       width: 20,
            //     ),
            //     Icon(
            //       JamIcons.cloud,
            //       size: 22,
            //       color: Color(0xFFE57697),
            //     ),
            //     SizedBox(
            //       width: 20,
            //     ),
            //     Container(
            //       width: MediaQuery.of(context).size.width * 0.6,
            //       child: Text(
            //         "The ability to cloud sync data.",
            //         style: Theme.of(context)
            //             .textTheme
            //             .headline6
            //             .copyWith(color: Theme.of(context).accentColor),
            //       ),
            //     ),
            //   ],
            // ),
            SizedBox(
              height: 25,
            ),
            FlatButton(
              shape: StadiumBorder(),
              color: Color(0xFFE57697),
              onPressed: () async {
                Navigator.of(context).pop();
                showDialog(
                    barrierDismissible: false,
                    context: context,
                    builder: (BuildContext context) => loaderDialog);
                await buyProduct(products
                    .firstWhere((element) => element.id == premiumPurchase[0]));
              },
              child: Text(
                'BUY PREMIUM',
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(
              height: 15,
            ),
          ],
        ),
      ),
    ),
  );
  initialize();
  showDialog(context: context, builder: (BuildContext context) => premiumPopUp);
}
