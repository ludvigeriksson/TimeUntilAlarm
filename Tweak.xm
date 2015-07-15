static NSString *stringFromDifference(int difference);
static int getCurrentMinute();

static int lastReloadMinute = 0;
static NSTimer *timer = nil;
static NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

// Preferences
static BOOL enableForActiveAlarmsOnly = NO;
static BOOL showNextActiveAlarmOnLockScreen = NO;

// Lockscreen properties
static NSDate *nextActiveAlarmFireDate = nil;
static int nextAlarmOnLockScreenViewSpacing = 8;
static int nextAlarmOnLockScreenViewTag = 50;
static int nextAlarmOnLockScreenLabelTag = 1;
static int nextAlarmOnLockScreenImageViewTag = 2;
static BOOL snoozedAlarmCellIsVisible = NO;

#import <SpringBoard/SBFLockScreenDateView.h>
#import <SpringBoard/SBLockScreenViewController.h>

%hook SBLockScreenViewController

- (void)startLockScreenFadeInAnimationForSource:(int)arg1 { 
	%orig; 

	id lockScreenView = self.lockScreenView;
	SBFLockScreenDateView *dateView = [lockScreenView valueForKey:@"dateView"];

	UIView *nextAlarmView = [dateView viewWithTag:nextAlarmOnLockScreenViewTag];
	UILabel *nextAlarmLabel;
	UIImageView *nextAlarmImageView;
	if (nextAlarmView == nil) {
		nextAlarmView = [[UIView alloc] init];
		nextAlarmView.tag = nextAlarmOnLockScreenViewTag;

		// Get image
		NSString *bundlePath = @"/Library/MobileSubstrate/DynamicLibraries/TimeUntilAlarmBundle.bundle";
        NSBundle *bundle = [[NSBundle alloc] initWithPath:bundlePath];
        NSString *imagePath = [bundle pathForResource:@"TimeUntilAlarmLockScreenIcon" ofType:@"png"];
        UIImage *image = [[UIImage imageWithContentsOfFile:imagePath] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

        // Add image view
		nextAlarmImageView = [[UIImageView alloc] initWithImage:image];
		nextAlarmImageView.tag = nextAlarmOnLockScreenImageViewTag;
        [nextAlarmView addSubview:nextAlarmImageView];

        // Add label
		nextAlarmLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		nextAlarmLabel.tag = nextAlarmOnLockScreenLabelTag;
		[nextAlarmView addSubview:nextAlarmLabel];

		// Add complete view to dateView
		[dateView addSubview:nextAlarmView];
	} else {
		nextAlarmLabel = (UILabel *)[nextAlarmView viewWithTag:nextAlarmOnLockScreenLabelTag];
		nextAlarmImageView = (UIImageView *)[nextAlarmView viewWithTag:nextAlarmOnLockScreenImageViewTag];
	}

	if (showNextActiveAlarmOnLockScreen && !snoozedAlarmCellIsVisible) {
		if (nextActiveAlarmFireDate != nil) {
			nextAlarmView.hidden = NO;

			int nextActiveAlarmDifference = [nextActiveAlarmFireDate timeIntervalSinceNow];
			nextAlarmLabel.text = stringFromDifference(nextActiveAlarmDifference);
			nextAlarmLabel.textColor = dateView.textColor;
			nextAlarmImageView.tintColor = dateView.textColor;
			[nextAlarmLabel sizeToFit];

			UIView *dateLabel = MSHookIvar<UIView *>(dateView, "_dateLabel");

			int imageSpace = 8;

			CGRect frame = nextAlarmLabel.frame;
			frame.origin.x = nextAlarmImageView.bounds.size.width + imageSpace;
			nextAlarmLabel.frame = frame;

			frame = nextAlarmImageView.frame;
			frame.origin.y = nextAlarmLabel.frame.origin.y + nextAlarmLabel.frame.size.height / 2 - nextAlarmImageView.frame.size.height / 2;
			nextAlarmImageView.frame = frame;

			frame = nextAlarmView.frame;
			frame.origin.x = CGRectGetMidX(dateView.bounds) - nextAlarmLabel.bounds.size.width / 2 - nextAlarmImageView.bounds.size.width / 2 - imageSpace / 2;
			frame.origin.y = CGRectGetMaxY(dateLabel.frame) + nextAlarmOnLockScreenViewSpacing;
			nextAlarmView.frame = frame;
		} else {
			nextAlarmView.hidden = YES;
		}

	} else {
		nextAlarmView.hidden = YES;
	}

}

%end

%hook SBLockScreenSnoozedAlarmCell
// Used to hide the lock screen label when the regular snooze cell is visible

- (void)setFireDate:(NSDate *)fireDate {
	snoozedAlarmCellIsVisible = (fireDate != nil);
	%orig;
}

%end


#import <MobileTimer/UIConcreteLocalNotification.h>

%hook SBClockDataProvider
// Used to save the next active alarm fire date

// Called every time any notifications (e.g. alarms, timers) changes
- (id)_scheduledNotifications { 
	id r = %orig;

	NSArray *notifications = (NSArray *)r;

	NSDate *earliestFireDate = nil;
	for (UIConcreteLocalNotification *notification in notifications) {
		id userInfo = notification.userInfo;
		if (userInfo[@"alarmId"] != nil) {
			// Notification is alarm (not timer for example)
			id nextFireDate = [notification nextFireDateAfterDate:[NSDate date] localTimeZone:notification.timeZone];
			if (earliestFireDate == nil) {
				earliestFireDate = nextFireDate;
			} else {
				id earlierDate = [earliestFireDate earlierDate:nextFireDate];
				earliestFireDate = earlierDate;
			}
		}
	}
	nextActiveAlarmFireDate = [earliestFireDate copy];

	return r; 
}

%end






#import <MobileTimer/Alarm.h>

%hook AlarmTableViewCell
// Used to calculate time left and set the time left label's text

- (void)refreshUI:(id)ui animated:(BOOL)animated { 

	UIView *alarmView = MSHookIvar<UIView *>(self, "_alarmView");

	// Get the time of the alarm as seconds into the day
	int alarmHours = [[ui valueForKey:@"hour"] intValue];
	int alarmMinutes = [[ui valueForKey:@"minute"] intValue];
	int daySetting = [[ui valueForKey:@"daySetting"] intValue];

	Alarm *alarm = [[Alarm alloc] init];
	alarm.daySetting = daySetting;
	alarm.hour = alarmHours;
	alarm.minute = alarmMinutes;

	NSDate *nextFireDate = [alarm nextFireDate];
	NSTimeInterval difference = [nextFireDate timeIntervalSinceNow];

	// Get the label to present the time remaining
	UILabel *label = (UILabel *)[alarmView viewWithTag:50];
	if (label == nil) {
		// Create the label if it doesn't already exists (cells gets reused)
		label = [[UILabel alloc] init];
		label.tag = 50;
		label.font = [UIFont systemFontOfSize:17];
		[alarmView addSubview:label];
	}

	// Set the label text to the time remaining
	label.text = stringFromDifference(difference);
	[label sizeToFit];

	// Positioning occurs in layoutSubviews in AlarmView

	%orig; 
}

%end

@interface AlarmView : UIView
@end

%hook AlarmView
// Used to position the time left label

- (void)layoutSubviews {
	%orig;

	// Get the label to present the time remaining
	UILabel *label = (UILabel *)[self viewWithTag:50];
	if (label != nil) {
		UIView *enabledSwitch = MSHookIvar<UIView *>(self, "_enabledSwitch");

		BOOL showLabel = YES;
		if (enableForActiveAlarmsOnly) {
			showLabel = [[enabledSwitch valueForKey:@"isOn"] boolValue];
		}

		if (showLabel) {
			label.hidden = NO;

			// Set the color to match the time label's color
			UIView *timeLabel = MSHookIvar<UIView *>(self, "_timeLabel");
			label.textColor = (UIColor *)[timeLabel valueForKey:@"textColor"];

			// Position the label above the switch
			CGFloat x = CGRectGetMaxX(enabledSwitch.frame) - label.bounds.size.width;
			CGFloat y = enabledSwitch.frame.origin.y / 2 - label.bounds.size.height / 2;
			label.frame = CGRectMake(x, y, label.bounds.size.width, label.bounds.size.height);
		} else {
			label.hidden = YES;
		}
	}
}

%end

@interface AlarmViewController : UITableViewController
@end

%hook AlarmViewController
// Used to reload the table view when the app opens and when minute changes

- (void)viewDidLoad {
	%orig;

	// Table view does not reload automatically when app enters foreground
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(applicationDidEnterForeground) 
												 name:UIApplicationDidBecomeActiveNotification
											   object:[UIApplication sharedApplication]];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(applicationWillTerminate) 
												 name:UIApplicationWillTerminateNotification
											   object:[UIApplication sharedApplication]];
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;

	lastReloadMinute = getCurrentMinute();

	// Reload table view when minute changes (check every second for minute change)
	timer = [NSTimer scheduledTimerWithTimeInterval:1
											 target:self
										   selector:@selector(reloadTableViewOnMinuteChange)
										   userInfo:nil
											repeats:YES];
	timer.tolerance = 1;
}

