import 'package:flutter/material.dart';
import 'models/task.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'screens/task_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await NotificationService.initialize();
  
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List',
      theme: ThemeData(
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B0000), // Dark red
          primary: const Color(0xFF8B0000), // Dark red
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF8B0000), // Dark red text
          elevation: 2,
          shadowColor: Colors.grey,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold),
          titleSmall: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF8B0000),
          foregroundColor: Colors.white,
        ),
      ),
      home: const TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Load tasks from storage when app starts
  Future<void> _loadTasks() async {
    final loadedTasks = await StorageService.loadTasks();
    setState(() {
      tasks = loadedTasks;
    });
  }

  // Save tasks to storage whenever tasks change
  Future<void> _saveTasks() async {
    await StorageService.saveTasks(tasks);
  }

  void _navigateToNewTask() {
    // Create a temporary task for the new task screen
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '',
      description: '',
      createdAt: DateTime.now(),
      dueDate: null,
      category: TaskCategory.transportation,
      status: TaskStatus.assigned,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(
          task: newTask,
          onEditTask: _addTask,
          onDeleteTask: _deleteTask,
          onToggleCompletion: _toggleTaskStatus,
          isNewTask: true,
        ),
      ),
    );
  }

  void _addTask(String taskId, String title) {
    final newTask = Task(
      id: taskId,
      title: title,
      description: '',
      createdAt: DateTime.now(),
      dueDate: null,
      category: TaskCategory.transportation,
      status: TaskStatus.assigned,
    );
    
    // Find the existing temporary task to get its due date
    final tempTask = tasks.firstWhere((task) => task.id == taskId, orElse: () => newTask);
    if (tempTask.dueDate != null) {
      newTask.dueDate = tempTask.dueDate;
      newTask.category = tempTask.category;
      newTask.description = tempTask.description;
    }
    
    setState(() {
      // Remove the temporary task if it exists
      tasks.removeWhere((task) => task.id == taskId);
      // Add the new task
      tasks.add(newTask);
    });
    
    // Schedule notifications if due date is set
    if (newTask.dueDate != null) {
      NotificationService.scheduleTaskNotifications(newTask);
    }
    
    _saveTasks(); // Save after adding task
  }

  void _toggleTaskStatus(String taskId) {
    setState(() {
      // Find the task with this ID and cycle through statuses
      for (var task in tasks) {
        if (task.id == taskId) {
          switch (task.status) {
            case TaskStatus.assigned:
              task.status = TaskStatus.started;
              break;
            case TaskStatus.started:
              task.status = TaskStatus.completed;
              break;
            case TaskStatus.completed:
              task.status = TaskStatus.assigned;
              break;
          }
          break;
        }
      }
    });
    _saveTasks(); // Save after status change
  }

  void _editTask(String taskId, String newTitle) {
    Task? updatedTask;
    setState(() {
      for (var task in tasks) {
        if (task.id == taskId) {
          task.title = newTitle;
          updatedTask = task;
          break;
        }
      }
    });
    
    // Reschedule notifications if due date is set
    if (updatedTask != null && updatedTask!.dueDate != null) {
      NotificationService.scheduleTaskNotifications(updatedTask!);
    }
    
    _saveTasks(); // Save after editing task
  }

  void _deleteTask(String taskId) {
    // Find the task before deleting to cancel its notifications
    final taskToDelete = tasks.firstWhere((task) => task.id == taskId);
    
    // Cancel notifications for this task
    NotificationService.cancelTaskNotifications(taskToDelete);
    
    setState(() {
      tasks.removeWhere((task) => task.id == taskId);
    });
    _saveTasks(); // Save after deleting task
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To Do List'),
      ),
      body: tasks.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No tasks yet!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
                    return Dismissible(
            key: Key(task.id),
            background: Container(
              color: const Color(0xFF8B0000),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Row(
                children: [
                  Icon(Icons.edit, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            secondaryBackground: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.delete, color: Colors.white),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                // Swipe right to edit
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailScreen(
                      task: task,
                      onEditTask: _editTask,
                      onDeleteTask: _deleteTask,
                      onToggleCompletion: _toggleTaskStatus,
                    ),
                  ),
                );
                return false; // Don't dismiss
              } else {
                // Swipe left to delete - show confirmation
                return await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Delete Task'),
                      content: Text('Are you sure you want to delete "${task.title}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                _deleteTask(task.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${task.title} deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: task.isOverdue && !task.isCompleted
                    ? const Icon(Icons.warning, color: Colors.red, size: 24)
                    : Icon(_getCategoryIcon(task.category), color: const Color(0xFF8B0000), size: 24),
                title: Text(
                  task.title,
                  style: TextStyle(
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough 
                        : TextDecoration.none,
                    color: task.isCompleted 
                        ? Colors.grey 
                        : (task.isOverdue ? Colors.red.shade700 : Colors.black),
                    fontWeight: task.isOverdue && !task.isCompleted 
                        ? FontWeight.bold 
                        : FontWeight.normal,
                  ),
                ),
                subtitle: task.dueDate != null
                    ? Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: task.isOverdue ? Colors.red : const Color(0xFF8B0000),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.dueDateDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              color: task.isOverdue ? Colors.red : const Color(0xFF8B0000),
                              fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailScreen(
                        task: task,
                        onEditTask: _editTask,
                        onDeleteTask: _deleteTask,
                        onToggleCompletion: _toggleTaskStatus,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Debug: Check permissions button
          FloatingActionButton.small(
            onPressed: () async {
              final hasPermission = await NotificationService.checkAndRequestPermissions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(hasPermission 
                        ? 'Notifications enabled ✅' 
                        : 'Notifications disabled ❌\nPlease enable in device Settings > Apps > To Do List 2 > Notifications'),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            tooltip: 'Check Permissions',
            backgroundColor: Colors.green,
            child: const Icon(Icons.security, size: 16),
          ),
          const SizedBox(height: 8),
          // Debug: Simple test notification (for iOS simulator)
          FloatingActionButton.small(
            onPressed: () async {
              await NotificationService.showSimpleTestNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simple notification sent!')),
                );
              }
            },
            tooltip: 'Simple Test',
            backgroundColor: Colors.purple,
            child: const Icon(Icons.star, size: 16),
          ),
          const SizedBox(height: 8),
          // Debug: Test notification button (remove in production)
          FloatingActionButton.small(
            onPressed: () async {
              await NotificationService.showTestNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent! Check notification center.')),
                );
              }
            },
            tooltip: 'Test Notification',
            backgroundColor: Colors.orange,
            child: const Icon(Icons.notifications_active, size: 16),
          ),
          const SizedBox(height: 8),
          // Debug: Show pending notifications
          FloatingActionButton.small(
            onPressed: () async {
              final pending = await NotificationService.getPendingNotifications();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Pending notifications: ${pending.length}')),
                );
              }
            },
            tooltip: 'Check Pending',
            backgroundColor: Colors.blue,
            child: const Icon(Icons.list, size: 16),
          ),
          const SizedBox(height: 8),
          // Main add task button
          FloatingActionButton(
            onPressed: _navigateToNewTask,
            tooltip: 'Add Task',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(TaskCategory category) {
    switch (category) {
      case TaskCategory.transportation:
        return Icons.directions_car;
      case TaskCategory.food:
        return Icons.restaurant;
      case TaskCategory.bills:
        return Icons.receipt_long;
      case TaskCategory.bigExpenditure:
        return Icons.attach_money;
      case TaskCategory.medicines:
        return Icons.medical_services;
    }
  }
 }
