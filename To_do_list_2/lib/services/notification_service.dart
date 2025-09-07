import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/task.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    // Android notification settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS notification settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request permissions for notifications
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    // Request permission on iOS
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request permission on Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap
    // TODO: Navigate to specific task when notification is tapped
  }

  // Schedule notification for exact due time
  static Future<void> scheduleDueDateNotification(Task task) async {
    if (task.dueDate == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'task_due_channel',
      'Task Due Notifications',
      channelDescription: 'Notifications for when tasks are due',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convert to timezone-aware DateTime
    final scheduledDate = tz.TZDateTime.from(task.dueDate!, tz.local);

    // Only schedule if the due date is in the future
    if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      await _notifications.zonedSchedule(
        int.parse(task.id.substring(task.id.length - 8)), // Use last 8 digits as unique ID
        'Task Due Now! ⏰',
        '${task.title} is due now',
        scheduledDate,
        notificationDetails,
        payload: 'due_${task.id}',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  // Schedule notification 1 hour before due time
  static Future<void> scheduleOneHourBeforeNotification(Task task) async {
    if (task.dueDate == null) return;

    // Calculate 1 hour before due date
    final oneHourBefore = task.dueDate!.subtract(const Duration(hours: 1));

    // Only schedule if 1 hour before is in the future
    if (oneHourBefore.isAfter(DateTime.now())) {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'task_reminder_channel',
        'Task Reminder Notifications',
        channelDescription: 'Reminders 1 hour before tasks are due',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Convert to timezone-aware DateTime
      final scheduledDate = tz.TZDateTime.from(oneHourBefore, tz.local);

      await _notifications.zonedSchedule(
        int.parse(task.id.substring(task.id.length - 7)), // Different ID for reminder
        'Task Reminder! 📝',
        '${task.title} is due in 1 hour',
        scheduledDate,
        notificationDetails,
        payload: 'reminder_${task.id}',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  // Schedule both notifications for a task
  static Future<void> scheduleTaskNotifications(Task task) async {
    if (task.dueDate == null) return;

    // Cancel existing notifications for this task first
    await cancelTaskNotifications(task);

    // Schedule new notifications
    await scheduleDueDateNotification(task);
    await scheduleOneHourBeforeNotification(task);
  }

  // Cancel notifications for a specific task
  static Future<void> cancelTaskNotifications(Task task) async {
    // Cancel due date notification
    await _notifications.cancel(int.parse(task.id.substring(task.id.length - 8)));
    // Cancel reminder notification
    await _notifications.cancel(int.parse(task.id.substring(task.id.length - 7)));
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Get pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}