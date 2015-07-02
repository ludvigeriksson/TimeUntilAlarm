%hook AlarmView

- (void)layoutSubviews {
	%orig;

	// Get the time of the alarm as seconds into the day
	UIView *timeLabel = MSHookIvar<UIView *>(self, "_timeLabel");
	int alarmHours = MSHookIvar<int>(timeLabel, "_hour");
	int alarmMinutes = MSHookIvar<int>(timeLabel, "_minute");
	
	int secondsForAlarm = (alarmHours * 3600) + (alarmMinutes * 60);

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

	// Convert the difference to hours and minutes
	int hours = difference / 3600;
	int minutes = (difference % 3600) / 60;

	// Get the label to present the time remaining
	UILabel *label = (UILabel *)[self viewWithTag:50];
	if (label == nil) {
		// Create the label if it doesn't already exists (cells gets reused)
		label = [[UILabel alloc] init];
		label.tag = 50;
		label.font = [UIFont systemFontOfSize:17];
		label.textColor = (UIColor *)[timeLabel valueForKey:@"textColor"];
		[self addSubview:label];
	}

	// Set the label text to the time remaining
	label.text = [NSString stringWithFormat:@"%dh %dm", hours, minutes];
	[label sizeToFit];

	// Position the label above the switch
	UIView *enabledSwitch = MSHookIvar<UIView *>(self, "_enabledSwitch");
	CGFloat x = CGRectGetMidX(enabledSwitch.frame) - label.bounds.size.width / 2;
	CGFloat y = enabledSwitch.frame.origin.y / 2 - label.bounds.size.height / 2;

	label.frame = CGRectMake(x, y, label.bounds.size.width, label.bounds.size.height);
}

%end