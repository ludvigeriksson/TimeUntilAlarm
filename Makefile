SHARED_CFLAGS = -fobjc-arc
ARCHS = armv7 armv7s arm64

include theos/makefiles/common.mk

TWEAK_NAME = TimeUntilAlarm
TimeUntilAlarm_FILES = Tweak.xm

TimeUntilAlarm_FRAMEWORKS = UIKit, CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 MobileTimer"

include $(THEOS_MAKE_PATH)/aggregate.mk
