#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSUInteger, ETStatusIconState) {
    ETStatusIconStateReady,
    ETStatusIconStatePaused,
    ETStatusIconStateSending,
    ETStatusIconStateError,
};

ETStatusIconState ETStatusIconStateForFlags(BOOL active, BOOL busy, BOOL error);
NSImage *ETStatusIcon(ETStatusIconState state);
NSColor *ETStatusIconTintColor(ETStatusIconState state);
NSString *ETStatusIconAccessibilityLabel(ETStatusIconState state);
