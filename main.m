#import <AppKit/AppKit.h>
#import "XDGLauncher.h"

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [NSApplication sharedApplication];
    
    XDGLauncher *launcher = [[XDGLauncher alloc] init];
    [NSApp setDelegate:launcher];
    
    // GNUstep way to suppress app icon - set in Info.plist instead
    // For now, we'll minimize interaction with dock
    
    int result = NSApplicationMain(argc, argv);
    
    [pool release];
    return result;
}