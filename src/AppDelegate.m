#import "AppDelegate.h"
#import "Shortcut.h"
#import "Storage.h"
#import "MediaSession.h"

@interface ETAppDelegate ()
@property ETMediaSession *session;
@property NSStatusItem *statusItem;
@property NSMenuItem *summaryItem;
@property NSMenuItem *resultItem;
@property NSMenuItem *toggleItem;
@property BOOL enabled;
@property BOOL sleeping;
@property BOOL locked;
@property BOOL stopping;
@property BOOL busy;
@property NSUInteger generation;
@property NSUInteger received;
@property NSUInteger sent;
@property NSMutableArray<NSDictionary *> *pending;
@end

@implementation ETAppDelegate
- (BOOL)accepting { return self.enabled && !self.sleeping && !self.locked && !self.stopping; }
- (void)updateCounter {
    self.statusItem.button.title = self.enabled ? @"EarTap" : @"EarTap ⏸";
    self.summaryItem.title = [NSString stringWithFormat:@"收到 %lu / 已发送 %lu", self.received, self.sent];
    self.toggleItem.title = self.enabled ? @"暂停映射" : @"启用映射";
}
- (void)refreshSession {
    BOOL active = [self accepting];
    [self.session setEnabled:active];
    [self updateCounter];
}
- (void)cancelPending {
    self.generation++;
    [self.pending removeAllObjects];
    // A started key sequence must finish releasing its modifiers.
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.pending = NSMutableArray.new;
    self.enabled = YES;
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSMenu *menu = NSMenu.new;
    self.summaryItem = [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    self.resultItem = [menu addItemWithTitle:@"等待媒体命令" action:nil keyEquivalent:@""];
    self.toggleItem = [menu addItemWithTitle:@"" action:@selector(toggle:) keyEquivalent:@""];
    self.toggleItem.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    for (NSArray *entry in @[@[@"测试快捷键（2 秒后）", @"testOnce:"], @[@"编辑快捷键配置", @"editConfig:"],
                             @[@"打开日志", @"showLog:"], @[@"检查辅助功能权限", @"checkPermission:"],
                             @[@"退出 EarTap", @"quit:"]]) {
        [menu addItemWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:@""].target = self;
    }
    self.statusItem.menu = menu;
    __weak ETAppDelegate *weak = self;
    self.session = [[ETMediaSession alloc] initWithHandler:^(NSString *source) { [weak receive:source]; }];
    NSNotificationCenter *nc = NSWorkspace.sharedWorkspace.notificationCenter;
    for (NSString *name in @[NSWorkspaceWillSleepNotification, NSWorkspaceDidWakeNotification,
                             NSWorkspaceSessionDidBecomeActiveNotification, NSWorkspaceSessionDidResignActiveNotification]) {
        [nc addObserver:self selector:@selector(lifecycle:) name:name object:nil];
    }
    [self refreshSession];
    ETLog([NSString stringWithFormat:@"READY accessibility=%d", AXIsProcessTrusted()]);
    if (!AXIsProcessTrusted()) self.resultItem.title = @"请从菜单检查辅助功能权限";
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible {
    (void)app; (void)visible;
    // Opening the app is never a shortcut trigger.
    return NO;
}
- (void)toggle:(id)sender {
    (void)sender;
    self.enabled = !self.enabled;
    [self cancelPending];
    [self refreshSession];
    self.resultItem.title = self.enabled ? @"等待媒体命令" : @"映射已暂停";
    ETLog(self.enabled ? @"ENABLED" : @"PAUSED");
}
- (void)lifecycle:(NSNotification *)note {
    if ([note.name isEqual:NSWorkspaceWillSleepNotification]) self.sleeping = YES;
    if ([note.name isEqual:NSWorkspaceDidWakeNotification]) self.sleeping = NO;
    if ([note.name isEqual:NSWorkspaceSessionDidResignActiveNotification]) self.locked = YES;
    if ([note.name isEqual:NSWorkspaceSessionDidBecomeActiveNotification]) self.locked = NO;
    [self cancelPending];
    [self refreshSession];
    ETLog([@"LIFECYCLE " stringByAppendingString:note.name]);
}
- (void)testOnce:(id)sender {
    (void)sender;
    NSUInteger generation = self.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (generation == self.generation) [self receive:@"menu-test"];
    });
}
- (void)editConfig:(id)sender { (void)sender; [NSWorkspace.sharedWorkspace openURL:ETConfigURL()]; }
- (void)showLog:(id)sender { (void)sender; [NSWorkspace.sharedWorkspace openURL:ETLogURL()]; }
- (void)checkPermission:(id)sender {
    (void)sender;
    BOOL trusted = AXIsProcessTrusted();
    self.resultItem.title = trusted ? @"辅助功能权限正常" : @"请在系统设置中允许 EarTap";
    ETLog([NSString stringWithFormat:@"CHECK accessibility=%d", trusted]);
    if (!trusted) {
        NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
    }
}
- (void)quit:(id)sender { (void)sender; [NSApp terminate:nil]; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    (void)sender;
    self.stopping = YES;
    [self cancelPending];
    [self.session close];
    ETLog(@"STOPPING");
    return self.busy ? NSTerminateLater : NSTerminateNow;
}
- (void)applicationWillTerminate:(NSNotification *)note {
    (void)note;
    [self.session close];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}
