#import "StatusIcon.h"

ETStatusIconState ETStatusIconStateForFlags(BOOL active, BOOL busy, BOOL error) {
    if (!active) return ETStatusIconStatePaused;
    if (busy) return ETStatusIconStateSending;
    if (error) return ETStatusIconStateError;
    return ETStatusIconStateReady;
}

NSString *ETStatusIconAccessibilityLabel(ETStatusIconState state) {
    switch (state) {
        case ETStatusIconStatePaused: return @"EarTap 已暂停";
        case ETStatusIconStateSending: return @"EarTap 正在发送快捷键";
        case ETStatusIconStateError: return @"EarTap 需要处理";
        default: return @"EarTap 已就绪";
    }
}

NSColor *ETStatusIconTintColor(ETStatusIconState state) {
    CGFloat alpha = state == ETStatusIconStatePaused ? 0.55 : 1.0;
    return [NSColor.whiteColor colorWithAlphaComponent:alpha];
}

static void ETDrawEarbud(void) {
    [NSColor.blackColor setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1.5, 9, 7.5, 7.5)] fill];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(5.8, 3, 3.2, 8.5) xRadius:1.6 yRadius:1.6] fill];
}

static void ETStrokeArc(CGFloat radius, CGFloat width) {
    NSBezierPath *arc = NSBezierPath.bezierPath;
    arc.lineWidth = width;
    arc.lineCapStyle = NSLineCapStyleRound;
    [arc appendBezierPathWithArcWithCenter:NSMakePoint(8.8, 9.4) radius:radius startAngle:-54 endAngle:54];
    [arc stroke];
}

NSImage *ETStatusIcon(ETStatusIconState state) {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(18, 18) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        (void)rect;
        ETDrawEarbud();
        [NSColor.blackColor setStroke];
        [NSColor.blackColor setFill];
        if (state == ETStatusIconStatePaused) {
            [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(11.2, 6.2, 1.8, 6.4) xRadius:0.9 yRadius:0.9] fill];
            [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(14.4, 6.2, 1.8, 6.4) xRadius:0.9 yRadius:0.9] fill];
        } else if (state == ETStatusIconStateError) {
            NSBezierPath *cross = NSBezierPath.bezierPath;
            cross.lineWidth = 1.8;
            cross.lineCapStyle = NSLineCapStyleRound;
            [cross moveToPoint:NSMakePoint(11.5, 6.8)];
            [cross lineToPoint:NSMakePoint(16, 11.3)];
            [cross moveToPoint:NSMakePoint(16, 6.8)];
            [cross lineToPoint:NSMakePoint(11.5, 11.3)];
            [cross stroke];
        } else {
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(8.7, 8.2, 2.4, 2.4)] fill];
            ETStrokeArc(4.1, 1.5);
            ETStrokeArc(6.5, 1.5);
            if (state == ETStatusIconStateSending) ETStrokeArc(8.8, 1.3);
        }
        return YES;
    }];
    image.template = YES;
    image.accessibilityDescription = ETStatusIconAccessibilityLabel(state);
    return image;
}
