//
//  vtButton.m
//  KnockKnock
//
//  Created by Patrick Wardle on 3/26/15.
//  Copyright (c) 2015 Lucas Derraugh. All rights reserved.
//

#import "VTButton.h"
#import "ItemTableController.h"

@implementation VTButton

@synthesize delegate;
@synthesize mouseDown;
@synthesize mouseExit;


- (void)awakeFromNib
{
    [self createTrackingArea];
    
    //[self setAction:@selector(showVirusTotal:)];
    //[self setTarget:self];
    
}

- (void)createTrackingArea
{
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                                     options:(NSTrackingInVisibleRect  | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:nil];
    [self addTrackingArea:trackingArea];
}

/*
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}
*/

- (void)mouseDown:(NSEvent *)theEvent;
{
    //NSLog(@"got right mouse down");
    
    self.mouseDown = YES;
    
    
    NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTitle]];
    NSRange titleRange = NSMakeRange(0, [colorTitle length]);
    [colorTitle addAttribute:NSForegroundColorAttributeName value:[NSColor lightGrayColor] range:titleRange];
    [self setAttributedTitle:colorTitle];
    
}

- (void)mouseUp:(NSEvent *)theEvent;
{
    //dbg msg
    //NSLog(@"got right mouse up");
    
    //shoud treat at click?
    // ->mouse up inside in non-disabled button
    if( (YES == self.isEnabled) &&
        (YES != self.mouseExit) )
    {
        //dbg msg
        //NSLog(@"MOUSE CLICK");
        
        //show virus total window
        [self.delegate performSelector:@selector(showVTInfo:) withObject:self];
    
    }
    
    NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTitle]];
    NSRange titleRange = NSMakeRange(0, [colorTitle length]);
    [colorTitle addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:titleRange];
    [self setAttributedTitle:colorTitle];
    
    //reset flag
    self.mouseDown = NO;
}

-(void)mouseEntered:(NSEvent*)theEvent
{
    //set flag
    self.mouseExit = NO;
    
        NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTitle]];
        NSRange titleRange = NSMakeRange(0, [colorTitle length]);
        [colorTitle addAttribute:NSForegroundColorAttributeName value:[NSColor grayColor] range:titleRange];
        [self setAttributedTitle:colorTitle];
  
}

-(void)mouseExited:(NSEvent*)theEvent
{
    
    //set flag
    self.mouseExit = YES;
    
    //NSLog(@"mouse exited here!!");
    
    //color
    NSColor* textColor = nil;
    
    if(YES == self.mouseDown)
    {
        textColor = [NSColor grayColor];
    }
    else
    {
        textColor = [NSColor blackColor];
    }
    
    NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTitle]];
    NSRange titleRange = NSMakeRange(0, [colorTitle length]);
    [colorTitle addAttribute:NSForegroundColorAttributeName value:textColor range:titleRange];
    [self setAttributedTitle:colorTitle];

    
   
    
}


@end