- (void)receive:(NSString *)source {
    if (![self accepting]) return;
    NSUInteger requestID = ++self.received;
    ETLog([NSString stringWithFormat:@"RECEIVED id=%lu source=%@", requestID, source]);
    [self updateCounter];
    if (self.pending.count >= 8) {
        ETLog([NSString stringWithFormat:@"QUEUE_FULL id=%lu", requestID]);
        self.resultItem.title = @"请求过多，已忽略";
        return;
    }
    [self.pending addObject:@{@"id": @(requestID), @"time": @(NSProcessInfo.processInfo.systemUptime), @"generation": @(self.generation)}];
    [self next];
}
- (void)finish:(NSString *)status request:(NSDictionary *)request {
    ETLog([NSString stringWithFormat:@"%@ id=%@", status, request[@"id"]]);
    NSDictionary *labels = @{@"SENT": @"快捷键已发送，目标应用状态未确认",
        @"NEEDS_ACCESSIBILITY": @"需要开启 EarTap 的辅助功能权限",
        @"KEYS_HELD": @"修饰键被按住，已取消", @"EXPIRED": @"请求等待过久，已取消",
        @"CANCELLED": @"操作已取消", @"EVENT_ERROR": @"按键发送失败"};
    self.resultItem.title = labels[status] ?: @"配置无效，请查看日志";
    self.busy = NO;
    if (self.stopping) { [NSApp replyToApplicationShouldTerminate:YES]; return; }
    [self updateCounter];
    [self next];
}
- (void)readyToSend:(NSDictionary *)shortcut request:(NSDictionary *)request {
    if (![self accepting] || [request[@"generation"] unsignedIntegerValue] != self.generation) {
        [self finish:@"CANCELLED" request:request]; return;
    }
    if (NSProcessInfo.processInfo.systemUptime - [request[@"time"] doubleValue] > 3) {
        [self finish:@"EXPIRED" request:request]; return;
    }
    if (!AXIsProcessTrusted()) { [self finish:@"NEEDS_ACCESSIBILITY" request:request]; return; }
    CGEventFlags flags = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
    CGEventFlags mask = kCGEventFlagMaskCommand | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate | kCGEventFlagMaskShift | kCGEventFlagMaskSecondaryFn;
    if (flags & mask) { [self finish:@"KEYS_HELD" request:request]; return; }
    ETLog([NSString stringWithFormat:@"SENDING id=%@ shortcut=%@", request[@"id"], shortcut[@"label"]]);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL success = ETSendShortcut(shortcut);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) self.sent++;
            [self finish:success ? @"SENT" : @"EVENT_ERROR" request:request];
        });
    });
}
- (void)next {
    if (![self accepting] || self.busy || !self.pending.count) return;
    NSDictionary *request = self.pending.firstObject;
    [self.pending removeObjectAtIndex:0];
    self.busy = YES;
    if (NSProcessInfo.processInfo.systemUptime - [request[@"time"] doubleValue] > 3) {
        [self finish:@"EXPIRED" request:request]; return;
    }
    NSString *failure = nil;
    NSDictionary *shortcut = ETParseShortcut([NSData dataWithContentsOfURL:ETConfigURL()], &failure);
    if (!shortcut) { [self finish:[@"INVALID_CONFIG: " stringByAppendingString:failure] request:request]; return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, [shortcut[@"settleDelayMs"] longLongValue] * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [self readyToSend:shortcut request:request];
    });
}
@end
