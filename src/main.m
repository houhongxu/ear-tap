#import "AppDelegate.h"
#import "Shortcut.h"
#import "Storage.h"
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSArray *args = NSProcessInfo.processInfo.arguments;
        if (argc > 1 && strcmp(argv[1], "--validate") == 0) {
            if (argc != 3) { fprintf(stderr, "Usage: EarTap --validate path/to/shortcut.json\n"); return 2; }
            NSString *failure = nil;
            NSDictionary *shortcut = ETParseShortcut([NSData dataWithContentsOfFile:@(argv[2])], &failure);
            printf("%s\n", [(shortcut ? shortcut[@"label"] : failure) UTF8String]);
            return shortcut ? 0 : 1;
        }
        if ([args containsObject:@"--stop"]) {
            for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier]) {
                if (app.processIdentifier == getpid()) continue;
                [app terminate];
                // The maximum configured key sequence can take 18 seconds to release all keys.
                for (int i = 0; i < 500 && !app.terminated; i++)
                    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
                if (!app.terminated) { fprintf(stderr, "EarTap did not stop; no files changed.\n"); return 2; }
            }
            return 0;
        }
        if (argc > 1 && ![args containsObject:@"--check"]) {
            fprintf(stderr, "Usage: EarTap [--check | --stop | --validate file]\n"); return 2;
        }
        NSError *error = nil;
        if (!ETPrepareStorage(&error)) { fprintf(stderr, "%s\n", error.localizedDescription.UTF8String); return 1; }
        if ([args containsObject:@"--check"]) {
            NSString *failure = nil;
            NSDictionary *shortcut = ETParseShortcut([NSData dataWithContentsOfURL:ETConfigURL()], &failure);
            NSString *message = [NSString stringWithFormat:@"CHECK shortcut=%@ accessibility=%d", shortcut ? shortcut[@"label"] : failure, AXIsProcessTrusted()];
            ETLog(message); printf("%s\n", message.UTF8String);
            return shortcut ? 0 : 1;
        }
        // Prevent copies launched from different paths from creating duplicate mappings.
        NSURL *lockURL = [ETDataDirectory() URLByAppendingPathComponent:@"instance.lock"];
        int lock = open(lockURL.fileSystemRepresentation, O_CREAT | O_RDWR, 0600);
        if (lock < 0) { perror("EarTap lock"); return 1; }
        if (flock(lock, LOCK_EX | LOCK_NB) != 0) { close(lock); return 0; }
        [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyAccessory];
        ETAppDelegate *delegate = ETAppDelegate.new;
        NSApp.delegate = delegate;
        [NSApp run];
        close(lock);
    }
    return 0;
}
