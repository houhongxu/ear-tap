#import <Foundation/Foundation.h>
NSURL *ETDataDirectory(void);
NSURL *ETConfigURL(void);
NSURL *ETLogURL(void);
BOOL ETPrepareStorage(NSError **error);
void ETLog(NSString *message);
