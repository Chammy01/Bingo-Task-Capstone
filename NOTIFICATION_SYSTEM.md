# Notification System Documentation

## Overview
This document describes the local notification system implemented for the Bingo Task app using the godot-notification-scheduler plugin.

## Features

### 1. No Tasks Added Notification
**Purpose:** Re-engage users who haven't planned their day

- **When:** User opens the app but hasn't added any tasks
- **Frequency:** Repeats every 2 hours until a task is added
- **Intervals:**
  - Production: 7200 seconds (2 hours)
  - Debug: 10 seconds
- **Messages:** Rotates randomly between 5 motivational messages:
  - "You haven't planned anything yet! Add your first task to get started."
  - "A goal is a dream with a deadline. What's your first move?"
  - "Success starts with a single task. Plan for progress!"
  - "Make today count—write down a goal!"
  - "Start small and win big. Add a Bingo!"
- **Stops When:** User adds their first task

### 2. No Progress Notification
**Purpose:** Nudge users who planned but aren't making progress

- **When:** User has added tasks but hasn't completed any in 3 hours
- **Frequency:** One-time after 3 hours of inactivity, resets after each completion
- **Intervals:**
  - Production: 10800 seconds (3 hours)
  - Debug: 15 seconds
- **Message:** "No progress for a while. You have X tasks waiting!"
- **Resets When:** User completes any task (timer restarts for another 3 hours)
- **Stops When:** All tasks are completed

### 3. Hourly Progress Reminders
**Purpose:** Keep users motivated with regular progress updates

- **When:** Tasks exist and are not all completed
- **Frequency:** Every 1 hour while tasks remain
- **Intervals:**
  - Production: 3600 seconds (1 hour)
  - Debug: 7 seconds
- **Adaptive Messages based on completion percentage:**
  - 0% complete: "Let's get started—your tasks await!"
  - <50% complete: "You've completed X% of your tasks. Keep going!"
  - ≥50% complete: "Awesome! X% done. Nearly there!"
- **Stops When:** All tasks completed (100%)

### 4. Daily Task Reminder
**Purpose:** Remind users twice daily about tasks they pre-planned for specific days

- **When:** User schedules tasks for a future date via calendar
- **Frequency:** Twice per scheduled day
  - Morning reminder: 6:00 AM
  - Evening reminder: 6:00 PM
- **Message:** "You have X task(s) scheduled for today. Let's get started!"
- **Works:** Completely offline using device system clock
- **Cancelled When:** User removes all tasks for that date before notifications trigger
- **Smart Scheduling:** Only schedules notifications if target time is in the future

## Technical Implementation

### Notification IDs
- No Tasks: 1000
- No Progress: 2000
- Hourly Progress: 3000
- Daily Reminders: 4000-5999
  - AM: 4000 + day_of_year
  - PM: 5000 + day_of_year

### Debug Mode
Toggle debug mode using **Ctrl+Shift+N** keyboard shortcut.

When enabled:
- Uses shorter intervals for testing (10s, 15s, 7s instead of 2h, 3h, 1h)
- Shows toast messages when notifications are scheduled/cancelled
- Prints detailed debug logs
- Persists across sessions

### Integration Points

**In board_manager.gd:**
- `NotificationManager.check_no_tasks_state()` - Called on app startup
- `NotificationManager.on_task_added()` - Called when a task is added
- `NotificationManager.on_task_completed()` - Called when a task is completed
- `NotificationManager.update_progress(completed, total)` - Called when progress changes
- `NotificationManager.schedule_daily_reminders(date_key, task_count)` - Called when scheduling tasks
- `NotificationManager.cancel_daily_reminders(date_key)` - Called when removing scheduled tasks

### Files

**New Files:**
- `NotificationManager.gd` - Main notification management autoload
- `addons/NotificationScheduler/*` - Notification scheduler plugin files

**Modified Files:**
- `project.godot` - Added NotificationManager to autoloads
- `board_manager.gd` - Added notification triggers
- `.gitignore` - Added to exclude build artifacts

## Usage

### For Developers

**Testing Notifications:**
1. Press **Ctrl+Shift+N** to enable debug mode
2. Notifications will use shorter intervals (seconds instead of hours)
3. Toast messages will appear when notifications are scheduled/cancelled
4. Press **Ctrl+Shift+N** again to disable debug mode

**Building for Android/iOS:**
1. Ensure the NotificationScheduler plugin is enabled in Project Settings → Plugins
2. Follow the plugin's platform-specific setup instructions in `addons/NotificationScheduler/`
3. Build and export to your target platform
4. Grant notification permissions when prompted

### For Users

Notifications work automatically in the background:
- Add tasks to stop "no tasks" reminders
- Complete tasks to reset the "no progress" timer
- Schedule tasks for future dates to receive 6 AM and 6 PM reminders
- All notifications work offline using your device's clock

## Platform Notes

### Android
- Requires notification permission (requested automatically)
- Works with battery optimization restrictions
- Notifications persist across app restarts

### iOS
- Requires notification permission (requested automatically)
- System limits: Max 64 repeating notifications, min 60 second interval for repeating
- Notifications scheduled use device local time

## Troubleshooting

**No notifications appearing:**
1. Check notification permissions in device settings
2. Verify NotificationScheduler plugin is enabled
3. Enable debug mode (Ctrl+Shift+N) and check console logs
4. Check device battery optimization settings

**Debug mode not working:**
1. Ensure you're pressing Ctrl+Shift+N (not just N)
2. Check console output for confirmation message
3. Setting persists in SaveManager

## Future Enhancements

Potential improvements for future versions:
- User-configurable notification intervals
- Customizable notification messages
- Time-of-day preferences for reminders
- Notification sound customization
- Snooze functionality
