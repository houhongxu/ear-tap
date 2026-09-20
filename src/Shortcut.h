#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

typedef struct {
    CGKeyCode key;
    bool down;
    CGEventType type;
    CGEventFlags flags;
} ETKeyStep;

// Returns nil with a human-readable error for malformed or unknown settings.
NSDictionary *ETParseShortcut(NSData *data, NSString **failure);
// The caller supplies room for 12 steps. Never posts input events.
size_t ETKeySteps(NSDictionary *shortcut, ETKeyStep steps[12]);
BOOL ETSendShortcut(NSDictionary *shortcut);
