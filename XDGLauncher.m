#import "XDGLauncher.h"

@implementation XDGLauncher

- (id)init
{
    self = [super init];
    if (self) {
        runningApps = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Suppress unnecessary notifications that cause INFO:(null) messages
    [NSApp setApplicationIconImage:nil];
    
    // Check if we should customize the app name and icon
    NSString *appName = [[[NSProcessInfo processInfo] environment] objectForKey:@"XDGLAUNCHER_APP_NAME"];
    NSString *appIcon = [[[NSProcessInfo processInfo] environment] objectForKey:@"XDGLAUNCHER_APP_ICON"];
    
    if (appName) {
        // Store the app name for later use - we can't modify NSBundle's info dictionary
        // The app name will be shown in dock through the process name
        NSLog(@"XDGLauncher running as: %@", appName);
    }
    
    if (appIcon && [[NSFileManager defaultManager] fileExistsAtPath:appIcon]) {
        // Set the application icon to match the wrapped app
        NSImage *icon = [[NSImage alloc] initWithContentsOfFile:appIcon];
        if (icon) {
            [NSApp setApplicationIconImage:icon];
            [icon release];
        }
    }
    
    // Create unique service name based on wrapped app
    NSString *serviceName = appName ? 
        [NSString stringWithFormat:@"XDGLauncher-%@", [appName stringByReplacingOccurrencesOfString:@" " withString:@""]] :
        @"XDGLauncher";
    
    // Set up service for IPC - prevents multiple instances per app
    serviceConnection = [NSConnection defaultConnection];
    [serviceConnection setRootObject:self];
    
    if (![serviceConnection registerName:serviceName]) {
        // Another instance exists for this app - send command and exit
        NSConnection *existing = [NSConnection 
            connectionWithRegisteredName:serviceName host:nil];
        if (existing) {
            id<XDGLauncherService> proxy = (id<XDGLauncherService>)[existing rootProxy];
            [proxy handleLaunchRequest:[[NSProcessInfo processInfo] arguments]];
        }
        exit(0);
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // Parse command line arguments
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    if ([args count] >= 2) {
        NSString *execPath = [args objectAtIndex:1];
        NSArray *execArgs = [args subarrayWithRange:NSMakeRange(2, [args count] - 2)];
        
        if ([self isApplicationRunning:execPath]) {
            [self activateApplication:execPath];
            // Exit after activation
            [self performSelector:@selector(terminate:) withObject:nil afterDelay:1.0];
        } else {
            [self launchApplication:execPath withArguments:execArgs];
            // Don't exit - stay running to represent the launched app
        }
    } else {
        // No arguments, just exit
        [NSApp terminate:self];
    }
}

- (void)handleLaunchRequest:(NSArray *)arguments
{
    if ([arguments count] >= 2) {
        NSString *execPath = [arguments objectAtIndex:1];
        NSArray *execArgs = [arguments subarrayWithRange:NSMakeRange(2, [arguments count] - 2)];
        
        if ([self isApplicationRunning:execPath]) {
            [self activateApplication:execPath];
        } else {
            [self launchApplication:execPath withArguments:execArgs];
        }
    }
}

- (void)launchApplication:(NSString *)executablePath withArguments:(NSArray *)args
{
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:executablePath];
    [task setArguments:args ? args : @[]];
    
    // Register for termination notification
    [[NSNotificationCenter defaultCenter] 
        addObserver:self 
        selector:@selector(taskDidTerminate:) 
        name:NSTaskDidTerminateNotification 
        object:task];
    
    NS_DURING
        [task launch];
        
        // Store app info
        NSNumber *pid = [NSNumber numberWithInt:[task processIdentifier]];
        [runningApps setObject:@{
            @"task": task,
            @"path": executablePath,
            @"arguments": args ? args : @[],
            @"startTime": [NSDate date]
        } forKey:pid];
        
        NSLog(@"Launched %@ with PID %d", executablePath, [task processIdentifier]);
        
    NS_HANDLER
        NSLog(@"Failed to launch %@: %@", executablePath, localException);
    NS_ENDHANDLER
}

- (BOOL)isApplicationRunning:(NSString *)executablePath
{
    // Check our tracked processes first
    for (NSDictionary *appInfo in [runningApps allValues]) {
        if ([[appInfo objectForKey:@"path"] isEqualToString:executablePath]) {
            NSTask *task = [appInfo objectForKey:@"task"];
            if ([task isRunning]) {
                return YES;
            }
        }
    }
    
    // Fallback: check system processes by command name
    NSString *appName = [executablePath lastPathComponent];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/pgrep"];
    [task setArguments:@[@"-f", appName]];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NS_DURING
        [task launch];
        [task waitUntilExit];
        
        if ([task terminationStatus] == 0) {
            return YES;  // pgrep found matching process
        }
    NS_HANDLER
        // pgrep failed, assume not running
    NS_ENDHANDLER
    
    return NO;
}

- (void)activateApplication:(NSString *)executablePath
{
    NSString *appName = [executablePath lastPathComponent];
    
    // Use wmctrl if available for window management
    NSTask *wmctrlTask = [[NSTask alloc] init];
    [wmctrlTask setLaunchPath:@"/usr/bin/wmctrl"];
    [wmctrlTask setArguments:@[@"-a", appName]];
    
    NS_DURING
        [wmctrlTask launch];
        [wmctrlTask waitUntilExit];
        
        if ([wmctrlTask terminationStatus] == 0) {
            NSLog(@"Activated windows for %@", appName);
            return;
        }
    NS_HANDLER
        // wmctrl failed or not available
    NS_ENDHANDLER
    
    // Fallback: use xdotool if available
    NSTask *xdotoolTask = [[NSTask alloc] init];
    [xdotoolTask setLaunchPath:@"/usr/bin/xdotool"];
    [xdotoolTask setArguments:@[@"search", @"--name", appName, @"windowactivate"]];
    
    NS_DURING
        [xdotoolTask launch];
        [xdotoolTask waitUntilExit];
        
        if ([xdotoolTask terminationStatus] == 0) {
            NSLog(@"Activated windows for %@ using xdotool", appName);
            return;
        }
    NS_HANDLER
        // xdotool failed or not available
    NS_ENDHANDLER
    
    NSLog(@"Could not activate windows for %@ - no window manager tools available", appName);
}

- (void)taskDidTerminate:(NSNotification *)notification
{
    NSTask *task = [notification object];
    NSNumber *pid = [NSNumber numberWithInt:[task processIdentifier]];
    
    NSDictionary *appInfo = [runningApps objectForKey:pid];
    if (appInfo) {
        NSString *path = [appInfo objectForKey:@"path"];
        
        [runningApps removeObjectForKey:pid];
        NSLog(@"Application %@ (PID %d) terminated", path, [pid intValue]);
        
        // If no more apps running, terminate XDGLauncher
        if ([runningApps count] == 0) {
            NSLog(@"No more applications running, terminating XDGLauncher");
            [NSApp terminate:self];
        }
    }
    
    // Remove observer
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSTaskDidTerminateNotification 
                                                  object:task];
}

- (void)terminate:(id)sender
{
    [NSApp terminate:sender];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    // Clean up service connection
    [serviceConnection invalidate];
    
    // Don't terminate child processes - they should continue running
    NSLog(@"XDGLauncher terminating");
}

@end