- (void)viewWillDisappear:(BOOL)animated {
	%orig;

	// Remove timer
	[timer invalidate];
	timer = nil;
}

%new
- (void)reloadTableViewOnMinuteChange {
	int currentMinute = getCurrentMinute();

	if (lastReloadMinute != currentMinute) {
		// Minute has changed, reload table view
		lastReloadMinute = currentMinute;
		[[self valueForKey:@"tableView"] reloadData];
	}
}

%new
- (void)applicationDidEnterForeground {
	// Reload table view when app enters foreground and view controller is visible
	if ([[self valueForKey:@"isViewLoaded"] boolValue]) {
		if ([[self valueForKey:@"view"] valueForKey:@"window"] != nil) {
			[[self valueForKey:@"tableView"] reloadData];
		}
	}
}

%new
- (void)applicationWillTerminate {
	// Remove observers before app terminates
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIApplicationDidBecomeActiveNotification
												  object:[UIApplication sharedApplication]];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIApplicationWillTerminateNotification
												  object:[UIApplication sharedApplication]];
}

%end



static UILabel *timeLeftLabel = nil;
static BOOL isNewAlarm = NO;

#import "MobileTimer/EditAlarmView.h"

@interface EditAlarmViewController : UITableViewController
@end

%hook EditAlarmViewController
// The view controller that edits an alarm (presented modally)
// Used to add a time left label in the header of the table view

