# Testing Notifications in DueTrack

This guide explains how to test the notification system in your DueTrack app.

## Testing in iOS Simulator

### Good News! 
iOS Simulator **does support local notifications** starting with iOS 14+. You can test notifications without a physical device.

### Steps to Test:

1. **Run the app in Simulator**
   - Select a simulator (e.g., iPhone 17)
   - Press `Cmd + R` to run

2. **Grant Notification Permission**
   - When the app launches, it will request notification permission
   - Click "Allow" when prompted
   - If you denied it, go to: Settings > DueTrack > Notifications > Allow Notifications

3. **Create a Test Bill**
   - Tap the "+" button to create a new bill
   - Set up a bill with a due date **today or tomorrow** for quick testing:
     - **Name**: "Test Bill"
     - **Amount**: $50.00
     - **Due Day**: Set to today's date (or tomorrow)
     - **Frequency**: Monthly
     - **Category**: Utilities
   - Save the bill

4. **Check Notification Schedule**
   - The app schedules notifications for:
     - 1 day before due date
     - 3 days before due date
     - 7 days before due date
     - 1 day after due date (overdue alert)

5. **View Scheduled Notifications**
   - Notifications appear at the scheduled time
   - In simulator, you can see them as banners at the top
   - Pull down from top to see Notification Center

### Quick Test Method (Fast Results):

To test notifications quickly, create a bill with:
- **Due Day**: Today's date
- This will trigger:
  - Overdue alert tomorrow (1 day after)
  - Or if due today, you'll see reminders scheduled

## Testing on Real Device

### Steps:

1. **Connect Your iPhone/iPad**
   - Connect via USB
   - Trust the computer if prompted
   - Select your device in Xcode

2. **Build and Run**
   - Press `Cmd + R`
   - App installs on your device

3. **Grant Permissions**
   - Allow notifications when prompted
   - Or go to: Settings > DueTrack > Notifications

4. **Create Test Bills**
   - Create bills with various due dates
   - Test different scenarios

5. **Wait for Notifications**
   - Notifications appear at scheduled times
   - Lock your device to see lock screen notifications
   - Check Notification Center

## Testing Different Scenarios

### Test Case 1: Upcoming Bill (7 days)
1. Create bill with due date = today + 7 days
2. You should get a notification today (7 days before)
3. Another notification in 4 days (3 days before)
4. Another notification in 6 days (1 day before)

### Test Case 2: Overdue Bill
1. Create bill with due date = yesterday
2. You should get an overdue alert tomorrow (1 day after due date)

### Test Case 3: Mark as Paid
1. Create a bill
2. Mark it as paid
3. Notifications should be cancelled
4. New notifications scheduled for next occurrence

## Debugging Notifications

### Check if Notifications are Scheduled:

Add this debug code temporarily to see scheduled notifications:

```swift
// Add this to SettingsView or a debug view
func listScheduledNotifications() {
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
        print("Scheduled notifications: \(requests.count)")
        for request in requests {
            print("ID: \(request.identifier)")
            print("Title: \(request.content.title)")
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                print("Scheduled for: \(trigger.dateComponents)")
            }
        }
    }
}
```

### Common Issues:

1. **Notifications Not Appearing**
   - Check notification permissions: Settings > DueTrack > Notifications
   - Make sure "Allow Notifications" is ON
   - Check "Lock Screen", "Notification Center", and "Banners" are enabled

2. **Notifications Scheduled in Past**
   - If you create a bill with a due date that already passed, notifications won't fire
   - Create bills with future due dates

3. **Simulator Time**
   - Make sure simulator time matches your system time
   - You can't fast-forward time in simulator for notifications

## Manual Testing Tips

### Fast Testing Method:

1. **Create Bill for Tomorrow**
   - Due date = tomorrow
   - You'll get "1 day before" notification today
   - You'll get "overdue" notification day after tomorrow

2. **Use System Clock (Advanced)**
   - On Mac: Change system time (not recommended, can cause issues)
   - Better: Wait for actual scheduled times

3. **Test Notification Content**
   - Check notification title and body
   - Verify they show correct bill name and amount
   - Check badge count updates

## Notification Settings to Check

In iOS Settings:
- Settings > DueTrack > Notifications
- Make sure all notification types are enabled:
  - Allow Notifications: ON
  - Lock Screen: ON
  - Notification Center: ON
  - Banners: ON
  - Sounds: ON (optional)
  - Badges: ON (shows count of upcoming bills)

## Testing Checklist

- [ ] App requests notification permission on first launch
- [ ] Permission granted successfully
- [ ] Creating a bill schedules notifications
- [ ] Notifications appear at correct times
- [ ] Notification content is correct (bill name, amount)
- [ ] Marking bill as paid cancels old notifications
- [ ] New notifications scheduled for next occurrence
- [ ] Badge count updates correctly
- [ ] Overdue alerts work correctly

## Quick Test Script

Here's a quick way to test:

1. **Day 1**: Create bill due in 7 days
   - Should get notification immediately (7 days before)

2. **Day 4**: Should get notification (3 days before)

3. **Day 6**: Should get notification (1 day before)

4. **Day 7**: Bill is due

5. **Day 8**: Should get overdue alert

## Pro Tips

1. **Use Real Device for Best Results**
   - Real devices handle notifications more reliably
   - You can test lock screen notifications
   - Test with device locked/unlocked

2. **Test Edge Cases**
   - Bills due on weekends
   - Bills due at month end
   - Multiple bills due same day
   - Very short notice (bill due tomorrow)

3. **Notification Timing**
   - Notifications are scheduled for specific times
   - Default is usually 9:00 AM
   - You can modify this in NotificationManager if needed

## Troubleshooting

If notifications aren't working:

1. **Check Permissions**
   ```swift
   // Add to SettingsView to check status
   UNUserNotificationCenter.current().getNotificationSettings { settings in
       print("Authorization: \(settings.authorizationStatus)")
   }
   ```

2. **Check Scheduled Notifications**
   ```swift
   UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
       print("Pending: \(requests.count)")
   }
   ```

3. **Reset Notification Permissions**
   - Delete app from device
   - Reinstall
   - Grant permissions again

4. **Check Console Logs**
   - In Xcode, check Console for errors
   - Look for notification-related errors

## Testing Notification Content

Verify notifications show:
- ✅ Correct bill name
- ✅ Correct amount
- ✅ Correct due date information
- ✅ Appropriate emoji/icon (if added)
- ✅ Actionable content

Happy testing! 🔔

