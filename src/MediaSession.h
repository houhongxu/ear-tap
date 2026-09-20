#import <Foundation/Foundation.h>
@interface ETMediaSession : NSObject
- (instancetype)initWithHandler:(void (^)(NSString *source))handler;
- (void)setEnabled:(BOOL)enabled;
- (void)close;
@end
