import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/features/setups/views/pages/review_screen.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DraftSetupScreen extends StatefulWidget {
  const DraftSetupScreen();

  @override
  _DraftSetupScreenState createState() => _DraftSetupScreenState();
}

class _DraftSetupScreenState extends State<DraftSetupScreen> {
  Future<bool> onWillPop() async {
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          title: Text(
            "Setup Drafts",
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
        ),
        body: StreamBuilder<List<FirestoreDocument>>(
            stream: firestoreClient.watchQuery<FirestoreDocument>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.draftSetups,
                sourceTag: 'draftSetups.list',
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
                return Center(
                  child: Loader(),
                );
              } else {
                if (snapshot.data!.isNotEmpty) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) => SetupTile(snapshot.data![index], true),
                  );
                } else {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                          "Your saved setup drafts show up here. Simply click the Save button when uploading a setup to save the draft."),
                    ),
                  );
                }
              }
            }),
      ),
    );
  }
}
