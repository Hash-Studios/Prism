// import 'package:firebase_messaging/firebase_messaging.dart';

// Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) {
//   if (message.containsKey('data')) {
//     // Handle data message
//     final dynamic data = message['data'];
//   }

//   if (message.containsKey('notification')) {
//     // Handle notification message
//     final dynamic notification = message['notification'];
//   }

//   // Or do other work.
// }

// class PushNotificationsManager {

//   PushNotificationsManager._();

//   factory PushNotificationsManager() => _instance;

//   static final PushNotificationsManager _instance = PushNotificationsManager._();

//   final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
//   bool _initialized = false;

//   Future<void> init() async {
//     if (!_initialized) {
//       _firebaseMessaging.requestNotificationPermissions();
//       _firebaseMessaging.configure(
//       onMessage: (Map<String, dynamic> message) async {
//         print("onMessage: $message");
//         // _showItemDialog(message);
//       },
//       onBackgroundMessage: myBackgroundMessageHandler,
//       onLaunch: (Map<String, dynamic> message) async {
//         print("onLaunch: $message");
//         // _navigateToItemDetail(message);
//       },
//       onResume: (Map<String, dynamic> message) async {
//         print("onResume: $message");
//         // _navigateToItemDetail(message);
//       },
//     );

//       String token = await _firebaseMessaging.getToken();
//       print("FirebaseMessaging token: $token");

//       _initialized = true;
//     }
//   }
// }
