import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:hive_io/hive_io.dart';
import 'package:injectable/injectable.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:quick_actions/quick_actions.dart';

@module
abstract class AppModule {
  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  @lazySingleton
  FirestoreTelemetrySink get firestoreTelemetrySink => CompositeFirestoreTelemetrySink(
        <FirestoreTelemetrySink>[
          const FirestoreConsoleTelemetrySink(),
          FirestoreFileTelemetrySink(),
        ],
      );

  @lazySingleton
  FirestoreClient firestoreClient(
    FirebaseFirestore firestore,
    FirestoreTelemetrySink telemetrySink,
  ) =>
      FirestoreTrackedClient(firestore, telemetrySink);

  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseDynamicLinks get firebaseDynamicLinks => FirebaseDynamicLinks.instance;

  @lazySingleton
  FirebaseRemoteConfig get remoteConfig => FirebaseRemoteConfig.instance;

  @lazySingleton
  InternetConnectionChecker get internetConnectionChecker => InternetConnectionChecker.instance;

  @lazySingleton
  QuickActions get quickActions => const QuickActions();

  @Named('prefsBox')
  @lazySingleton
  Box<dynamic> get prefsBox => Hive.box('prefs');

  @Named('localFavBox')
  @lazySingleton
  Box<dynamic> get localFavBox => Hive.box('localFav');

  @Named('inAppNotificationsBox')
  @lazySingleton
  Box<InAppNotif> get inAppNotificationsBox => Hive.box<InAppNotif>('inAppNotifs');
}
