// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/edit_profile_panel.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_image_compress_common/flutter_image_compress_common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../support/fake_firestore_client.dart';

class _Picker extends ImagePickerPlatform {
  _Picker(this.path);

  final String path;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile(path);
}

class _Functions extends FirebaseFunctionsPlatform {
  _Functions(super.app, super.region);

  bool fail = false;

  @override
  FirebaseFunctionsPlatform delegateFor({FirebaseApp? app, required String region}) => this;

  @override
  HttpsCallablePlatform httpsCallable(String? origin, String name, HttpsCallableOptions options) =>
      _Callable(this, origin, name, options, null);
}

class _Callable extends HttpsCallablePlatform {
  _Callable(super.functions, super.origin, super.name, super.options, super.uri);

  @override
  Future<dynamic> call([dynamic parameters]) async {
    if ((functions as _Functions).fail) throw PlatformException(code: 'upload_failed');
    return <String, Object>{
      'content': <String, String>{'download_url': 'https://example.test/profile.png'},
    };
  }
}

class _Firestore extends FakeFirestoreClient {
  bool fail = false;

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) async {
    if (fail) throw PlatformException(code: 'profile_update_failed');
    await super.updateDoc(collection, id, data, sourceTag: sourceTag);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  const compressionChannel = MethodChannel('flutter_image_compress');
  final haptics = <Object?>[];
  final messages = <String>[];
  late _Functions functions;
  late _Firestore firestore;
  late Directory directory;
  late ImagePickerPlatform previousPicker;
  late FlutterImageCompressPlatform previousCompression;
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
  );
  bool failCompression = false;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    final app = await Firebase.initializeApp();
    functions = _Functions(app, 'asia-south1');
    FirebaseFunctionsPlatform.instance = functions;
  });

  setUp(() async {
    await getIt.reset();
    firestore = _Firestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'profile-user'
      ..loggedIn = true
      ..bio = ''
      ..profilePhoto = ''
      ..coverPhoto = null;
    functions.fail = false;
    failCompression = false;
    directory = Directory('test').createTempSync('.profile-haptics-');
    final image = File('${directory.path}/profile.png')..writeAsBytesSync(bytes);
    previousPicker = ImagePickerPlatform.instance;
    previousCompression = FlutterImageCompressPlatform.instance;
    ImagePickerPlatform.instance = _Picker(image.absolute.path);
    FlutterImageCompressCommon.registerWith();
    haptics.clear();
    messages.clear();
    PrismHaptics.enabled = true;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    messenger.setMockMethodCallHandler(toastChannel, (call) async {
      messages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    messenger.setMockMethodCallHandler(compressionChannel, (call) async {
      if (failCompression) throw PlatformException(code: 'compression_failed');
      return bytes;
    });
  });

  tearDown(() async {
    ImagePickerPlatform.instance = previousPicker;
    FlutterImageCompressPlatform.instance = previousCompression;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    messenger.setMockMethodCallHandler(compressionChannel, null);
    PrismHaptics.enabled = true;
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    directory.deleteSync(recursive: true);
  });

  for (final photo in <String>['profile', 'cover']) {
    for (final stage in <String>['compression', 'upload', 'profile update', 'success']) {
      testWidgets('$photo image save $stage reports only its actual outcome', (tester) async {
        failCompression = stage == 'compression';
        functions.fail = stage == 'upload';
        firestore.fail = stage == 'profile update';
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditProfilePanel())),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        final photoPicker = find.bySemanticsLabel('Change $photo photo');
        await tester.tapAt(tester.getTopLeft(photoPicker) + Offset(tester.getSize(photoPicker).width / 2, 10));
        await tester.pumpAndSettle();
        haptics.clear();
        await tester.ensureVisible(find.text('Update'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        if (stage == 'success') {
          expect(messages, <String>['Profile updated!']);
          expect(haptics, <String>['HapticFeedbackType.lightImpact', 'HapticFeedbackType.successNotification']);
          expect(find.text('Edit Profile'), findsNothing);
          expect(firestore.writes.single.data, <String, String>{
            photo == 'profile' ? 'profilePhoto' : 'coverPhoto': 'https://example.test/profile.png',
          });
        } else {
          expect(messages, <String>['Some uploading issue, please try again.']);
          expect(haptics, <String>['HapticFeedbackType.lightImpact', 'HapticFeedbackType.errorNotification']);
          expect(find.text('Edit Profile'), findsOneWidget);
          final save = find.ancestor(of: find.text('Update'), matching: find.byType(InkWell));
          expect(tester.widget<InkWell>(save).onTap, isNotNull);
        }
        await tester.pump(const Duration(seconds: 1));
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }
}
