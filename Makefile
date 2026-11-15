TARGET := iphone:clang:latest:15.0
ARCHS := arm64

# Rootless: dylib + plist устанавливаются в /var/jb/Library/MobileSubstrate/...
THEOS_PACKAGE_SCHEME = rootless

# После `make install` перезапускаем SpringBoard и закрываем Камеру.
INSTALL_TARGET_PROCESSES = SpringBoard Camera

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AcidVision

AcidVision_FILES = \
	Tweak.x \
	AcidConfig.m \
	AcidOverlayWindow.m \
	AcidOverlayViewController.m \
	AcidOverlayManager.m \
	AcidMetalView.m \
	AcidRenderer.m \
	AcidDriftAnimator.m \
	AcidCameraPreviewManager.m \
	AcidCameraProcessor.m

AcidVision_CFLAGS = -fobjc-arc -Wall -Wno-deprecated-declarations
AcidVision_FRAMEWORKS = \
	UIKit \
	Foundation \
	QuartzCore \
	CoreGraphics \
	CoreImage \
	Metal \
	MetalKit \
	AVFoundation \
	Photos \
	ImageIO

include $(THEOS_MAKE_PATH)/tweak.mk
