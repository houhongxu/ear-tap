#import "Storage.h"

NSURL *ETDataDirectory(void) {
    NSURL *base = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [base URLByAppendingPathComponent:@"EarTap" isDirectory:YES];
}
NSURL *ETConfigURL(void) { return [ETDataDirectory() URLByAppendingPathComponent:@"shortcut.json"]; }
NSURL *ETLogURL(void) { return [ETDataDirectory() URLByAppendingPathComponent:@"status.log"]; }
BOOL ETPrepareStorage(NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtURL:ETDataDirectory() withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    if (![fm fileExistsAtPath:ETConfigURL().path]) {
        NSURL *source = [NSBundle.mainBundle URLForResource:@"shortcut" withExtension:@"json"];
        if (!source) {
            if (error) *error = [NSError errorWithDomain:@"EarTap" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Bundled shortcut.json is missing."}];
            return NO;
        }
        if (![fm copyItemAtURL:source toURL:ETConfigURL() error:error]) return NO;
    }
    return YES;
}
void ETLog(NSString *message) {
    // All callers run on the main thread. Bounded local metadata, no input contents.
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSString *old = [NSString stringWithContentsOfURL:ETLogURL() encoding:NSUTF8StringEncoding error:nil] ?: @"";
    NSArray *lines = [[old stringByAppendingString:line] componentsSeparatedByString:@"\n"];
    if (lines.count > 501) lines = [lines subarrayWithRange:NSMakeRange(lines.count - 501, 501)];
    [[lines componentsJoinedByString:@"\n"] writeToURL:ETLogURL() atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
