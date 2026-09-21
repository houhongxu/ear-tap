#import "../src/AppDelegate.h"
#import "../src/Shortcut.h"
#import "../src/Storage.h"
#import "../src/MediaSession.h"
#import <Carbon/Carbon.h>
#include <IOKit/hidsystem/IOLLEvent.h>

// Substitute the framework centers, exercising actual registration and callback code.
#import <MediaPlayer/MediaPlayer.h>
@interface TestCommand : NSObject
@property BOOL enabled;
@property (copy) MPRemoteCommandHandlerStatus (^handler)(MPRemoteCommandEvent *);
- (id)addTargetWithHandler:(MPRemoteCommandHandlerStatus (^)(MPRemoteCommandEvent *))handler;
- (void)removeTarget:(id)target;
@end
@implementation TestCommand
- (id)addTargetWithHandler:(MPRemoteCommandHandlerStatus (^)(MPRemoteCommandEvent *))handler {
    self.handler = handler; return self;
}
- (void)removeTarget:(id)target { (void)target; self.handler = nil; }
@end
@interface TestRemoteCenter : NSObject
@property TestCommand *playCommand;
@property TestCommand *pauseCommand;
@property TestCommand *togglePlayPauseCommand;
+ (instancetype)sharedCommandCenter;
@end
@implementation TestRemoteCenter
+ (instancetype)sharedCommandCenter {
    static TestRemoteCenter *center;
    if (!center) {
        center = TestRemoteCenter.new;
        center.playCommand = TestCommand.new; center.pauseCommand = TestCommand.new; center.togglePlayPauseCommand = TestCommand.new;
    }
    return center;
}
@end
@interface TestInfoCenter : NSObject
@property NSDictionary *nowPlayingInfo;
@property MPNowPlayingPlaybackState playbackState;
+ (instancetype)defaultCenter;
@end
@implementation TestInfoCenter
+ (instancetype)defaultCenter { static TestInfoCenter *center; if (!center) center = TestInfoCenter.new; return center; }
@end
#define MPRemoteCommandCenter TestRemoteCenter
#define MPNowPlayingInfoCenter TestInfoCenter
#import "../src/MediaSession.m"
#undef MPRemoteCommandCenter
#undef MPNowPlayingInfoCenter

#import "../src/StatusIcon.m"

static NSMutableArray<NSString *> *logs;
static NSURL *configURL;
static BOOL trusted = YES;
static CGEventFlags heldFlags = 0;
static NSUInteger sends = 0;
static void TestLog(NSString *message) { [logs addObject:message]; }
static NSURL *TestConfigURL(void) { return configURL; }
static NSURL *TestLogURL(void) { return configURL; }
static Boolean TestTrusted(void) { return trusted; }
static CGEventFlags TestFlags(CGEventSourceStateID state) { (void)state; return heldFlags; }
static BOOL TestSend(NSDictionary *shortcut) { (void)shortcut; sends++; return YES; }
// Test the actual dispatcher while replacing OS input and file/log destinations.
// No application launch, media session registration, permission prompts, or real keys.
#define ETLog TestLog
#define ETConfigURL TestConfigURL
#define ETLogURL TestLogURL
#define AXIsProcessTrusted TestTrusted
#define CGEventSourceFlagsState TestFlags
#define ETSendShortcut TestSend
#import "../src/AppDelegate.m"
#undef ETLog
#undef ETConfigURL
#undef ETLogURL
#undef AXIsProcessTrusted
#undef CGEventSourceFlagsState
#undef ETSendShortcut

