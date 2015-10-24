// Bundle
static const NSBundle *tweakBundle = [NSBundle bundleWithPath:@"/Library/Application Support/TimeUntilAlarm"];
#define LOCALIZED(str) [tweakBundle localizedStringForKey:str value:@"" table:nil]

// Helper functions
static NSString *stringFromDate(NSDate *date);
static NSString *stringFromDifference(int difference, int format);
static int getCurrentMinute();

// Enums
typedef NS_ENUM(int, ClockAppPosition) {
	ClockAppPositionAboveSwitch = 0,
	ClockAppPositionUnderSwitch = 1,
	ClockAppPositionAfterText = 2,
	ClockAppPositionReplaceText = 3,
};
typedef NS_ENUM(int, TimeType) {
	TimeTypeTimeUntilAlarm = 0,
	TimeTypeAlarmTime = 1,
	TimeTypeBoth = 2,
};
typedef NS_ENUM(int, HorizontalPosition) {
    HorizontalPositionCustom = 0,
    HorizontalPositionLeft = 1,
    HorizontalPositionMiddle = 2,
    HorizontalPositionRight = 3,
};
typedef NS_ENUM(int, VerticalPosition) {
    VerticalPositionCustom = 0,
    VerticalPositionTop = 1,
    VerticalPositionBelowClock = 2,
    VerticalPositionBottom = 3,
};
typedef NS_ENUM(int, HorizontalStartingPoint) {
    HorizontalStartingPointLeft = 1,
    HorizontalStartingPointRight = 2,
};
typedef NS_ENUM(int, VerticalStartingPoint) {
    VerticalStartingPointTop = 1,
    VerticalStartingPointBottom = 2,
};

// Clock app properties
static BOOL enableInClockApp = YES;
static BOOL enableForActiveAlarmsOnly = NO;
static int clockAppFontSize = 17;
static int clockAppTimeFormat = 0;
static const int clockAppLabelTag = 50;
static int lastReloadMinute = 0;
static NSTimer *reloadEveryMinuteTimer = nil;

// Clock app position
static int clockAppPosition = ClockAppPositionAboveSwitch;

// Lockscreen properties
static BOOL enableOnLockScreen = NO;
static int lockScreenFontSize = 17;
static int lockScreenTimeFormat = 0;
static int lockScreenTimeType = TimeTypeTimeUntilAlarm;
static int hideOnLockScreenIf = 24; // Default to 24 hours
static BOOL hideOnLockScreenWhenMusicIsPlaying = false;
static BOOL snoozedAlarmCellIsVisible = NO;
static NSDate *nextActiveAlarmFireDate = nil;

static const int nextAlarmOnLockScreenViewTag = 50;
static const int nextAlarmOnLockScreenLabelTag = 1;
static const int nextAlarmOnLockScreenImageViewTag = 2;

// Lockscreen positioning
static const int nextAlarmOnLockScreenViewSpacing = 8;
static const int nextAlarmOnLockScreenTopBottomSpacing = 20;
static int lockScreenImageViewDefaultSize = 20;
static int lockScreenHorizontalPosition = HorizontalPositionMiddle;
static int lockScreenVerticalPosition = VerticalPositionBelowClock;
static int lockScreenHorizontalPositionValue = 0;
static int lockScreenVerticalPositionValue = 0;
static int lockScreenHorizontalPositionStartingPoint = HorizontalStartingPointLeft;
static int lockScreenVerticalPositionStartingPoint = VerticalStartingPointTop;







// LOCKSCREEN

%group LockScreenHooks

@interface SBLockScreenViewController : UITableViewController
- (id)lockScreenView;
- (BOOL)isShowingMediaControls;
- (_Bool)lockScreenIsShowingBulletins;

- (void)resizeAlarmView:(UIView *)alarmView;
- (NSString *)nextAlarmLabelText:(NSTimeInterval)difference;
- (UIView *)createAlarmView;
- (CGRect)frameForAlarmView:(UIView *)view;
@end

@interface SBFLockScreenDateView : UIView
@property(retain, nonatomic) UIColor *textColor;
@end

%hook SBLockScreenViewController