- (id)initWithAlarm:(id)alarm { 
	// Save whether the view controller was opened by creating a new alarm or not
	isNewAlarm = (alarm == nil);
	return %orig;
}

- (void)viewDidLoad {
	%orig;
	
	// Setup time left label
	timeLeftLabel = [[UILabel alloc] init];
	timeLeftLabel.textColor = [UIColor darkGrayColor];

	// Get the settings table view
	EditAlarmView *editAlarmView = MSHookIvar<EditAlarmView *>(self, "_editAlarmView");
	UITableView *settingsTable = MSHookIvar<UITableView *>(editAlarmView, "_settingsTable");
	
	// Create table view header and add time left label
	CGRect frame = CGRectMake(0, 0, settingsTable.bounds.size.width, 44);

	settingsTable.tableHeaderView = [[UIView alloc] initWithFrame:frame];
	[settingsTable.tableHeaderView addSubview:timeLeftLabel];
}

- (void)viewWillAppear:(BOOL)view {
	%orig;

	Alarm *alarm = (Alarm *)[self valueForKey:@"alarm"];
	if (alarm != nil && !isNewAlarm) {
		// Opened by editing existing alarm
		isNewAlarm = NO;
		Alarm *editingProxy = alarm.editingProxy;
		NSDate *nextFireDate = [editingProxy nextFireDate];
		int difference = [nextFireDate timeIntervalSinceNow];
		timeLeftLabel.text = stringFromDifference(difference);
	} else {
		// Opened by creating new alarm
		timeLeftLabel.text = stringFromDifference(0);
	}

	// Center timeLeftLabel in settings table header
	EditAlarmView *editAlarmView = MSHookIvar<EditAlarmView *>(self, "_editAlarmView");
	UITableView *settingsTable = MSHookIvar<UITableView *>(editAlarmView, "_settingsTable");
	[timeLeftLabel sizeToFit];
	timeLeftLabel.center = settingsTable.tableHeaderView.center;
}

