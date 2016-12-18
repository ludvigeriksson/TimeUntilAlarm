SHARED_CFLAGS = -fobjc-arc
ARCHS = armv7 armv7s arm64

# Uncomment before release to remove build number
PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)

include theos/makefiles/common.mk

TWEAK_NAME = TimeUntilAlarm
TimeUntilAlarm_FILES = Tweak.xm

TimeUntilAlarm_FRAMEWORKS = UIKit CoreGraphics
TimeUntilAlarm_PRIVATE_FRAMEWORKS = MobileTimer
TimeUntilAlarm_LIBRARIES = colorpicker

TimeUntilAlarm_CODESIGN_FLAGS=-Sentitlements.xml

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += timeuntilalarmprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
