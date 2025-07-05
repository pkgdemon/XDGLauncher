include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = XDGLauncher

XDGLauncher_OBJC_FILES = \
	main.m \
	XDGLauncher.m

include $(GNUSTEP_MAKEFILES)/application.make

# Create the custom info file that gets merged
after-all::
	@echo "Creating XDGLauncherInfo.plist..."
	@echo '{' > XDGLauncherInfo.plist
	@echo '    ApplicationDescription = "Simple application launcher for GNUstep dock integration";' >> XDGLauncherInfo.plist
	@echo '    ApplicationRelease = "1.0";' >> XDGLauncherInfo.plist
	@echo '    GSSuppressAppIcon = "YES";' >> XDGLauncherInfo.plist
	@echo '    LSUIElement = "YES";' >> XDGLauncherInfo.plist
	@echo '    NSServices = (' >> XDGLauncherInfo.plist
	@echo '        {' >> XDGLauncherInfo.plist
	@echo '            NSPortName = "XDGLauncher";' >> XDGLauncherInfo.plist
	@echo '            NSMessage = "handleLaunchRequest";' >> XDGLauncherInfo.plist
	@echo '            NSUserData = "";' >> XDGLauncherInfo.plist
	@echo '        }' >> XDGLauncherInfo.plist
	@echo '    );' >> XDGLauncherInfo.plist
	@echo '}' >> XDGLauncherInfo.plist
	@cp XDGLauncherInfo.plist XDGLauncher.app/Resources/