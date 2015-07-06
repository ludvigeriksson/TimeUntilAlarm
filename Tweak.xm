int differenceFromTimeInterval(int secondsForAlarm) {
	// Get the current time as seconds into the day
	NSDate *now = [NSDate date];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *components = [calendar components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:now];
	int secondsNow = ([components hour] * 3600) + ([components minute] * 60);

	// Calculate difference between the alarm and time now
	int difference = 0;
	if (secondsNow < secondsForAlarm) {
		difference = secondsForAlarm - secondsNow;
	} else {
		difference = (86400) - (secondsNow - secondsForAlarm);
	}

	return difference;
}

int differenceFromHoursMinutes(int alarmHours, int alarmMinutes) {
	// Convert the alarm time to seconds into the day
	int secondsForAlarm = (alarmHours * 3600) + (alarmMinutes * 60);

	return differenceFromTimeInterval(secondsForAlarm);
}

NSString *stringFromDifference(int difference) {
	// Convert the difference to days, hours and minutes
	int days = difference / 86400;
	int hours = (difference % 86400) / 3600;
	int minutes = ((difference % 86400) % 3600) / 60;

	// Turn into string
	NSString *daysString = (days > 0) ? [NSString stringWithFormat:@"%dd ", days] : @"";
	NSString *hoursString = (hours > 0) ? [NSString stringWithFormat:@"%dh ", hours] : @"";
	return [NSString stringWithFormat:@"%@%@%dm", daysString, hoursString, minutes];
}


%hook AlarmView
// This is the view inside the table view cell representing an alarm

- (void)layoutSubviews {
	%orig;

	// Get the time of the alarm as seconds into the day
	UIView *timeLabel = MSHookIvar<UIView *>(self, "_timeLabel");
	int alarmHours = MSHookIvar<int>(timeLabel, "_hour");
	int alarmMinutes = MSHookIvar<int>(timeLabel, "_minute");

	// Get the difference between the alarm and now
	int difference = differenceFromHoursMinutes(alarmHours, alarmMinutes);

	// Get the label to present the time remaining
	UILabel *label = (UILabel *)[self viewWithTag:50];
	if (label == nil) {
		// Create the label if it doesn't already exists (cells gets reused)
		label = [[UILabel alloc] init];
		label.tag = 50;
		label.font = [UIFont systemFontOfSize:17];
		[self addSubview:label];
	}

	// Set the label text to the time remaining
	label.text = stringFromDifference(difference);
	label.textColor = (UIColor *)[timeLabel valueForKey:@"textColor"];
	[label sizeToFit];

	// Position the label above the switch
	UIView *enabledSwitch = MSHookIvar<UIView *>(self, "_enabledSwitch");
	CGFloat x = CGRectGetMaxX(enabledSwitch.frame) - label.bounds.size.width;
	CGFloat y = enabledSwitch.frame.origin.y / 2 - label.bounds.size.height / 2;

	label.frame = CGRectMake(x, y, label.bounds.size.width, label.bounds.size.height);
}

%end

static int lastReloadMinute = 0;
static NSTimer *timer = nil;

int getCurrentMinute() {
	NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSDateComponents *components = [calendar components:NSMinuteCalendarUnit fromDate:[NSDate date]];
	return [components minute];
}

%hook AlarmViewController
// The view controller listing all the alarms (subclass of UITableViewController)
// Use this to reload the table view when the app opens and when minute changes

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

%hook EditAlarmViewController
// The view controller that edits an alarm (presented modally)
// Add a time left label in the header of the table view

- (id)initWithAlarm:(id)alarm { 
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

	// Set time left label text
	id alarm = [self valueForKey:@"alarm"];
	if (alarm != nil && !isNewAlarm) {
		// Opened by editing existing alarm
		isNewAlarm = NO;
		int hour = [[alarm valueForKey:@"hour"] intValue];
		int minute = [[alarm valueForKey:@"minute"] intValue];
		int difference = differenceFromHoursMinutes(hour, minute);
		timeLeftLabel.text = stringFromDifference(difference);
	} else {
		// Opened by creating new alarm
		timeLeftLabel.text = stringFromDifference(0);
	}
	[timeLeftLabel sizeToFit];
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

	// Update time left label

	EditAlarmView *editAlarmView = MSHookIvar<EditAlarmView *>(self, "_editAlarmView");
	UIDatePicker *timePicker = MSHookIvar<UIDatePicker *>(editAlarmView, "_timePicker");
	UITableView *settingsTable = MSHookIvar<UITableView *>(editAlarmView, "_settingsTable");

	int pickedTime = timePicker.countDownDuration;

	int difference = differenceFromTimeInterval(pickedTime);

	timeLeftLabel.text = stringFromDifference(difference);
	[timeLeftLabel sizeToFit];
	timeLeftLabel.center = settingsTable.tableHeaderView.center;
}

%end