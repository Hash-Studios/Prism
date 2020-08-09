// import 'dart:async';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:Prism/main.dart' as main;
// import 'package:in_app_purchase/in_app_purchase.dart';

// final List<String> premiumPurchase = ['prism_pro'];

// void createPremiumFirestore(bool premium) async {
//   Firestore firestore = Firestore.instance;
//   var uid = main.prefs.get("id");
//   await firestore.collection("users").document(uid).updateData({
//     "premium": premium,
//   });
//   main.prefs.put('premium', premium);
// }

// final InAppPurchaseConnection iap = InAppPurchaseConnection.instance;
// bool available = true;

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

// // void verifyPurchase(String productID) async {
// //   PurchaseDetails purchase = hasPurchased(productID);
// //   if (purchase != null) {
// //     if (purchase.status == PurchaseStatus.purchased) {
// //       if (!purchase.billingClientPurchase.isAcknowledged)
// //         await iap.completePurchase(purchase);
// //       toasts.premiumSuccess();
// //       main.prefs.put("premium", true);
// //       createPremiumFirestore(true);
// //       cancelSubscription();
// //       // func();
// //     }
// //   } else {
// //     toasts.error("Invalid Purchase!");
// //     main.prefs.put("premium", false);
// //     createPremiumFirestore(false);
// //     cancelSubscription();
// //   }
// // }

// Future<void> buyProduct(ProductDetails prod) {
//   final PurchaseParam purchaseParam = PurchaseParam(productDetails: prod);
//   iap.buyNonConsumable(purchaseParam: purchaseParam);
// }

// // void initialize() async {
// //   available = await iap.isAvailable();
// //   if (available) {
// //     List<Future> futures = [getProducts(), getPastPurchases()];
// //     await Future.wait(futures);
// //     subscription = iap.purchaseUpdatedStream.listen(
// //       (data) {
// //         purchases.addAll(data);
// //         verifyPurchase(data[data.length - 1].productID);
// //       },
// //     );
// //   }
// // }

// // Future<void> getPremiumPurchaseData() async {
// //   bool premium = false;
// //   QueryPurchaseDetailsResponse response = await iap.queryPastPurchases();
// //   purchases = response.pastPurchases;
// //   purchases.forEach((element) {
// //     if (element.productID == 'prism_pro') {
// //       print('Prism Premium');
// //       premium = true;
// //     }
// //   });
// //   createPremiumFirestore(premium);
// // }
