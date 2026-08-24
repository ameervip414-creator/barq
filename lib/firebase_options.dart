import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCO_F9EdntGvZiHvd3RpS1El-RtyignkE0',
    appId: '1:325625073771:web:296a856c098762c3c1a12e',
    messagingSenderId: '325625073771',
    projectId: 'delivery-app-aefd7',
    authDomain: 'delivery-app-aefd7.firebaseapp.com',
    storageBucket: 'delivery-app-aefd7.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCO_F9EdntGvZiHvd3RpS1El-RtyignkE0',
    appId: '1:325625073771:android:eb2e358cdcb2dec6c1a12e',
    messagingSenderId: '325625073771',
    projectId: 'delivery-app-aefd7',
    storageBucket: 'delivery-app-aefd7.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC6wdOt9LwX6_4S0TAMM0PlmQKc5a6dMPo',
    appId: '1:325625073771:ios:7da0047f42af033dc1a12e',
    messagingSenderId: '325625073771',
    projectId: 'delivery-app-aefd7',
    storageBucket: 'delivery-app-aefd7.firebasestorage.app',
    databaseURL:
        'https://delivery-app-aefd7-default-rtdb.europe-west1.firebasedatabase.app',
    iosBundleId: 'com.barqapp.delivery',
  );
}
