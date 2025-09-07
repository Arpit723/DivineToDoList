import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final Function(String, String) onEditTask;
  final Function(String) onDeleteTask;
  final Function(String) onToggleCompletion;
  final bool isNewTask;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onToggleCompletion,
    this.isNewTask = false,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isEditing = false;
  String? _titleError;
  String? _dueDateError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    // Start in editing mode for new tasks
    _isEditing = widget.isNewTask;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reset controllers to original values if canceling edit
        _titleController.text = widget.task.title;
        _descriptionController.text = widget.task.description;
      }
    });
  }

  bool _validateForm() {
    setState(() {
      _titleError = null;
      _dueDateError = null;
    });

    bool isValid = true;
    final newTitle = _titleController.text.trim();

    // Validate title
    if (newTitle.isEmpty) {
      setState(() {
        _titleError = 'Task title is required';
      });
      isValid = false;
    } else if (newTitle.length < 3) {
      setState(() {
        _titleError = 'Task title must be at least 3 characters';
      });
      isValid = false;
    } else if (newTitle.length > 100) {
      setState(() {
        _titleError = 'Task title must be less than 100 characters';
      });
      isValid = false;
    }

    // Validate due date (if set, it should be in the future for new tasks)
    if (widget.isNewTask && widget.task.dueDate != null) {
      final now = DateTime.now();
      if (widget.task.dueDate!.isBefore(now)) {
        setState(() {
          _dueDateError = 'Due date must be in the future';
        });
        isValid = false;
      }
    }

    return isValid;
  }

  void _saveChanges() {
    if (!_validateForm()) {
      return;
    }

    final newTitle = _titleController.text.trim();
    final newDescription = _descriptionController.text.trim();
    
    if (widget.isNewTask) {
      // For new task, add it to the main task list
      widget.onEditTask(widget.task.id, newTitle);
      Navigator.of(context).pop(); // Go back to main screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created successfully!')),
      );
    } else {
      // For existing task, update all fields
      setState(() {
        widget.task.title = newTitle;
        widget.task.description = newDescription;
      });
      
      // Save the updated task
      widget.onEditTask(widget.task.id, newTitle);
      
      // Navigate back to task list
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated successfully!')),
      );
    }
  }

  void _saveStatusChange() {
    // Just trigger the save mechanism to persist the status change
    widget.onEditTask(widget.task.id, widget.task.title);
  }

  Future<void> _selectDueDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.task.dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: widget.task.dueDate != null 
            ? TimeOfDay.fromDateTime(widget.task.dueDate!) 
            : TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          widget.task.dueDate = selectedDateTime;
        });
        
        // Schedule notifications for the new due date
        NotificationService.scheduleTaskNotifications(widget.task);
        
        // Auto-save the due date change
        if (!widget.isNewTask) {
          widget.onEditTask(widget.task.id, widget.task.title);
        }
      }
    }
  }

  void _clearDueDate() {
    // Cancel notifications before clearing due date
    NotificationService.cancelTaskNotifications(widget.task);
    
    setState(() {
      widget.task.dueDate = null;
    });
    
    // Auto-save the due date change
    if (!widget.isNewTask) {
      widget.onEditTask(widget.task.id, widget.task.title);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Text('Are you sure you want to delete "${widget.task.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onDeleteTask(widget.task.id);
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to main screen
              },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNewTask 
            ? 'Create New Task' 
            : (_isEditing ? 'Edit Task' : 'Task Details')),
        actions: [
          if (widget.isNewTask) ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Create Task',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Save Changes',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
              tooltip: 'Delete Task',
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + 20.0), // Extra bottom padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Task Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...TaskStatus.values.map((status) {
                      final isSelected = widget.task.status == status;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            if (widget.task.status != status) {
                              setState(() {
                                widget.task.status = status;
                              });
                              _saveStatusChange();
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                isSelected 
                                    ? Icons.radio_button_checked 
                                    : Icons.radio_button_unchecked,
                                color: isSelected ? const Color(0xFF8B0000) : Colors.grey,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                status.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? const Color(0xFF8B0000) : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Task Title Section
            const Text(
              'Task Title',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B0000),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Enter task title...',
                errorText: _titleError,
                errorStyle: const TextStyle(color: Colors.red),
              ),
              style: TextStyle(
                decoration: widget.task.isCompleted 
                    ? TextDecoration.lineThrough 
                    : TextDecoration.none,
                color: widget.task.isCompleted 
                    ? Colors.grey 
                    : Colors.black,
              ),
              onChanged: (value) {
                if (_titleError != null) {
                  setState(() {
                    _titleError = null;
                  });
                }
              },
            ),
            
            const SizedBox(height: 24),
            
            // Task Description Section
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B0000),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter task description (optional)...',
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Due Date Section
            const Text(
              'Due Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B0000),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: widget.task.isOverdue ? Colors.red : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.task.dueDateDisplay,
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.task.isOverdue ? Colors.red : Colors.black,
                            fontWeight: widget.task.isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: _selectDueDate,
                        tooltip: 'Set due date',
                      ),
                      if (widget.task.dueDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: _clearDueDate,
                          tooltip: 'Clear due date',
                        ),
                    ],
                  ),
                  if (widget.task.isOverdue)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'This task is overdue!',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (_dueDateError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _dueDateError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Category Selection Section
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<TaskCategory>(
              value: widget.task.category,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: TaskCategory.values.map((category) {
                return DropdownMenuItem<TaskCategory>(
                  value: category,
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        color: Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(category.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (TaskCategory? newCategory) {
                if (newCategory != null) {
                  setState(() {
                    widget.task.category = newCategory;
                  });
                  
                  // Auto-save the category change
                  if (!widget.isNewTask) {
                    widget.onEditTask(widget.task.id, widget.task.title);
                  }
                }
              },
            ),
            
            const SizedBox(height: 24),
            
            // Task Details Section
            const Text(
              'Task Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Created Date
            _buildDetailRow(
              icon: Icons.schedule,
              label: 'Created',
              value: _formatDateTime(widget.task.createdAt),
            ),
            
            const SizedBox(height: 8),
            
            // Task ID
            _buildDetailRow(
              icon: Icons.fingerprint,
              label: 'Task ID',
              value: widget.task.id,
            ),
            
            const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SelectableText(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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
