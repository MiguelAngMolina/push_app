import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:push_app/firebase_options.dart';

import 'package:push_app/domain/entities/push_message.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  int pushNumerId = 0;
  final Future<void> Function()? requestLocalNotificationPermission;
  final void Function({
    required int id,
    String? title,
    String? body,
    String? data,
  })? showLocalNotifications;

  NotificationsBloc({
     this.requestLocalNotificationPermission,
     this.showLocalNotifications
    }) : super(const NotificationsState()) {
    on<NotificationStatusChanged>(_notificationStatusChanged);
    on<NotificationReceived>(_notificationReceived);

    //  Verificar estado de las notificaciones
    _initialStatusCheck();

    //Listener para notificaciones en foreground
    _onForegroundMessage();
  }

  static Future<void> initalizeFCM() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  void _initialStatusCheck() async {
    final settings = await messaging.getNotificationSettings();
    add(NotificationStatusChanged(settings.authorizationStatus));
    _getFCMToken();
  }

  void _getFCMToken() async {
    final settings = await messaging.getNotificationSettings();

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return null;
    }

    final token = await messaging.getToken();
    print(token);
  }

  void _notificationStatusChanged(
    NotificationStatusChanged event,
    Emitter<NotificationsState> emit,
  ) {
    emit(state.copyWith(status: event.status));
    _getFCMToken();
  }

  void _notificationReceived(
    NotificationReceived event,
    Emitter<NotificationsState> emit,
  ) {
    emit(
      state.copyWith(notifications: [event.message, ...state.notifications]),
    );
  }

  void _onForegroundMessage() {
    FirebaseMessaging.onMessage.listen(handleRemoteMessage);
  }

  void handleRemoteMessage(RemoteMessage message) {
    if (message.notification == null) return;

    final notificacion = PushMessage(
      messageId:
          message.messageId?.replaceAll(':', '').replaceAll('%', '') ?? '',
      title: message.notification!.title ?? '',
      body: message.notification!.body ?? '',
      sentDate: message.sentTime ?? DateTime.now(),
      data: message.data,
      imageUrl: Platform.isAndroid
          ? message.notification!.android?.imageUrl
          : message.notification!.apple?.imageUrl,
    );


    if (showLocalNotifications != null){
    showLocalNotifications!(
      id: ++pushNumerId,
      body: notificacion.body,
      data: notificacion.messageId,
      title: notificacion.title,
    );
    }

    add(NotificationReceived(notificacion));
  }

  void requestPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    if(requestLocalNotificationPermission != null){
      await requestLocalNotificationPermission!();
    }
    

    add(NotificationStatusChanged(settings.authorizationStatus));
  }

  PushMessage? getPushMessageById(String id) {
    final exist = state.notifications.any((element) => element.messageId == id);
    print('$exist');
    print(
      "IDs en la lista: ${state.notifications.map((e) => e.messageId).toList()}",
    );
    print('$id');

    if (!exist) return null;
    return state.notifications.firstWhere((element) => element.messageId == id);
  }
}
