#import "MediaSession.h"
#import <MediaPlayer/MediaPlayer.h>

@interface ETMediaSession ()
@property NSArray<MPRemoteCommand *> *commands;
@property NSMutableArray *tokens;
@property (copy) void (^handler)(NSString *);
@property (nonatomic) BOOL enabled;
@property NSUInteger generation; // Atomic snapshot for callbacks arriving on framework threads.
@end

@implementation ETMediaSession
- (instancetype)initWithHandler:(void (^)(NSString *))handler {
    if (!(self = [super init])) return nil;
    self.handler = handler;
    self.tokens = NSMutableArray.new;
    MPRemoteCommandCenter *center = MPRemoteCommandCenter.sharedCommandCenter;
    self.commands = @[center.playCommand, center.pauseCommand, center.togglePlayPauseCommand];
    NSArray *names = @[@"play", @"pause", @"toggle"];
    __weak ETMediaSession *weak = self;
    for (NSUInteger i = 0; i < self.commands.count; i++) {
        MPRemoteCommand *command = self.commands[i];
        command.enabled = NO;
        NSString *name = names[i];
        id token = [command addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            (void)event;
            NSUInteger generation = weak.generation;
            // Do not synchronously wait for main: MediaPlayer may hold framework locks.
            dispatch_async(dispatch_get_main_queue(), ^{
                ETMediaSession *session = weak;
                if (session.enabled && session.generation == generation && session.handler) session.handler(name);
            });
            // Accepted for dispatch, never a claim that the target app handled the shortcut.
            return MPRemoteCommandHandlerStatusSuccess;
        }];
        [self.tokens addObject:token];
    }
    return self;
}
- (void)setEnabled:(BOOL)enabled {
    if (_enabled == enabled) return;
    self.generation++;
    _enabled = enabled;
    for (MPRemoteCommand *command in self.commands) command.enabled = enabled;
    MPNowPlayingInfoCenter *center = MPNowPlayingInfoCenter.defaultCenter;
    if (enabled) {
        center.nowPlayingInfo = @{MPMediaItemPropertyTitle: @"EarTap", MPNowPlayingInfoPropertyPlaybackRate: @0};
        // Advertise the session without audio. These are NOT recording states.
        center.playbackState = MPNowPlayingPlaybackStatePlaying;
        center.playbackState = MPNowPlayingPlaybackStatePaused;
    } else {
        center.nowPlayingInfo = nil;
        center.playbackState = MPNowPlayingPlaybackStateStopped;
    }
}
- (void)close {
    [self setEnabled:NO];
    for (NSUInteger i = 0; i < self.commands.count; i++) [self.commands[i] removeTarget:self.tokens[i]];
    self.commands = @[];
    [self.tokens removeAllObjects];
    self.handler = nil;
}
@end