- (void)viewDidLayoutSubviews {
	%orig;

	UIView *lockScreenView = (UIView *)self.lockScreenView;
	SBFLockScreenDateView *dateView = [lockScreenView valueForKey:@"dateView"];
	UIView *lockScreenAlarmView = [dateView viewWithTag:nextAlarmOnLockScreenViewTag];

	if (enableOnLockScreen) {
		int nextActiveAlarmDifference = [nextActiveAlarmFireDate timeIntervalSinceNow];
		int maximumDifference = hideOnLockScreenIf * 60 * 60;
		BOOL hide = ((nextActiveAlarmDifference > maximumDifference) && (hideOnLockScreenIf != 0)) ||
					(hideOnLockScreenWhenMusicIsPlaying && [self isShowingMediaControls]);

		if (!snoozedAlarmCellIsVisible && nextActiveAlarmFireDate != nil && !hide) {
			UILabel *nextAlarmLabel;
			UIImageView *nextAlarmImageView;
			if (lockScreenAlarmView == nil) {
				// Create next alarm view
				lockScreenAlarmView = [self createAlarmView];

				// Add complete alarm view to date view
				[dateView addSubview:lockScreenAlarmView];
			}

			nextAlarmLabel = (UILabel *)[lockScreenAlarmView viewWithTag:nextAlarmOnLockScreenLabelTag];
			nextAlarmImageView = (UIImageView *)[lockScreenAlarmView viewWithTag:nextAlarmOnLockScreenImageViewTag];
			lockScreenAlarmView.hidden = NO;

			nextAlarmLabel.text = [self nextAlarmLabelText:nextActiveAlarmDifference];
			nextAlarmLabel.textColor = dateView.textColor;
			nextAlarmImageView.tintColor = dateView.textColor;

			[self resizeAlarmView:lockScreenAlarmView];

			lockScreenAlarmView.frame = [self frameForAlarmView:lockScreenAlarmView];

		} else if (lockScreenAlarmView != nil) {
			lockScreenAlarmView.hidden = YES;
		}
	} else if (lockScreenAlarmView != nil) {
		[lockScreenAlarmView removeFromSuperview];
		lockScreenAlarmView = nil;
	}
}

%new
- (void)resizeAlarmView:(UIView *)alarmView {
	UILabel *label = (UILabel *)[alarmView viewWithTag:nextAlarmOnLockScreenLabelTag];
	UIImageView *imageView = (UIImageView *)[alarmView viewWithTag:nextAlarmOnLockScreenImageViewTag];

	// Resize label to fit settings
	label.font = [UIFont systemFontOfSize:lockScreenFontSize];
	[label sizeToFit];

	// Resize image to fit label
	CGRect frame = imageView.frame;
	frame.size.width = lockScreenImageViewDefaultSize + (lockScreenFontSize - 17);
	frame.size.height = frame.size.width;
	frame.origin.y = label.frame.origin.y + label.frame.size.height / 2 - frame.size.height / 2;
	imageView.frame = frame;

	// Position the label next to the image
	frame = label.frame;
	frame.origin.x = imageView.bounds.size.width + imageView.bounds.size.width / 2;
	label.frame = frame;

	// Resize the whole alarm view to fit its contents
	frame = alarmView.frame;
	frame.size.width = CGRectGetMaxX(label.frame);
	frame.size.height = label.frame.size.height;
	alarmView.frame = frame;
}

%new
- (NSString *)nextAlarmLabelText:(NSTimeInterval)difference {
	NSString *text = nil;
	switch (lockScreenTimeType) {
		case TimeTypeTimeUntilAlarm:
			text = stringFromDifference(difference, lockScreenTimeFormat);
			break;
		case TimeTypeAlarmTime:
			text = stringFromDate(nextActiveAlarmFireDate);
			break;
		case TimeTypeBoth:
			NSString *alarmTime = stringFromDate(nextActiveAlarmFireDate);
			NSString *timeUntilAlarm = stringFromDifference(difference, lockScreenTimeFormat);
			text = [alarmTime stringByAppendingFormat:@" (%@)", timeUntilAlarm];
			break;
	}
	return text;
}

