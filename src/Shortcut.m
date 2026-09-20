#import "Shortcut.h"
#import <Carbon/Carbon.h>
#include <IOKit/hidsystem/IOLLEvent.h>
#include <math.h>
#include <unistd.h>

NSDictionary *ETParseShortcut(NSData *data, NSString **failure) {
    id config = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![config isKindOfClass:NSDictionary.class] ||
        ![config[@"key"] isKindOfClass:NSString.class] ||
        ![config[@"modifiers"] isKindOfClass:NSArray.class]) {
        *failure = @"shortcut.json must contain a key string and a modifiers array.";
        return nil;
    }
    NSSet *allowed = [NSSet setWithArray:@[@"key", @"modifiers", @"settleDelayMs", @"eventIntervalMs", @"keyHoldMs"]];
    for (NSString *name in config) if (![allowed containsObject:name]) {
        *failure = [@"Unknown setting: " stringByAppendingString:name];
        return nil;
    }
    NSDictionary *keys = @{
        @"a": @0, @"s": @1, @"d": @2, @"f": @3, @"h": @4, @"g": @5,
        @"z": @6, @"x": @7, @"c": @8, @"v": @9, @"b": @11,
        @"q": @12, @"w": @13, @"e": @14, @"r": @15, @"y": @16, @"t": @17,
        @"o": @31, @"u": @32, @"i": @34, @"p": @35,
        @"l": @37, @"j": @38, @"k": @40, @"n": @45, @"m": @46,
        @"space": @(kVK_Space), @"return": @(kVK_Return), @"escape": @(kVK_Escape),
        @"tab": @(kVK_Tab), @"delete": @(kVK_Delete),
        @"left": @(kVK_LeftArrow), @"right": @(kVK_RightArrow),
        @"up": @(kVK_UpArrow), @"down": @(kVK_DownArrow),
        @"0": @29, @"1": @18, @"2": @19, @"3": @20, @"4": @21,
        @"5": @23, @"6": @22, @"7": @26, @"8": @28, @"9": @25
    };
    NSDictionary *modifierDefinitions = @{
        @"command": @[@(kVK_Command), @(kCGEventFlagMaskCommand | NX_DEVICELCMDKEYMASK)],
        @"shift": @[@(kVK_Shift), @(kCGEventFlagMaskShift | NX_DEVICELSHIFTKEYMASK)],
        @"option": @[@(kVK_Option), @(kCGEventFlagMaskAlternate | NX_DEVICELALTKEYMASK)],
        @"control": @[@(kVK_Control), @(kCGEventFlagMaskControl | NX_DEVICELCTLKEYMASK)],
        @"fn": @[@(kVK_Function), @(kCGEventFlagMaskSecondaryFn)]
    };
    NSString *key = [config[@"key"] lowercaseString];
    NSArray *modifiers = config[@"modifiers"];
    NSMutableSet *seen = [NSMutableSet set];
    if (!keys[key] || modifiers.count > 5) {
        *failure = @"Unsupported key or too many modifiers. See docs/configuration.md.";
        return nil;
    }
    NSMutableArray *definitions = [NSMutableArray array];
    for (id name in modifiers) {
        if (![name isKindOfClass:NSString.class] || !modifierDefinitions[name] || [seen containsObject:name]) {
            *failure = @"Modifiers must be distinct: command, shift, option, control, fn.";
            return nil;
        }
        [seen addObject:name];
        [definitions addObject:modifierDefinitions[name]];
    }
    NSString *label = modifiers.count ? [NSString stringWithFormat:@"%@+%@", [modifiers componentsJoinedByString:@"+"], key] : key;
    NSMutableDictionary *result = [@{@"keyCode": keys[key], @"modifiers": definitions, @"label": label} mutableCopy];
    NSDictionary *timings = @{@"settleDelayMs": @250, @"eventIntervalMs": @40, @"keyHoldMs": @80};
    for (NSString *name in timings) {
        id value = config[name] ?: timings[name];
        if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() || !isfinite([value doubleValue]) ||
            [value doubleValue] < 10 || [value doubleValue] > 1500) {
            *failure = [NSString stringWithFormat:@"%@ must be a number from 10 to 1500.", name];
            return nil;
        }
        result[name] = value;
    }
    return result;
}

size_t ETKeySteps(NSDictionary *shortcut, ETKeyStep steps[12]) {
    NSArray *modifiers = shortcut[@"modifiers"];
    size_t count = 0;
    CGEventFlags flags = 0;
    for (NSArray *modifier in modifiers) {
        flags |= [modifier[1] unsignedLongLongValue];
        steps[count++] = (ETKeyStep){[modifier[0] unsignedShortValue], true, kCGEventFlagsChanged, flags};
    }
    CGKeyCode key = [shortcut[@"keyCode"] unsignedShortValue];
    steps[count++] = (ETKeyStep){key, true, kCGEventKeyDown, flags};
    steps[count++] = (ETKeyStep){key, false, kCGEventKeyUp, flags};
    for (NSArray *modifier in modifiers.reverseObjectEnumerator) {
        flags &= ~[modifier[1] unsignedLongLongValue];
        steps[count++] = (ETKeyStep){[modifier[0] unsignedShortValue], false, kCGEventFlagsChanged, flags};
    }

    return count;
}

BOOL ETSendShortcut(NSDictionary *shortcut) {
    ETKeyStep steps[12];
    size_t count = ETKeySteps(shortcut, steps);
    // Track generated key state independently of real keyboard devices.
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
    if (!source) return NO;
    CGEventRef events[12] = {0};
    BOOL valid = YES;
    // Construct all events before posting, so allocation failure cannot leave keys down.
    for (size_t i = 0; i < count; i++) {
        events[i] = CGEventCreateKeyboardEvent(source, steps[i].key, steps[i].down);
        if (!events[i]) { valid = NO; break; }
        CGEventSetType(events[i], steps[i].type);
        CGEventSetFlags(events[i], steps[i].flags);
    }
    if (valid) {
        for (size_t i = 0; i < count; i++) {
            CGEventPost(kCGHIDEventTap, events[i]);
            NSUInteger delay = [shortcut[steps[i].type == kCGEventKeyDown ? @"keyHoldMs" : @"eventIntervalMs"] unsignedIntegerValue];
            usleep((useconds_t)(delay * 1000));
        }
        usleep(50000);
    }
    for (size_t i = 0; i < count; i++) if (events[i]) CFRelease(events[i]);
    CFRelease(source);
    return valid;
}
