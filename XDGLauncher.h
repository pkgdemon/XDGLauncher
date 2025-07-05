#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Protocol for distributed objects
@protocol XDGLauncherService
- (void)handleLaunchRequest:(NSArray *)arguments;
@end

@interface XDGLauncher : NSObject <NSApplicationDelegate, XDGLauncherService>
{
    NSMutableDictionary *runningApps;  // pid -> app info
    NSConnection *serviceConnection;
}

- (void)launchApplication:(NSString *)executablePath withArguments:(NSArray *)args;
- (BOOL)isApplicationRunning:(NSString *)executablePath;
- (void)activateApplication:(NSString *)executablePath;
- (void)handleLaunchRequest:(NSArray *)arguments;

@end