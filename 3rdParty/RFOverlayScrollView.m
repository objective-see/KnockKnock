//
//  RFOverlayScrollView.m
//  RFOverlayScrollView
//
//  Created by Tim Brückmann on 31.12.12.
//  Copyright (c) 2012 Rheinfabrik. All rights reserved.
//

#import <objc/objc-class.h>
#import "RFOverlayScrollView.h"
#import "RFOverlayScroller.h"

@implementation RFOverlayScrollView

static NSComparisonResult scrollerAboveSiblingViewsComparator(NSView *view1, NSView *view2, void *context)
{
    if ([view1 isKindOfClass:[RFOverlayScroller class]]) {
        return NSOrderedDescending;
    } else if ([view2 isKindOfClass:[RFOverlayScroller class]]) {
        return NSOrderedAscending;
    }
    
    return NSOrderedSame;
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        _headerOffset = [self tableHeaderOffsetFromSuperview];
    }
    return self;
}

- (void)awakeFromNib
{
    self.wantsLayer = YES;
    _headerOffset = [self tableHeaderOffsetFromSuperview];
}

- (void)tile
{
    // Fake zero scroller width so the contentView gets drawn to the edge
    method_exchangeImplementations(class_getClassMethod([RFOverlayScroller class], @selector(scrollerWidthForControlSize:scrollerStyle:)),
                                   class_getClassMethod([RFOverlayScroller class], @selector(zeroWidth)));
	[super tile];
    // Restore original scroller width
    method_exchangeImplementations(class_getClassMethod([RFOverlayScroller class], @selector(scrollerWidthForControlSize:scrollerStyle:)),
                                   class_getClassMethod([RFOverlayScroller class], @selector(zeroWidth)));
    
    // Resize vertical scroller
    CGFloat width = [RFOverlayScroller scrollerWidthForControlSize:self.verticalScroller.controlSize
                                                         scrollerStyle:self.verticalScroller.scrollerStyle];
	[self.verticalScroller setFrame:(NSRect){
        self.bounds.size.width - width,
        self.headerOffset,
        width,
        self.bounds.size.height - self.headerOffset
    }];
    
    // Move scroller to front
    [self sortSubviewsUsingFunction:scrollerAboveSiblingViewsComparator
                            context:NULL];
}

- (NSInteger)tableHeaderOffsetFromSuperview
{
    for (NSView *subView in [self subviews])
    {
        if ([subView isKindOfClass:[NSClipView class]])
        {   for (NSView *subView2 in [subView subviews])
            {   if ([subView2 isKindOfClass:[NSTableView class]])
                {
                    return [(NSTableView *)subView2 headerView].frame.size.height;
                }
            }
        }
    }
    return 0;
}

@end
