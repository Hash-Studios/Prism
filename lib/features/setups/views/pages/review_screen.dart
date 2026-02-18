import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_route/auto_route.dart';
import 'package:photo_view/photo_view.dart';

@RoutePage()
class ReviewScreen extends StatefulWidget {
  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with SingleTickerProviderStateMixin {
  TabController? tabController;

  @override
  void initState() {
    tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: AppBar(
          title: Row(
            children: [
              Text("Review Status", style: Theme.of(context).textTheme.displaySmall),
              Container(
                margin: const EdgeInsets.only(left: 3, bottom: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(500),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 4),
                  child: Text("BETA", style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.secondary)),
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(JamIcons.chevron_left),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        bottom: TabBar(
          controller: tabController,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              child: Text(
                "Wallpapers",
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
            Tab(
              child: Text(
                "Setups",
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      body: TabBarView(controller: tabController, children: [WallReview(), SetupReview()]),
    );
  }
}

class WallReview extends StatefulWidget {
  @override
  _WallReviewState createState() => _WallReviewState();
}

class _WallReviewState extends State<WallReview> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          StreamBuilder<List<FirestoreDocument>>(
            stream: firestoreClient.watchQuery<FirestoreDocument>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.rejectedWalls,
                sourceTag: 'review.rejectedWalls',
                filters: <FirestoreFilter>[
                  FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: globals.prismUser.email),
                ],
                orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
                isStream: true,
              ),
              (data, docId) => FirestoreDocument(docId, data),
            ),
            builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
              if (!snapshot.hasData) {
                return Container();
              } else {
                return Column(
                  children: List.generate(
                    snapshot.data!.length,
                    (int index) => RejectedWallTile(snapshot.data![index]),
                  ),
                );
              }
            },
          ),
          StreamBuilder<List<FirestoreDocument>>(
            stream: firestoreClient.watchQuery<FirestoreDocument>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.walls,
                sourceTag: 'review.pendingWalls',
                filters: <FirestoreFilter>[
                  FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: globals.prismUser.email),
                  const FirestoreFilter(field: "review", op: FirestoreFilterOp.isEqualTo, value: false),
                ],
                orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
                isStream: true,
              ),
              (data, docId) => FirestoreDocument(docId, data),
            ),
            builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
              if (!snapshot.hasData) {
                return Center(child: Loader());
              } else {
                return Column(
                  children: List.generate(snapshot.data!.length, (int index) => WallTile(snapshot.data![index])),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class WallTile extends StatelessWidget {
  final FirestoreDocument wallpaper;
  WallTile(this.wallpaper);
  final DateFormat formatter = DateFormat('d MMMM y, h:m a');
  static final PrismMediaHostApi _prismMediaApi = PrismMediaHostApi();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 340,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(JamIcons.clock, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        formatter.format(_toDateTime(wallpaper.data()["createdAt"]).toLocal()),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => PhotoView(
                                  onTapUp: (context, details, controller) {
                                    Navigator.pop(context);
                                  },
                                  imageProvider: CachedNetworkImageProvider(
                                    wallpaper.data()["wallpaper_url"] as String,
                                  ),
                                ),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                          child: SizedBox(
                            height: 240,
                            width: 120,
                            child: CachedNetworkImage(
                              imageUrl: wallpaper.data()["wallpaper_thumb"] as String,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(JamIcons.id_card, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  "${wallpaper.data()["id"]}",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(JamIcons.save, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  "${wallpaper.data()["size"]}",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(JamIcons.set_square, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  "${wallpaper.data()["resolution"]}",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ActionChip(
                              backgroundColor: Colors.amber,
                              avatar: const Icon(JamIcons.clock, color: Colors.black),
                              onPressed: () {},
                              label: Text(
                                "IN REVIEW",
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(JamIcons.download, color: Theme.of(context).primaryColor),
                                    onPressed: () async {
                                      final status = await Permission.storage.status;
                                      if (!status.isGranted) {
                                        await Permission.storage.request();
                                      }
                                      final link = wallpaper.data()["wallpaper_url"].toString();
                                      logger.d(link);

                                      final androidInfo = await DeviceInfoPlugin().androidInfo;
                                      final sdkInt = androidInfo.version.sdkInt;
                                      logger.d('(SDK $sdkInt)');
                                      toasts.codeSend("Starting Download");
                                      main.localNotification.createDownloadNotification();

                                      try {
                                        final request = SaveMediaRequest(
                                          link: link,
                                          isLocalFile: false,
                                          kind: SaveMediaKind.wallpaper,
                                        );
                                        final result = await _prismMediaApi.saveMedia(request);
                                        if (result.success) {
                                          analytics.logEvent(name: 'download_own_wall', parameters: {'link': link});
                                          toasts.codeSend("Wall Downloaded in Pictures/Prism!");
                                        } else {
                                          toasts.codeSend("Couldn't download! Please Retry!");
                                        }
                                      } on PlatformException catch (e) {
                                        logger.e('saveMedia failed for review wall download', error: e);
                                        toasts.codeSend("Couldn't download! Please Retry!");
                                      } catch (e) {
                                        logger.e('Unexpected saveMedia failure for review wall download', error: e);
                                        toasts.codeSend("Couldn't download! Please Retry!");
                                      } finally {
                                        main.localNotification.cancelDownloadNotification();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: IconButton(
                                    icon: const Icon(JamIcons.trash, color: Colors.white),
                                    onPressed: () async {
                                      final AlertDialog deleteWallPopUp = AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        title: Text(
                                          'Delete this wallpaper?',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                        content: Text(
                                          "This is permanent, and this action can't be undone!",
                                          style: TextStyle(
                                            fontFamily: "Proxima Nova",
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                        actions: [
                                          MaterialButton(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            color: Theme.of(context).hintColor,
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await firestoreClient.deleteDoc(
                                                FirebaseCollections.walls,
                                                wallpaper.id,
                                                sourceTag: 'review.wall.delete',
                                              );
                                              toasts.codeSend("Wallpaper successfully deleted from server!");
                                            },
                                            child: const Text(
                                              'DELETE',
                                              style: TextStyle(fontSize: 16.0, color: Colors.white),
                                            ),
                                          ),
                                          MaterialButton(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            color: Theme.of(context).colorScheme.error,
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text(
                                              'CANCEL',
                                              style: TextStyle(fontSize: 16.0, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                        backgroundColor: Theme.of(context).primaryColor,
                                        actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                                      );

                                      showModal(context: context, builder: (BuildContext context) => deleteWallPopUp);
                                    },
                                  ),
                                ),
                              ],
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

class RejectedWallTile extends StatelessWidget {
  final FirestoreDocument wallpaper;
  RejectedWallTile(this.wallpaper);
  final DateFormat formatter = DateFormat('d MMMM y, h:m a');
  static final PrismMediaHostApi _prismMediaApi = PrismMediaHostApi();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(JamIcons.clock, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        formatter.format(_toDateTime(wallpaper.data()["createdAt"]).toLocal()),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => PhotoView(
                                  onTapUp: (context, details, controller) {
                                    Navigator.pop(context);
                                  },
                                  imageProvider: CachedNetworkImageProvider(
                                    wallpaper.data()["wallpaper_url"] as String,
                                  ),
                                ),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                          child: SizedBox(
                            height: 240,
                            width: 120,
                            child: CachedNetworkImage(
                              imageUrl: wallpaper.data()["wallpaper_thumb"] as String,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(JamIcons.id_card, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  "${wallpaper.data()["id"]}",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(JamIcons.save, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  "${wallpaper.data()["size"]}",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(JamIcons.set_square, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  "${wallpaper.data()["resolution"]}",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ActionChip(
                              backgroundColor: Colors.red,
                              avatar: const Icon(JamIcons.close, color: Colors.white),
                              onPressed: () {},
                              label: Text(
                                "REJECTED",
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(JamIcons.download, color: Theme.of(context).primaryColor),
                                    onPressed: () async {
                                      final status = await Permission.storage.status;
                                      if (!status.isGranted) {
                                        await Permission.storage.request();
                                      }
                                      final link = wallpaper.data()["wallpaper_url"].toString();
                                      logger.d(link);

                                      final androidInfo = await DeviceInfoPlugin().androidInfo;
                                      final sdkInt = androidInfo.version.sdkInt;
                                      logger.d('(SDK $sdkInt)');
                                      toasts.codeSend("Starting Download");
                                      main.localNotification.createDownloadNotification();

                                      try {
                                        final request = SaveMediaRequest(
                                          link: link,
                                          isLocalFile: false,
                                          kind: SaveMediaKind.wallpaper,
                                        );
                                        final result = await _prismMediaApi.saveMedia(request);
                                        if (result.success) {
                                          analytics.logEvent(name: 'download_own_wall', parameters: {'link': link});
                                          toasts.codeSend("Wall Downloaded in Pictures/Prism!");
                                        } else {
                                          toasts.codeSend("Couldn't download! Please Retry!");
                                        }
                                      } on PlatformException catch (e) {
                                        logger.e('saveMedia failed for rejected wall download', error: e);
                                        toasts.codeSend("Couldn't download! Please Retry!");
                                      } catch (e) {
                                        logger.e('Unexpected saveMedia failure for rejected wall download', error: e);
                                        toasts.codeSend("Couldn't download! Please Retry!");
                                      } finally {
                                        main.localNotification.cancelDownloadNotification();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: IconButton(
                                    icon: const Icon(JamIcons.trash, color: Colors.white),
                                    onPressed: () async {
                                      final AlertDialog deleteWallPopUp = AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        title: Text(
                                          'Delete this wallpaper?',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                        content: Text(
                                          "This is permanent, and this action can't be undone!",
                                          style: TextStyle(
                                            fontFamily: "Proxima Nova",
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                        actions: [
                                          MaterialButton(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            color: Theme.of(context).hintColor,
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await firestoreClient.deleteDoc(
                                                FirebaseCollections.rejectedWalls,
                                                wallpaper.id,
                                                sourceTag: 'review.rejectedWall.delete',
                                              );
                                              toasts.codeSend("Wallpaper successfully deleted from server!");
                                            },
                                            child: const Text(
                                              'DELETE',
                                              style: TextStyle(fontSize: 16.0, color: Colors.white),
                                            ),
                                          ),
                                          MaterialButton(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            color: Theme.of(context).colorScheme.error,
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text(
                                              'CANCEL',
                                              style: TextStyle(fontSize: 16.0, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                        backgroundColor: Theme.of(context).primaryColor,
                                        actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                                      );

                                      showModal(context: context, builder: (BuildContext context) => deleteWallPopUp);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(JamIcons.close, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: Text(
                          "The wallpaper didn't meet our expectations. Please try uploading a good quality wallpaper.",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ],
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

class SetupReview extends StatefulWidget {
  @override
  _SetupReviewState createState() => _SetupReviewState();
}

class _SetupReviewState extends State<SetupReview> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          StreamBuilder<List<FirestoreDocument>>(
            stream: firestoreClient.watchQuery<FirestoreDocument>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.rejectedSetups,
                sourceTag: 'review.rejectedSetups',
                filters: <FirestoreFilter>[
                  FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: globals.prismUser.email),
                ],
                orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
                isStream: true,
              ),
              (data, docId) => FirestoreDocument(docId, data),
            ),
            builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
              if (!snapshot.hasData) {
                return Container();
              } else {
                return Column(
                  children: List.generate(
                    snapshot.data!.length,
                    (int index) => RejectedSetupTile(snapshot.data![index]),
                  ),
                );
              }
            },
          ),
          StreamBuilder<List<FirestoreDocument>>(
            stream: firestoreClient.watchQuery<FirestoreDocument>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.setups,
                sourceTag: 'review.pendingSetups',
                filters: <FirestoreFilter>[
                  FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: globals.prismUser.email),
                  const FirestoreFilter(field: "review", op: FirestoreFilterOp.isEqualTo, value: false),
                ],
                orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
                isStream: true,
              ),
              (data, docId) => FirestoreDocument(docId, data),
            ),
            builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
              if (!snapshot.hasData) {
                return Center(child: Loader());
              } else {
                return Column(
                  children: List.generate(
                    snapshot.data!.length,
                    (int index) => SetupTile(snapshot.data![index], false),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class SetupTile extends StatelessWidget {
  final FirestoreDocument wallpaper;
  final bool draft;
  SetupTile(this.wallpaper, this.draft);
  final DateFormat formatter = DateFormat('d MMMM y, h:m a');
  static final PrismMediaHostApi _prismMediaApi = PrismMediaHostApi();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      constraints: BoxConstraints(
        minHeight: "${wallpaper.data()["widget2"]}" != "" ? 420 : 390,
        maxHeight: "${wallpaper.data()["widget2"]}" != "" ? 470 : 440,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(JamIcons.clock, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        formatter.format(_toDateTime(wallpaper.data()["created_at"]).toLocal()),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => PhotoView(
                                      onTapUp: (context, details, controller) {
                                        Navigator.pop(context);
                                      },
                                      imageProvider: CachedNetworkImageProvider(wallpaper.data()["image"] as String),
                                    ),
                                    fullscreenDialog: true,
                                  ),
                                );
                              },
                              child: SizedBox(
                                height: 240,
                                width: 120,
                                child: CachedNetworkImage(
                                  imageUrl: wallpaper.data()["image"] as String,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                toasts.codeSend("${wallpaper.data()["name"]} - ${wallpaper.data()["desc"]}");
                              },
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.3,
                                child: RichText(
                                  text: TextSpan(
                                    text: "${wallpaper.data()["name"]}" == ""
                                        ? "No name"
                                        : "${wallpaper.data()["name"]}",
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: "${wallpaper.data()["desc"]}" == ""
                                            ? " - No desc"
                                            : " - ${wallpaper.data()["desc"]}",
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          decoration: TextDecoration.underline,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(JamIcons.id_card, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.3,
                                  child: Text(
                                    "${wallpaper.data()["id"]}",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                if ("${wallpaper.data()["wallpaper_url"]}" != "") {
                                  if ("${wallpaper.data()["wallpaper_url"]}"[0] != "[") {
                                    if ("${wallpaper.data()["wall_id"]}" != "") {
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (context) => PhotoView(
                                            onTapUp: (context, details, controller) {
                                              Navigator.pop(context);
                                            },
                                            imageProvider: CachedNetworkImageProvider(
                                              wallpaper.data()["wallpaper_url"] as String,
                                            ),
                                          ),
                                          fullscreenDialog: true,
                                        ),
                                      );
                                    } else {
                                      launch("${wallpaper.data()["wallpaper_url"]}").catchError((e) {
                                        toasts.error("Error in link!");
                                        return false;
                                      });
                                    }
                                  } else {
                                    launch("${wallpaper.data()["wallpaper_url"][1]}").catchError((e) {
                                      toasts.error("Error in link!");
                                      return false;
                                    });
                                  }
                                } else {
                                  toasts.error("Wallpaper not added!");
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.3,
                                    child: Text(
                                      "${wallpaper.data()["wallpaper_url"]}" != ""
                                          ? "${wallpaper.data()["wallpaper_url"]}"[0] != "["
                                                ? "Wallpaper"
                                                : "${wallpaper.data()["wallpaper_url"][0]} - ${wallpaper.data()["wallpaper_url"][2]}"
                                          : "Wallpaper",
                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                if ("${wallpaper.data()["icon_url"]}" != "") {
                                  launch("${wallpaper.data()["icon_url"]}").catchError((e) {
                                    toasts.error("Error in link!");
                                    return false;
                                  });
                                } else {
                                  toasts.error("No icons added!");
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(JamIcons.google_play, color: Theme.of(context).colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.3,
                                    child: Text(
                                      "${wallpaper.data()["icon"]}" == "" ? "No icon" : "${wallpaper.data()["icon"]}",
                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if ("${wallpaper.data()["widget"]}" != "") const SizedBox(height: 16) else Container(),
                            if ("${wallpaper.data()["widget"]}" != "")
                              GestureDetector(
                                onTap: () {
                                  launch("${wallpaper.data()["widget_url"]}").catchError((e) {
                                    toasts.error("Error in link!");
                                    return false;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(JamIcons.google_play, color: Theme.of(context).colorScheme.secondary),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.3,
                                      child: Text(
                                        "${wallpaper.data()["widget"]}",
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          decoration: TextDecoration.underline,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(),
                            if ("${wallpaper.data()["widget2"]}" != "") const SizedBox(height: 16) else Container(),
                            if ("${wallpaper.data()["widget2"]}" != "")
                              GestureDetector(
                                onTap: () {
                                  launch("${wallpaper.data()["widget_url2"]}").catchError((e) {
                                    toasts.error("Error in link!");
                                    return false;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(JamIcons.google_play, color: Theme.of(context).colorScheme.secondary),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.3,
                                      child: Text(
                                        "${wallpaper.data()["widget2"]}",
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          decoration: TextDecoration.underline,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(),
                            const SizedBox(height: 16),
                            if (draft)
                              Container()
                            else
                              ActionChip(
                                backgroundColor: Colors.amber,
                                avatar: const Icon(JamIcons.clock, color: Colors.black),
                                onPressed: () {},
                                label: Text(
                                  "IN REVIEW",
                                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.black),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Wrap(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(JamIcons.pencil, color: Theme.of(context).primaryColor),
                                    onPressed: () {
                                      context.router.push(EditSetupReviewRoute(arguments: [wallpaper]));
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(JamIcons.download, color: Theme.of(context).primaryColor),
                                    onPressed: () async {
                                      final status = await Permission.storage.status;
                                      if (!status.isGranted) {
                                        await Permission.storage.request();
                                      }
                                      final link = wallpaper.data()["image"].toString();
                                      logger.d(link);

                                      final androidInfo = await DeviceInfoPlugin().androidInfo;
                                      final sdkInt = androidInfo.version.sdkInt;
                                      logger.d('(SDK $sdkInt)');
                                      toasts.codeSend("Starting Download");

                                      try {
                                        final request = SaveMediaRequest(
                                          link: link,
                                          isLocalFile: false,
                                          kind: SaveMediaKind.setup,
                                        );
                                        final result = await _prismMediaApi.saveMedia(request);
                                        if (result.success) {
                                          analytics.logEvent(name: 'download_own_setup', parameters: {'link': link});
                                          toasts.codeSend("Setup Downloaded in Pictures/Prism Setup!");
                                        } else {
                                          toasts.codeSend("Couldn't download! Please Retry!");
                                        }
                                      } on PlatformException catch (e) {
                                        logger.e('saveMedia failed for review setup download', error: e);
                                        toasts.codeSend("Couldn't download! Please Retry!");
                                      } catch (e) {
                                        logger.e('Unexpected saveMedia failure for review setup download', error: e);
                                        toasts.codeSend("Couldn't download! Please Retry!");
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ActionChip(
                              backgroundColor: Colors.red,
                              avatar: const Icon(JamIcons.trash, color: Colors.white),
                              label: Text(
                                "DELETE",
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
                              ),
                              onPressed: () async {
                                final AlertDialog deleteWallPopUp = AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  title: Text(
                                    draft ? 'Delete this draft?' : 'Delete this setup?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                  content: Text(
                                    "This is permanent, and this action can't be undone!",
                                    style: TextStyle(
                                      fontFamily: "Proxima Nova",
                                      fontWeight: FontWeight.normal,
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                  actions: [
                                    MaterialButton(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                      color: Theme.of(context).hintColor,
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        if (draft) {
                                          await firestoreClient.deleteDoc(
                                            FirebaseCollections.draftSetups,
                                            wallpaper.id,
                                            sourceTag: 'review.draftSetup.delete',
                                          );
                                          toasts.codeSend("Draft successfully deleted from server!");
                                        } else {
                                          await firestoreClient.deleteDoc(
                                            FirebaseCollections.setups,
                                            wallpaper.id,
                                            sourceTag: 'review.setup.delete',
                                          );
                                          toasts.codeSend("Setup successfully deleted from server!");
                                        }
                                      },
                                      child: const Text(
                                        'DELETE',
                                        style: TextStyle(fontSize: 16.0, color: Colors.white),
                                      ),
                                    ),
                                    MaterialButton(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                      color: Theme.of(context).colorScheme.error,
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text(
                                        'CANCEL',
                                        style: TextStyle(fontSize: 16.0, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                  backgroundColor: Theme.of(context).primaryColor,
                                  actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                                );

                                showModal(context: context, builder: (BuildContext context) => deleteWallPopUp);
                              },
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

class RejectedSetupTile extends StatelessWidget {
  final FirestoreDocument wallpaper;
  RejectedSetupTile(this.wallpaper);
  final DateFormat formatter = DateFormat('d MMMM y, h:m a');
  static final PrismMediaHostApi _prismMediaApi = PrismMediaHostApi();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: "${wallpaper.data()["widget2"]}" != "" ? 460 : 430,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(JamIcons.clock, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        formatter.format(_toDateTime(wallpaper.data()["created_at"]).toLocal()),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => PhotoView(
                                      onTapUp: (context, details, controller) {
                                        Navigator.pop(context);
                                      },
                                      imageProvider: CachedNetworkImageProvider(wallpaper.data()["image"] as String),
                                    ),
                                    fullscreenDialog: true,
                                  ),
                                );
                              },
                              child: SizedBox(
                                height: 240,
                                width: 120,
                                child: CachedNetworkImage(
                                  imageUrl: wallpaper.data()["image"] as String,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                toasts.codeSend("${wallpaper.data()["name"]} - ${wallpaper.data()["desc"]}");
                              },
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.3,
                                child: RichText(
                                  text: TextSpan(
                                    text: "${wallpaper.data()["name"]}",
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: " - ${wallpaper.data()["desc"]}",
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          decoration: TextDecoration.underline,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(JamIcons.id_card, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.3,
                                  child: Text(
                                    "${wallpaper.data()["id"]}",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                if ("${wallpaper.data()["wallpaper_url"]}"[0] != "[") {
                                  if ("${wallpaper.data()["wall_id"]}" != "") {
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (context) => PhotoView(
                                          onTapUp: (context, details, controller) {
                                            Navigator.pop(context);
                                          },
                                          imageProvider: CachedNetworkImageProvider(
                                            wallpaper.data()["wallpaper_url"] as String,
                                          ),
                                        ),
                                        fullscreenDialog: true,
                                      ),
                                    );
                                  } else {
                                    launch("${wallpaper.data()["wallpaper_url"]}").catchError((e) {
                                      toasts.error("Error in link!");
                                      return false;
                                    });
                                  }
                                } else {
                                  launch("${wallpaper.data()["wallpaper_url"][1]}").catchError((e) {
                                    toasts.error("Error in link!");
                                    return false;
                                  });
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.3,
                                    child: Text(
                                      "${wallpaper.data()["wallpaper_url"]}"[0] != "["
                                          ? "Wallpaper"
                                          : "${wallpaper.data()["wallpaper_url"][0]} - ${wallpaper.data()["wallpaper_url"][2]}",
                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                launch("${wallpaper.data()["icon_url"]}").catchError((e) {
                                  toasts.error("Error in link!");
                                  return false;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(JamIcons.google_play, color: Theme.of(context).colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.3,
                                    child: Text(
                                      "${wallpaper.data()["icon"]}",
                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if ("${wallpaper.data()["widget"]}" != "") const SizedBox(height: 16) else Container(),
                            if ("${wallpaper.data()["widget"]}" != "")
                              GestureDetector(
                                onTap: () {
                                  launch("${wallpaper.data()["widget_url"]}").catchError((e) {
                                    toasts.error("Error in link!");
                                    return false;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(JamIcons.google_play, color: Theme.of(context).colorScheme.secondary),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.3,
                                      child: Text(
                                        "${wallpaper.data()["widget"]}",
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          decoration: TextDecoration.underline,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(),
                            if ("${wallpaper.data()["widget2"]}" != "") const SizedBox(height: 16) else Container(),
                            if ("${wallpaper.data()["widget2"]}" != "")
                              GestureDetector(
                                onTap: () {
                                  launch("${wallpaper.data()["widget_url2"]}").catchError((e) {
                                    toasts.error("Error in link!");
                                    return false;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(JamIcons.google_play, color: Theme.of(context).colorScheme.secondary),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.3,
                                      child: Text(
                                        "${wallpaper.data()["widget2"]}",
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          decoration: TextDecoration.underline,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(),
                            const SizedBox(height: 16),
                            ActionChip(
                              backgroundColor: Colors.red,
                              avatar: const Icon(JamIcons.close, color: Colors.white),
                              onPressed: () {},
                              label: Text(
                                "REJECTED",
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(JamIcons.download, color: Theme.of(context).primaryColor),
                                    onPressed: () async {
                                      final status = await Permission.storage.status;
                                      if (!status.isGranted) {
                                        await Permission.storage.request();
                                      }
                                      final link = wallpaper.data()["image"].toString();
                                      logger.d(link);

                                      final androidInfo = await DeviceInfoPlugin().androidInfo;
                                      final sdkInt = androidInfo.version.sdkInt;
                                      logger.d('(SDK $sdkInt)');
                                      toasts.codeSend("Starting Download");

                                      try {
                                        final request = SaveMediaRequest(
                                          link: link,
                                          isLocalFile: false,
                                          kind: SaveMediaKind.setup,
                                        );
                                        final result = await _prismMediaApi.saveMedia(request);
                                        if (result.success) {
                                          analytics.logEvent(name: 'download_own_setup', parameters: {'link': link});
                                          toasts.codeSend("Setup Downloaded in Pictures/Prism Setups!");
                                        } else {
                                          toasts.codeSend("Couldn't download! Please Retry!");
                                        }
                                      } on PlatformException catch (e) {
                                        logger.e('saveMedia failed for rejected setup download', error: e);
                                        toasts.codeSend("Couldn't download! Please Retry!");
                                      } catch (e) {
                                        logger.e('Unexpected saveMedia failure for rejected setup download', error: e);
                                        toasts.codeSend("Couldn't download! Please Retry!");
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: IconButton(
                                    icon: const Icon(JamIcons.trash, color: Colors.white),
                                    onPressed: () async {
                                      final AlertDialog deleteWallPopUp = AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        title: Text(
                                          'Delete this setup?',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                        content: Text(
                                          "This is permanent, and this action can't be undone!",
                                          style: TextStyle(
                                            fontFamily: "Proxima Nova",
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                        actions: [
                                          MaterialButton(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            color: Theme.of(context).hintColor,
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await firestoreClient.deleteDoc(
                                                FirebaseCollections.rejectedSetups,
                                                wallpaper.id,
                                                sourceTag: 'review.rejectedSetup.delete',
                                              );
                                              toasts.codeSend("Setup successfully deleted from server!");
                                            },
                                            child: const Text(
                                              'DELETE',
                                              style: TextStyle(fontSize: 16.0, color: Colors.white),
                                            ),
                                          ),
                                          MaterialButton(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            color: Theme.of(context).colorScheme.error,
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text(
                                              'CANCEL',
                                              style: TextStyle(fontSize: 16.0, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                        backgroundColor: Theme.of(context).primaryColor,
                                        actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                                      );

                                      showModal(context: context, builder: (BuildContext context) => deleteWallPopUp);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(JamIcons.close, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: Text(
                          "The setup didn't meet our expectations. Please try uploading another setup.",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ],
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

DateTime _toDateTime(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  final dynamic withToDate = value;
  if (withToDate != null && withToDate.toDate is Function) {
    return withToDate.toDate() as DateTime;
  }
  return DateTime.now().toUtc();
}