%new
- (UIView *)createAlarmView {
	// Create next alarm view
	UIView *alarmView = [[UIView alloc] init];
	alarmView.tag = nextAlarmOnLockScreenViewTag;

	// Get image
	NSString *imagePath = [tweakBundle pathForResource:@"TimeUntilAlarmLockScreenIcon" ofType:@"png"];
	UIImage *image = [[UIImage imageWithContentsOfFile:imagePath] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

	// Add image view
	UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
	imageView.tag = nextAlarmOnLockScreenImageViewTag;
	lockScreenImageViewDefaultSize = imageView.frame.size.height;
	[alarmView addSubview:imageView];

	// Add label
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.tag = nextAlarmOnLockScreenLabelTag;
	[alarmView addSubview:label];

	return alarmView;
}

%new
- (CGRect)frameForAlarmView:(UIView *)view {
	CGRect frame = view.frame;

	UIView *lockScreenView = (UIView *)self.lockScreenView;
	CGFloat fullscreenWidth = lockScreenView.frame.size.width;
	CGFloat fullscreenHeight = lockScreenView.frame.size.height;

	if (lockScreenHorizontalPosition == HorizontalPositionLeft) {
		frame.origin.x = nextAlarmOnLockScreenViewSpacing;
	} else if (lockScreenHorizontalPosition == HorizontalPositionMiddle) {
		frame.origin.x = fullscreenWidth / 2 - frame.size.width / 2;
	} else if (lockScreenHorizontalPosition == HorizontalPositionRight) {
		frame.origin.x = fullscreenWidth - frame.size.width - nextAlarmOnLockScreenViewSpacing;
	} else if (lockScreenHorizontalPosition == HorizontalPositionCustom) {
		if (lockScreenHorizontalPositionStartingPoint == HorizontalStartingPointLeft) {
			frame.origin.x = lockScreenHorizontalPositionValue;
		} else if (lockScreenHorizontalPositionStartingPoint == HorizontalStartingPointRight) {
			frame.origin.x = fullscreenWidth - frame.size.width - lockScreenHorizontalPositionValue;
		}
	}

	SBFLockScreenDateView *dateView = [lockScreenView valueForKey:@"dateView"];

	if (lockScreenVerticalPosition == VerticalPositionTop) {
		frame.origin.y = nextAlarmOnLockScreenTopBottomSpacing - dateView.frame.origin.y;
	} else if (lockScreenVerticalPosition == VerticalPositionBelowClock) {
		UIView *dateLabel = MSHookIvar<UIView *>(dateView, "_dateLabel");
		frame.origin.y = CGRectGetMaxY(dateLabel.frame) + nextAlarmOnLockScreenViewSpacing;
		if ([self isShowingMediaControls]) {
			frame.origin.y -= 8;
		} else if ([self lockScreenIsShowingBulletins]) {
			frame.origin.y -= 4;
		}
	} else if (lockScreenVerticalPosition == VerticalPositionBottom) {
		frame.origin.y = fullscreenHeight - frame.size.height - nextAlarmOnLockScreenTopBottomSpacing - dateView.frame.origin.y;
	} else if (lockScreenVerticalPosition == VerticalPositionCustom) {
		if (lockScreenVerticalPositionStartingPoint == VerticalStartingPointTop) {
			frame.origin.y = lockScreenVerticalPositionValue - dateView.frame.origin.y;
		} else if (lockScreenVerticalPositionStartingPoint == VerticalStartingPointBottom) {
			frame.origin.y = fullscreenHeight - frame.size.height - lockScreenVerticalPositionValue - dateView.frame.origin.y;
		}
	}

	return frame;
}

%end

%hook SBLockScreenSnoozedAlarmCell
// Used to hide the lock screen label when the regular snooze cell is visible

- (void)setFireDate:(NSDate *)fireDate {
	snoozedAlarmCellIsVisible = (fireDate != nil);
	%orig;
}

%end

@interface UIConcreteLocalNotification : NSObject
- (id)userInfo;
- (id)timeZone;
- (id)nextFireDateAfterDate:(id)arg1 localTimeZone:(id)arg2;
@end

@interface SBClockDataProvider
- (void)didScheduleNotifications:(NSArray *)notifications;
@end

%hook SBClockDataProvider
// Used to save the next active alarm fire date

// Called every time any notifications (e.g. alarms, timers) changes on iOS 7 & 8
- (id)_scheduledNotifications {
	id r = %orig;

	[self didScheduleNotifications:r];

	return r;
}

// Called every time any notifications (e.g. alarms, timers) changes on iOS 9
- (void)_publishAlarmsWithScheduledNotifications:(id)arg1 {
	%orig;

	[self didScheduleNotifications:arg1];
}

%new
- (void)didScheduleNotifications:(NSArray *)notifications {
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
}

%end

%end // LockScreenHooks group








// CLOCK APP

%group ClockAppHooks

@interface AlarmView : UIView
@property (nonatomic, readonly) UISwitch *enabledSwitch;
- (void)setName:(id)arg1 andRepeatText:(id)arg2 textColor:(id)arg3;
@end

@interface Alarm : NSObject
@property(nonatomic) unsigned int daySetting;
@property(nonatomic) unsigned int minute;
@property(nonatomic) unsigned int hour;
@property (readonly, nonatomic) Alarm *editingProxy;

- (id)nextFireDate;
@end

%hook AlarmTableViewCell
// Used to calculate time left and set the time left label's text

- (void)refreshUI:(id)ui animated:(BOOL)animated {

	AlarmView *alarmView = MSHookIvar<AlarmView *>(self, "_alarmView");
	UILabel *label = (UILabel *)[alarmView viewWithTag:clockAppLabelTag];

	if (enableInClockApp) {
		label.hidden = NO;

		Alarm *alarm = (Alarm *)ui;
		NSDate *nextFireDate = [alarm nextFireDate];
		NSTimeInterval difference = [nextFireDate timeIntervalSinceNow];

		if (label == nil) {
			// Create the label if it doesn't already exists (cells gets reused)
			label = [[UILabel alloc] init];
			label.tag = clockAppLabelTag;
			[alarmView addSubview:label];
		}

		// Set the label text to the time remaining
		label.text = stringFromDifference(difference, clockAppTimeFormat);
		label.font = [UIFont systemFontOfSize:clockAppFontSize];
		[label sizeToFit];

	} else if (label != nil) {
		// Hide if disabled in clock app
		label.hidden = YES;
	}

	%orig;
}

%end

%hook AlarmView

// If the time should be placed in the existing labels, it's set here.
- (void)setName:(id)arg1 andRepeatText:(id)arg2 textColor:(id)arg3 {

	if (enableInClockApp &&
		(clockAppPosition == ClockAppPositionReplaceText ||
			clockAppPosition == ClockAppPositionAfterText) &&
		(!enableForActiveAlarmsOnly || self.enabledSwitch.isOn)) {
		UILabel *label = (UILabel *)[self viewWithTag:clockAppLabelTag];
		if (label != nil) {
			if (clockAppPosition == ClockAppPositionReplaceText) {
				arg1 = label.text;
			} else if (clockAppPosition == ClockAppPositionAfterText) {
				arg1 = [arg1 stringByAppendingFormat:@", %@", label.text];
			}
		}
	}

	%orig;
}

// Used to position the time left label
- (void)layoutSubviews {
	%orig;

	if (enableInClockApp) {
		// Get the label to present the time remaining
		UILabel *label = (UILabel *)[self viewWithTag:clockAppLabelTag];
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

				// Position the label
				CGRect frame = label.frame;

				switch (clockAppPosition) {
					case ClockAppPositionAboveSwitch:
						frame.origin.x = CGRectGetMaxX(enabledSwitch.frame) - label.bounds.size.width;
						frame.origin.y = enabledSwitch.frame.origin.y / 2 - label.bounds.size.height / 2;
						break;
					case ClockAppPositionUnderSwitch:
						frame.origin.x = CGRectGetMaxX(enabledSwitch.frame) - label.bounds.size.width;
						frame.origin.y = (CGRectGetMaxY(self.frame) + CGRectGetMaxY(enabledSwitch.frame)) / 2 - label.bounds.size.height / 2;
						break;
					case ClockAppPositionAfterText:
					case ClockAppPositionReplaceText:
						// The time is placed in the existing text label instead
						// This occurs in setName:andRepeatText:textColor: above
						frame = CGRectZero;
						break;
					default:
						break;
				}
				label.frame = frame;
			} else {
				label.hidden = YES;
			}
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

	if (enableInClockApp) {
		lastReloadMinute = getCurrentMinute();

		// Reload table view when minute changes (check every second for minute change)
		reloadEveryMinuteTimer = [NSTimer scheduledTimerWithTimeInterval:1
												 				  target:self
											   				 	selector:@selector(reloadTableViewOnMinuteChange)
											   					userInfo:nil
																 repeats:YES];
		reloadEveryMinuteTimer.tolerance = 1;
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	%orig;

	if (reloadEveryMinuteTimer != nil) {
		// Remove timer
		[reloadEveryMinuteTimer invalidate];
		reloadEveryMinuteTimer = nil;
	}
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

@interface EditAlarmView : UIView
@end

@interface EditAlarmViewController : UITableViewController
@end

%hook EditAlarmViewController
// The view controller that edits an alarm (presented modally)
// Used to add a time left label in the header of the table view

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

	if (alarm != nil) {
		int difference = [[alarm.editingProxy nextFireDate] timeIntervalSinceNow];
		timeLeftLabel.text = stringFromDifference(difference, clockAppTimeFormat);
	} else {
		timeLeftLabel.text = stringFromDifference(0, clockAppTimeFormat);
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
	timeLeftLabel.text = stringFromDifference(difference, clockAppTimeFormat);

	// Center timeLeftLabel in settings table header
	UITableView *settingsTable = MSHookIvar<UITableView *>(editAlarmView, "_settingsTable");
	[timeLeftLabel sizeToFit];
	timeLeftLabel.center = settingsTable.tableHeaderView.center;
}

%end

%end // ClockAppHooks group






// HELPERS

static const NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

static int getCurrentMinute() {
	NSDateComponents *components = [calendar components:NSMinuteCalendarUnit fromDate:[NSDate date]];
	return [components minute];
}

static NSString *stringFromDifference(int difference, int format) {
	if (difference > 0) {
		difference += 60; // Round to next minute
	}

	// Convert the difference to days, hours and minutes
	int days = difference / 86400;
	int hours = (difference % 86400) / 3600;
	int minutes = ((difference % 86400) % 3600) / 60;

	// Turn into string
	NSString *dateString = @"";

	// 1d 9h 41m
	if (format == 0) {
		NSString *daysString = (days > 0) ? [NSString stringWithFormat:@"%d%@ ", days, LOCALIZED(@"DAY_SHORT")] : @"";
		NSString *hoursString = (hours > 0) ? [NSString stringWithFormat:@"%d%@ ", hours, LOCALIZED(@"HOUR_SHORT")] : @"";
		NSString *minutesString = (minutes > 0) ? [NSString stringWithFormat:@"%d%@", minutes, LOCALIZED(@"MINUTE_SHORT")] : @"";
		if (days == 0 && hours == 0 && minutes == 0) {
			minutesString = [NSString stringWithFormat:@"%d%@", minutes, LOCALIZED(@"MINUTE_SHORT")];
		}
		dateString = [NSString stringWithFormat:@"%@%@%@", daysString, hoursString, minutesString];
	}
	// 1day, 9hrs, 41mins
	else if (format == 1) {
		NSString *daysString = @"", *hoursString = @"", *minutesString = @"";
		if (days > 0) {
			daysString = [NSString stringWithFormat:@"%d%@ ", days, (days == 1) ? LOCALIZED(@"DAY_FULL") : LOCALIZED(@"DAYS_FULL")];
		}
		if (hours > 0) {
			hoursString = [NSString stringWithFormat:@"%d%@ ", hours, (hours == 1) ? LOCALIZED(@"HOUR_MEDIUM") : LOCALIZED(@"HOURS_MEDIUM")];
		}
		if (minutes > 0 || (days == 0 && hours == 0)) {
			minutesString = [NSString stringWithFormat:@"%d%@", minutes, (minutes == 1) ? LOCALIZED(@"MINUTE_MEDIUM") : LOCALIZED(@"MINUTES_MEDIUM")];
		}
		dateString = [NSString stringWithFormat:@"%@%@%@", daysString, hoursString, minutesString];
	}
	// 1 day 9 hours 41 minutes
	else if (format == 2) {
		NSString *daysString = @"", *hoursString = @"", *minutesString = @"";
		if (days > 0) {
			daysString = [NSString stringWithFormat:@"%d %@ ", days, (days == 1) ? LOCALIZED(@"DAY_FULL") : LOCALIZED(@"DAYS_FULL")];
		}
		if (hours > 0) {
			hoursString = [NSString stringWithFormat:@"%d %@ ", hours, (hours == 1) ? LOCALIZED(@"HOUR_FULL") : LOCALIZED(@"HOURS_FULL")];
		}
		if (minutes > 0 || (days == 0 && hours == 0)) {
			minutesString = [NSString stringWithFormat:@"%d %@", minutes, (minutes == 1) ? LOCALIZED(@"MINUTE_FULL") : LOCALIZED(@"MINUTES_FULL")];
		}
		dateString = [NSString stringWithFormat:@"%@%@%@", daysString, hoursString, minutesString];
	}
	// 1:9:41
	else if (format == 3) {
		NSString *daysString = (days > 0) ? [NSString stringWithFormat:@"%d:", days] : @"";
		NSString *hoursString = [NSString stringWithFormat:@"%d:", hours];
		NSString *minutesString = [NSString stringWithFormat:@"%@%d", (minutes < 10) ? @"0" : @"", minutes];
		dateString = [NSString stringWithFormat:@"%@%@%@", daysString, hoursString, minutesString];
	}

	return [dateString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

static NSDateFormatter *dateFormatter;

static NSString *stringFromDate(NSDate* date) {
	if (dateFormatter == nil) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateStyle = NSDateFormatterNoStyle;
		dateFormatter.timeStyle = NSDateFormatterShortStyle;
	}
	return [dateFormatter stringFromDate:date];
}

static CFStringRef settingsChangedNotification = CFSTR("com.ludvigeriksson.timeuntilalarmprefs/settingschanged");
static CFStringRef timeUntilAlarmPrefsKey 	   = CFSTR("com.ludvigeriksson.timeuntilalarmprefs");

static CFStringRef enableInClockAppKey 			= CFSTR("TUAEnableInClockApp");
static CFStringRef enableForActiveAlarmsOnlyKey = CFSTR("TUAEnableForActiveAlarmsOnly");
static CFStringRef clockAppFontSizeKey 			= CFSTR("TUAClockAppFontSize");
static CFStringRef clockAppTimeFormatKey 		= CFSTR("TUAClockAppTimeFormat");
static CFStringRef clockAppPositionKey 			= CFSTR("TUAClockAppPosition");

static CFStringRef enableOnLockScreenKey			     = CFSTR("TUAShowNextActiveAlarmOnLockScreen"); // Was called this previously, remains unchanged for compatability
static CFStringRef lockScreenFontSizeKey 			     = CFSTR("TUALockScreenFontSize");
static CFStringRef lockScreenTimeFormatKey 			     = CFSTR("TUALockScreenTimeFormat");
static CFStringRef hideOnLockScreenIfKey 			     = CFSTR("TUAHideOnLockScreenIf");
static CFStringRef hideOnLockScreenWhenMusicIsPlayingKey = CFSTR("TUAHideOnLockScreenWhenMusicIsPlaying");
static CFStringRef lockScreenTimeTypeKey			     = CFSTR("TUALockScreenTimeType");

static CFStringRef lockScreenHorizontalPositionKey 			    = CFSTR("TUALockScreenHorizontalPosition");
static CFStringRef lockScreenVerticalPositionKey 				= CFSTR("TUALockScreenVerticalPosition");
static CFStringRef lockScreenHorizontalPositionValueKey		    = CFSTR("TUALockScreenHorizontalPositionValue");
static CFStringRef lockScreenVerticalPositionValueKey 			= CFSTR("TUALockScreenVerticalPositionValue");
static CFStringRef lockScreenHorizontalPositionStartingPointKey = CFSTR("TUALockScreenHorizontalPositionStartingPoint");
static CFStringRef lockScreenVerticalPositionStartingPointKey 	= CFSTR("TUALockScreenVerticalPositionStartingPoint");

static void loadPrefs() {
    CFPreferencesAppSynchronize(timeUntilAlarmPrefsKey);
    if (CFBridgingRelease(CFPreferencesCopyAppValue(enableInClockAppKey, timeUntilAlarmPrefsKey))) {
        enableInClockApp = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(enableInClockAppKey, timeUntilAlarmPrefsKey)) boolValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(enableForActiveAlarmsOnlyKey, timeUntilAlarmPrefsKey))) {
        enableForActiveAlarmsOnly = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(enableForActiveAlarmsOnlyKey, timeUntilAlarmPrefsKey)) boolValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(clockAppFontSizeKey, timeUntilAlarmPrefsKey))) {
        clockAppFontSize = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(clockAppFontSizeKey, timeUntilAlarmPrefsKey)) intValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(clockAppTimeFormatKey, timeUntilAlarmPrefsKey))) {
        clockAppTimeFormat = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(clockAppTimeFormatKey, timeUntilAlarmPrefsKey)) intValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(clockAppPositionKey, timeUntilAlarmPrefsKey))) {
        clockAppPosition = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(clockAppPositionKey, timeUntilAlarmPrefsKey)) intValue];
    }

    if (CFBridgingRelease(CFPreferencesCopyAppValue(enableOnLockScreenKey, timeUntilAlarmPrefsKey))) {
        enableOnLockScreen = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(enableOnLockScreenKey, timeUntilAlarmPrefsKey)) boolValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenFontSizeKey, timeUntilAlarmPrefsKey))) {
        lockScreenFontSize = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenFontSizeKey, timeUntilAlarmPrefsKey)) intValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenTimeFormatKey, timeUntilAlarmPrefsKey))) {
        lockScreenTimeFormat = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenTimeFormatKey, timeUntilAlarmPrefsKey)) intValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(hideOnLockScreenIfKey, timeUntilAlarmPrefsKey))) {
        hideOnLockScreenIf = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(hideOnLockScreenIfKey, timeUntilAlarmPrefsKey)) intValue];
    }
	if (CFBridgingRelease(CFPreferencesCopyAppValue(hideOnLockScreenWhenMusicIsPlayingKey, timeUntilAlarmPrefsKey))) {
        hideOnLockScreenWhenMusicIsPlaying = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(hideOnLockScreenWhenMusicIsPlayingKey, timeUntilAlarmPrefsKey)) boolValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenTimeTypeKey, timeUntilAlarmPrefsKey))) {
        lockScreenTimeType = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenTimeTypeKey, timeUntilAlarmPrefsKey)) intValue];
    }

    if (CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenHorizontalPositionKey, timeUntilAlarmPrefsKey))) {
        lockScreenHorizontalPosition = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenHorizontalPositionKey, timeUntilAlarmPrefsKey)) intValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenVerticalPositionKey, timeUntilAlarmPrefsKey))) {
        lockScreenVerticalPosition = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenVerticalPositionKey, timeUntilAlarmPrefsKey)) intValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenHorizontalPositionValueKey, timeUntilAlarmPrefsKey))) {
        lockScreenHorizontalPositionValue = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenHorizontalPositionValueKey, timeUntilAlarmPrefsKey)) intValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenVerticalPositionValueKey, timeUntilAlarmPrefsKey))) {
        lockScreenVerticalPositionValue = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenVerticalPositionValueKey, timeUntilAlarmPrefsKey)) intValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenHorizontalPositionStartingPointKey, timeUntilAlarmPrefsKey))) {
        lockScreenHorizontalPositionStartingPoint = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenHorizontalPositionStartingPointKey, timeUntilAlarmPrefsKey)) intValue];
    }
    if (CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenVerticalPositionStartingPointKey, timeUntilAlarmPrefsKey))) {
        lockScreenVerticalPositionStartingPoint = [(id)CFBridgingRelease(CFPreferencesCopyAppValue(lockScreenVerticalPositionStartingPointKey, timeUntilAlarmPrefsKey)) intValue];
    }
}

%ctor {
	NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
    if ([bundleIdentifier length]) {
        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            NSLog(@"TimeUntilAlarm: initializing in SpringBoard");
            %init(LockScreenHooks);
        }
        if ([bundleIdentifier isEqualToString:@"com.apple.mobiletimer"]) {
            NSLog(@"TimeUntilAlarm: initializing in MobileTimer");
            %init(ClockAppHooks);
        }
    }
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, settingsChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    loadPrefs();
}
