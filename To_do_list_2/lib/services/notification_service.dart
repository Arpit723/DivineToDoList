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
      requestCriticalPermission: true,
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
    
    // Create notification channels for Android
    await _createNotificationChannels();
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

  static Future<void> _createNotificationChannels() async {
    // Create Android notification channels
    const AndroidNotificationChannel dueDateChannel = AndroidNotificationChannel(
      'task_due_channel',
      'Task Due Notifications',
      description: 'Notifications for when tasks are due',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      'task_reminder_channel',
      'Task Reminder Notifications',
      description: 'Reminders 1 hour before tasks are due',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(dueDateChannel);
      await androidPlugin.createNotificationChannel(reminderChannel);
    }
  }

  static void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap
    // TODO: Navigate to specific task when notification is tapped
    print('Notification tapped: ${response.payload}');
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
      final notificationId = _generateNotificationId(task.id, false);
      print('Scheduling due date notification for task ${task.title} at ${scheduledDate.toString()} with ID: $notificationId');
      
      await _notifications.zonedSchedule(
        notificationId,
        'Task Due Now! ⏰',
        '${task.title} is due now',
        scheduledDate,
        notificationDetails,
        payload: 'due_${task.id}',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } else {
      print('Due date ${scheduledDate.toString()} is in the past, not scheduling notification for ${task.title}');
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
      final notificationId = _generateNotificationId(task.id, true);
      print('Scheduling reminder notification for task ${task.title} at ${scheduledDate.toString()} with ID: $notificationId');

      await _notifications.zonedSchedule(
        notificationId,
        'Task Reminder! 📝',
        '${task.title} is due in 1 hour',
        scheduledDate,
        notificationDetails,
        payload: 'reminder_${task.id}',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } else {
      print('Reminder time ${oneHourBefore.toString()} is in the past, not scheduling reminder for ${task.title}');
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

  // Generate unique notification ID from task ID
  static int _generateNotificationId(String taskId, bool isReminder) {
    // Use hash code of task ID to generate a consistent integer
    int hash = taskId.hashCode.abs();
    // Ensure it's within int32 range and add offset for reminder
    hash = hash % 2000000000; // Keep within reasonable range
    return isReminder ? hash + 1 : hash; // Different ID for reminder
  }

  // Cancel notifications for a specific task
  static Future<void> cancelTaskNotifications(Task task) async {
    // Cancel due date notification
    final dueDateId = _generateNotificationId(task.id, false);
    final reminderId = _generateNotificationId(task.id, true);
    
    print('Cancelling notifications for task ${task.title}: due date ID $dueDateId, reminder ID $reminderId');
    
    await _notifications.cancel(dueDateId);
    await _notifications.cancel(reminderId);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Get pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    print('Pending notifications count: ${pending.length}');
    for (var notification in pending) {
      print('Pending notification ID: ${notification.id}, title: ${notification.title}, body: ${notification.body}');
    }
    return pending;
  }

  // Show immediate test notification
  static Future<void> showTestNotification() async {
    print('Attempting to show test notification...');
    
    // Check if notifications are enabled on Android
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final areEnabled = await androidPlugin.areNotificationsEnabled();
      print('Android notifications enabled: $areEnabled');
    }

    // Check iOS permissions
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      print('iOS platform detected');
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_due_channel',
      'Task Due Notifications',
      channelDescription: 'Notifications for when tasks are due',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableLights: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      print('Calling _notifications.show()...');
      await _notifications.show(
        999, // Test notification ID
        'Test Notification ✅',
        'If you see this in notification center, notifications are working!',
        notificationDetails,
        payload: 'test',
      );
      print('_notifications.show() completed successfully');
      
      // Give a small delay then check pending notifications
      await Future.delayed(const Duration(milliseconds: 500));
      final pending = await getPendingNotifications();
      print('Pending notifications after test: ${pending.length}');
      
    } catch (e) {
      print('Error showing test notification: $e');
      rethrow;
    }
  }

  // Check and request notification permissions
  static Future<bool> checkAndRequestPermissions() async {
    print('Checking notification permissions...');
    
    // Check Android permissions
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final areEnabled = await androidPlugin.areNotificationsEnabled();
      print('Android notifications currently enabled: $areEnabled');
      
      if (areEnabled == false) {
        // Request permission
        final granted = await androidPlugin.requestNotificationsPermission();
        print('Android notification permission granted: $granted');
        return granted ?? false;
      }
      return areEnabled ?? false;
    }

    // Check iOS permissions  
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,
      );
      print('iOS notification permissions granted: $granted');
      return granted ?? false;
    }
    
    return false;
  }

  // Simple notification test without channels (for iOS simulator compatibility)
  static Future<void> showSimpleTestNotification() async {
    print('Showing simple test notification...');
    
    try {
      await _notifications.show(
        998,
        'Simple Test 🔔',
        'Basic notification without platform-specific details',
        const NotificationDetails(),
        payload: 'simple_test',
      );
      print('Simple notification sent');
    } catch (e) {
      print('Error with simple notification: $e');
    }
  }
}