static NSUInteger checks = 0;
#define CHECK(condition) do { checks++; if (!(condition)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); exit(1); } } while (0)
static NSDictionary *parse(id value) {
    NSString *failure = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingFragmentsAllowed error:nil];
    NSDictionary *result = ETParseShortcut(data, &failure);
    CHECK(result || failure.length);
    return result;
}
static ETAppDelegate *bridge(void) {
    ETAppDelegate *b = ETAppDelegate.new;
    b.enabled = YES;
    b.pending = NSMutableArray.new;
    return b;
}
static void drain(ETAppDelegate *b) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (b.busy && deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    CHECK(!b.busy);
}
static BOOL hasLog(NSString *text) {
    for (NSString *line in logs) if ([line containsString:text]) return YES;
    return NO;
}
static BOOL isWhiteStatusImage(NSImage *image) {
    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
    if (!rep) return NO;
    BOOL found = NO;
    for (NSInteger y = 0; y < rep.pixelsHigh; y++) {
        for (NSInteger x = 0; x < rep.pixelsWide; x++) {
            NSColor *pixel = [[rep colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
            if (pixel.alphaComponent < 0.02) continue;
            found = YES;
            if (pixel.redComponent < 0.99 || pixel.greenComponent < 0.99 || pixel.blueComponent < 0.99) return NO;
        }
    }
    return found;
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        CHECK(argc == 3);
        logs = NSMutableArray.new;
        CHECK(ETStatusIconStateForFlags(YES, NO, NO) == ETStatusIconStateReady);
        CHECK(ETStatusIconStateForFlags(NO, YES, YES) == ETStatusIconStatePaused);
        CHECK(ETStatusIconStateForFlags(YES, YES, YES) == ETStatusIconStateSending);
        CHECK(ETStatusIconStateForFlags(YES, NO, YES) == ETStatusIconStateError);
        for (NSUInteger state = ETStatusIconStateReady; state <= ETStatusIconStateError; state++) {
            NSImage *image = ETStatusIcon((ETStatusIconState)state);
            CHECK(!image.isTemplate && NSEqualSizes(image.size, NSMakeSize(18, 18)));
            CHECK(isWhiteStatusImage(image));
            CHECK(ETStatusIconAccessibilityLabel((ETStatusIconState)state).length > 0);
            NSColor *tint = [ETStatusIconTintColor((ETStatusIconState)state) colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
            CHECK(tint.redComponent > 0.99 && tint.greenComponent > 0.99 && tint.blueComponent > 0.99);
        }
        configURL = [NSURL fileURLWithPath:[@(argv[2]) stringByAppendingPathComponent:@"shortcut.json"]];
        NSString *failure = nil;
        NSDictionary *defaults = ETParseShortcut([NSData dataWithContentsOfFile:@(argv[1])], &failure);
        CHECK(defaults != nil);
        CHECK([defaults[@"keyCode"] intValue] == kVK_ANSI_V);
        ETKeyStep steps[12];
        size_t count = ETKeySteps(defaults, steps);
        CHECK(count == 6);
        CHECK(steps[0].key == kVK_Shift && steps[0].type == kCGEventFlagsChanged);
        CHECK(steps[1].key == kVK_Command);
        CGEventFlags expected = kCGEventFlagMaskShift | NX_DEVICELSHIFTKEYMASK | kCGEventFlagMaskCommand | NX_DEVICELCMDKEYMASK;
        CHECK(steps[2].key == kVK_ANSI_V && steps[2].down && steps[2].flags == expected);
        CHECK(steps[3].type == kCGEventKeyUp && !steps[3].down && steps[3].flags == expected);
        CHECK(steps[4].key == kVK_Command && !steps[4].down);
        CHECK(steps[5].key == kVK_Shift && !steps[5].down && steps[5].flags == 0);
        NSDictionary *plain = parse(@{@"key": @"space", @"modifiers": @[]});
        CHECK(ETKeySteps(plain, steps) == 2 && steps[0].key == kVK_Space && steps[0].flags == 0 && !steps[1].down);
        NSDictionary *maximum = parse(@{@"key": @"a", @"modifiers": @[@"command", @"shift", @"option", @"control", @"fn"]});
        CHECK(ETKeySteps(maximum, steps) == 12 && steps[11].flags == 0);
        for (NSString *key in @[@"0", @"9", @"return", @"escape", @"tab", @"delete", @"left", @"right", @"up", @"down", @"Z"])
            CHECK(parse(@{@"key": key, @"modifiers": @[]}) != nil);
        for (id invalid in @[@[], @{}, NSNull.null, @{@"key": @"bogus", @"modifiers": @[]},
            @{@"key": @"v", @"modifiers": @[@"shift", @"shift"]},
            @{@"key": @"v", @"modifiers": @[@1]}, @{@"key": @"v", @"modifiers": @"shift"},
            @{@"key": @3, @"modifiers": @[]}, @{@"key": @"v", @"modifiers": @[], @"unexpected": @1}]) CHECK(!parse(invalid));
        for (id bad in @[@9, @1501, @YES, @"40", NSNull.null])
            CHECK(!parse(@{@"key": @"v", @"modifiers": @[], @"keyHoldMs": bad}));
        CHECK(!ETParseShortcut([@"{broken" dataUsingEncoding:NSUTF8StringEncoding], &failure));
        NSDictionary *fast = @{@"key": @"v", @"modifiers": @[@"shift", @"command"], @"settleDelayMs": @10};
        NSData *validData = [NSJSONSerialization dataWithJSONObject:fast options:0 error:nil];
        CHECK([validData writeToURL:configURL atomically:YES]);
        ETAppDelegate *b = bridge();
        b.busy = YES;
        [b receive:@"play"];
        [b receive:@"pause"];
        CHECK(b.pending.count == 2 && b.received == 2 && sends == 0);
        CHECK(hasLog(@"source=play") && hasLog(@"source=pause"));
        [b cancelPending];
        b = bridge();
        [logs removeAllObjects];
        for (NSString *source in @[@"play", @"pause", @"toggle"]) [b receive:source];
        drain(b);
        CHECK(b.received == 3 && b.sent == 3 && sends == 3);
        CHECK(hasLog(@"source=play") && hasLog(@"source=pause") && hasLog(@"source=toggle"));
        [b applicationShouldHandleReopen:(NSApplication *)NSObject.new hasVisibleWindows:NO];
        CHECK(b.received == 3); // Opening an app does not type into the current window.
        [b receive:@"play"];
        [b toggle:nil];
        [b toggle:nil];
        drain(b);
        CHECK(sends == 3 && hasLog(@"CANCELLED")); // Disable/re-enable cannot revive queued work.
        trusted = NO;
        [b receive:@"play"]; drain(b);
        CHECK(sends == 3 && hasLog(@"NEEDS_ACCESSIBILITY"));
        trusted = YES; heldFlags = kCGEventFlagMaskShift;
        [b receive:@"play"]; drain(b);
        CHECK(sends == 3 && hasLog(@"KEYS_HELD"));
        heldFlags = 0;
        CHECK([[@"{}" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:configURL atomically:YES]);
        [b receive:@"play"]; drain(b);
        CHECK(sends == 3 && hasLog(@"INVALID_CONFIG"));
        CHECK([validData writeToURL:configURL atomically:YES]);
        [b receive:@"play"]; drain(b);
        CHECK(sends == 4); // Live config recovery without restart.
        b = bridge(); b.busy = YES;
        for (int i = 0; i < 10; i++) [b receive:@"play"];
        CHECK(b.pending.count == 8 && hasLog(@"QUEUE_FULL"));
        [b cancelPending]; CHECK(b.pending.count == 0);
        b.busy = NO;
        [b.pending addObject:@{@"id": @99, @"time": @(NSProcessInfo.processInfo.systemUptime - 4), @"generation": @(b.generation)}];
        [b next]; CHECK(hasLog(@"EXPIRED") && sends == 4);
        [b lifecycle:[NSNotification notificationWithName:NSWorkspaceWillSleepNotification object:nil]];
        NSUInteger received = b.received;
        [b receive:@"play"]; CHECK(b.received == received);
        [b lifecycle:[NSNotification notificationWithName:NSWorkspaceDidWakeNotification object:nil]];
        CHECK([b accepting]);
        [b lifecycle:[NSNotification notificationWithName:NSWorkspaceSessionDidResignActiveNotification object:nil]];
        CHECK(![b accepting]);
        [b lifecycle:[NSNotification notificationWithName:NSWorkspaceSessionDidBecomeActiveNotification object:nil]];
        CHECK([b accepting]);
        CHECK([b applicationShouldTerminate:(NSApplication *)NSObject.new] == NSTerminateNow);
        [b receive:@"play"]; CHECK(b.received == received);
        NSMutableArray *sources = NSMutableArray.new;
        ETMediaSession *session = [[ETMediaSession alloc] initWithHandler:^(NSString *source) { [sources addObject:source]; }];
        TestRemoteCenter *center = TestRemoteCenter.sharedCommandCenter;
        CHECK(!center.playCommand.enabled);
        [session setEnabled:YES];
        CHECK(center.playCommand.enabled && center.pauseCommand.enabled && center.togglePlayPauseCommand.enabled);
        CHECK(TestInfoCenter.defaultCenter.nowPlayingInfo != nil);
        for (TestCommand *command in @[center.playCommand, center.pauseCommand, center.togglePlayPauseCommand])
            command.handler((MPRemoteCommandEvent *)NSObject.new);
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        CHECK(([sources isEqual:@[@"play", @"pause", @"toggle"]]));
        center.playCommand.handler((MPRemoteCommandEvent *)NSObject.new);
        [session setEnabled:NO];
        CHECK(!center.playCommand.enabled && TestInfoCenter.defaultCenter.nowPlayingInfo == nil);
        [session setEnabled:YES];
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        CHECK(sources.count == 3); // Framework callback queued before pause must not revive.
        center.playCommand.handler((MPRemoteCommandEvent *)NSObject.new);
        [session close];
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        CHECK(sources.count == 3 && center.playCommand.handler == nil && !center.playCommand.enabled);
        // Route all real media callbacks through the dispatcher.
        ETAppDelegate *dispatched = bridge();
        [logs removeAllObjects];
        NSUInteger sendsBefore = sends;
        ETMediaSession *dispatchedSession = [[ETMediaSession alloc] initWithHandler:^(NSString *source) { [dispatched receive:source]; }];
        [dispatchedSession setEnabled:YES];
        for (TestCommand *command in @[center.playCommand, center.pauseCommand, center.togglePlayPauseCommand])
            command.handler((MPRemoteCommandEvent *)NSObject.new);
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        drain(dispatched);
        CHECK(dispatched.received == 3 && dispatched.sent == 3 && sends == sendsBefore + 3);
        CHECK(dispatched.pending.count == 0);
        CHECK(hasLog(@"source=play") && hasLog(@"source=pause") && hasLog(@"source=toggle"));
        [dispatchedSession close];
        printf("PASS: %lu checks; no real keyboard events or media sessions created.\n", checks);
    }
    return 0;
}
