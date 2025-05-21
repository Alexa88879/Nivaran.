// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart'; // Ensure Firebase is initialized for background

// Function to handle background messages (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `Firebase.initializeApp()` before using them.
  // No need to call Firebase.initializeApp() here if it's already done in main() for the app's start.
  // However, for background isolates, it's a good practice if this handler might be the first Firebase interaction.
  // As Firebase.initializeApp() is in main, we assume it's handled for the primary isolate.
  // For this background isolate, ensure it's initialized if you use Firebase services here.
  // await Firebase.initializeApp(); // Consider if needed based on what this handler does.

  developer.log("Handling a background message: ${message.messageId}", name: "NotificationServiceBG");
  developer.log('Message data: ${message.data}', name: "NotificationServiceBG");
  developer.log('Message notification: ${message.notification?.title} / ${message.notification?.body}', name: "NotificationServiceBG");

  // This handler is primarily for data-only messages received in the background
  // or for performing tasks before a notification is displayed by FCM itself.
  // If you send a notification payload, FCM on Android handles displaying it.
  // On iOS, this handler might be called if content-available is true.
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // This navigatorKey will be passed from main.dart and used by the instance methods
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationService({required this.navigatorKey});

  Future<void> initialize() async {
    developer.log("NotificationService: Initializing...", name: "NotificationService");

    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      developer.log('User granted notification permission', name: "NotificationService");
    } else {
      developer.log('User declined or has not accepted permission', name: "NotificationService");
    }

    try {
      _fcmToken = await _firebaseMessaging.getToken();
      developer.log("FCM Token: $_fcmToken", name: "NotificationService");
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        developer.log("FCM Token Refreshed: $newToken", name: "NotificationService");
        // The UserProfileService will call getToken and update Firestore.
        // If direct update from here is needed, a callback or provider interaction would be used.
        // For now, UserProfileService handles fetching this token.
      });
    } catch (e) {
      developer.log("Error getting FCM token: $e", name: "NotificationService");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse, // Note: This is now top-level
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('Foreground message received!', name: "NotificationService");
      developer.log('Message data: ${message.data}', name: "NotificationService");

      RemoteNotification? notification = message.notification;
      // AndroidNotification? android = message.notification?.android; // <-- FIXED: Removed unused variable

      if (notification != null) {
        developer.log('Message also contained a notification: ${notification.title} / ${notification.body}', name: "NotificationService");
        _showLocalNotification(message);
        // TODO: Optionally, save this to the in-app 'notifications' Firestore collection.
        // This is ideally done by a Cloud Function when the notification is sent for consistency.
        // If done client-side, ensure it's robust (e.g., handle duplicates if function also saves).
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('Message opened from background/terminated state!', name: "NotificationService");
      developer.log('Message data for navigation: ${message.data}', name: "NotificationService");
      _handleNotificationTap(message.data); // Now an instance method
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      developer.log('App opened from terminated state via notification!', name: "NotificationService");
      developer.log('Initial message data for navigation: ${initialMessage.data}', name: "NotificationService");
      // Delay slightly to ensure navigator is ready after app launch
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(initialMessage.data); // Now an instance method
      });
    }

    // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler); // Already set in main.dart
    developer.log("NotificationService: Initialization complete.", name: "NotificationService");
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    // AndroidNotification? android = message.notification?.android; // <-- FIXED: Removed unused variable

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'nivaran_default_channel',
      'Nivaran Updates',
      channelDescription: 'Notifications for Nivaran app updates and issues.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const DarwinNotificationDetails iosPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true);

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iosPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification?.title,
      notification?.body,
      platformChannelSpecifics,
      payload: message.data['navigateTo'] as String? ?? message.data['issueId'] as String?, // Pass navigateTo or issueId as payload
    );
  }

  // Instance method to handle local notification taps
  void _onDidReceiveLocalNotificationResponse(NotificationResponse notificationResponse) {
    developer.log('Local notification tapped (foreground): Payload: ${notificationResponse.payload}', name: "NotificationService");
    Map<String, dynamic> data = {};
    if (notificationResponse.payload != null && notificationResponse.payload!.isNotEmpty) {
      // Assuming payload could be a route or an issueId.
      // If it's just an issueId, we assume the route is '/issue_details'
      if (notificationResponse.payload!.startsWith('/')) { // Looks like a route
         data['navigateTo'] = notificationResponse.payload;
      } else { // Assume it's an issueId
         data['navigateTo'] = '/issue_details';
         data['issueId'] = notificationResponse.payload;
      }
    }
    _handleNotificationTap(data);
  }

  // Instance method to handle all notification taps that require navigation
  void _handleNotificationTap(Map<String, dynamic> data) {
    final String? navigateTo = data['navigateTo'] as String?;
    final String? issueId = data['issueId'] as String?;

    developer.log("Handling notification tap. NavigateTo: $navigateTo, IssueID: $issueId", name: "NotificationService");

    // Ensure navigatorKey.currentState is not null before attempting to use it.
    if (navigatorKey.currentState == null) {
      developer.log("NavigatorKey current state is null, cannot navigate.", name: "NotificationService");
      return;
    }

    if (navigateTo != null && navigateTo.isNotEmpty) {
      if (navigateTo == '/issue_details' && issueId != null && issueId.isNotEmpty) {
        navigatorKey.currentState!.pushNamed(navigateTo, arguments: issueId);
      } else {
        // For general routes that don't need arguments or have them embedded
        navigatorKey.currentState!.pushNamed(navigateTo);
      }
    } else if (issueId != null && issueId.isNotEmpty) {
      // Fallback: if only issueId is present, assume navigation to issue details
      developer.log("No 'navigateTo' but issueId is present. Navigating to /issue_details with $issueId", name: "NotificationService");
      navigatorKey.currentState!.pushNamed('/issue_details', arguments: issueId);
    }
    else {
      developer.log("No 'navigateTo' route or 'issueId' found in notification data.", name: "NotificationService");
    }
  }
}

// This must be a top-level function as per flutter_local_notifications documentation for background handling
@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
  developer.log('Local notification tapped (background/terminated): ${notificationResponse.payload}', name: "NotificationServiceBGCallback");
  // This is tricky because you don't have access to the NotificationService instance or its navigatorKey here.
  // One common approach is to save the payload (e.g., route or issueId) to SharedPreferences.
  // Then, when the app starts/resumes, check SharedPreferences and navigate.
  // For simplicity in this iteration, we'll primarily rely on FCM's onMessageOpenedApp and getInitialMessage
  // for taps that open the app. This handler is more for actions on local notifications when the app is not in the foreground.
  // If you need navigation from here, it requires a more complex setup (e.g., plugins that can communicate with the main isolate).
  // For now, just log.
}