- (void)viewDidLayoutSubviews {
	%orig;

	// Center time left label
	EditAlarmView *editAlarmView = MSHookIvar<EditAlarmView *>(self, "_editAlarmView");
	UITableView *settingsTable = MSHookIvar<UITableView *>(editAlarmView, "_settingsTable");
	timeLeftLabel.center = settingsTable.tableHeaderView.center;
}

- (void)handlePickerChanged { 
	%orig;

	// Get the picked time
	EditAlarmView *editAlarmView = MSHookIvar<EditAlarmView *>(self, "_editAlarmView");
	UIDatePicker *timePicker = MSHookIvar<UIDatePicker *>(editAlarmView, "_timePicker");

	int pickedTime = timePicker.countDownDuration;

	// Calculate next fire date
	Alarm *alarm = (Alarm *)[self valueForKey:@"alarm"];
	Alarm *editingProxy = alarm.editingProxy;
	Alarm *newAlarm = editingProxy;
	newAlarm.hour = pickedTime / 3600;
	newAlarm.minute = (pickedTime % 3600) / 60;
	NSDate *nextFireDate = [newAlarm nextFireDate];

	// Set timeLeftLabel to difference
	int difference = [nextFireDate timeIntervalSinceNow];
	timeLeftLabel.text = stringFromDifference(difference);

	// Center timeLeftLabel in settings table header
	UITableView *settingsTable = MSHookIvar<UITableView *>(editAlarmView, "_settingsTable");
	[timeLeftLabel sizeToFit];
	timeLeftLabel.center = settingsTable.tableHeaderView.center;
}

%end

static int getCurrentMinute() {
	NSDateComponents *components = [calendar components:NSMinuteCalendarUnit fromDate:[NSDate date]];
	return [components minute];
}

static NSString *stringFromDifference(int difference) {
	if (difference > 0) {
		difference += 60; // Round to next minute
	}

	// Convert the difference to days, hours and minutes
	int days = difference / 86400;
	int hours = (difference % 86400) / 3600;
	int minutes = ((difference % 86400) % 3600) / 60;

	// Turn into string
	NSString *daysString = (days > 0) ? [NSString stringWithFormat:@"%dd ", days] : @"";
	NSString *hoursString = (hours > 0) ? [NSString stringWithFormat:@"%dh ", hours] : @"";
	NSString *minuteString = (minutes > 0) ? [NSString stringWithFormat:@"%dm", minutes] : @"";
	if (days == 0 && hours == 0 && minutes == 0) {
		minuteString = [NSString stringWithFormat:@"%dm", minutes];
	}
	return [NSString stringWithFormat:@"%@%@%@", daysString, hoursString, minuteString];
}

static CFStringRef settingsChangedNotification = CFSTR("com.ludvigeriksson.timeuntilalarmprefs/settingschanged");
static CFStringRef timeUntilAlarmPrefsKey = CFSTR("com.ludvigeriksson.timeuntilalarmprefs");
static CFStringRef enableForActiveAlarmsOnlyKey = CFSTR("TUAEnableForActiveAlarmsOnly");
static CFStringRef showNextActiveAlarmOnLockScreenKey = CFSTR("TUAShowNextActiveAlarmOnLockScreen");

static void loadPrefs() {
    CFPreferencesAppSynchronize(timeUntilAlarmPrefsKey);
    if (CFBridgingRelease(CFPreferencesCopyAppValue(enableForActiveAlarmsOnlyKey, timeUntilAlarmPrefsKey))) {
        enableForActiveAlarmsOnly = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(enableForActiveAlarmsOnlyKey, timeUntilAlarmPrefsKey)) boolValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(showNextActiveAlarmOnLockScreenKey, timeUntilAlarmPrefsKey))) {
        showNextActiveAlarmOnLockScreen = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(showNextActiveAlarmOnLockScreenKey, timeUntilAlarmPrefsKey)) boolValue];
    }
}

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, settingsChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    loadPrefs();
}