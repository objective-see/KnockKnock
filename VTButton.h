//
//  vtButton.h
//  KnockKnock
//
//  Created by Patrick Wardle on 3/26/15.
//  Copyright (c) 2015 Lucas Derraugh. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//#import "ItemTableController.h"

@class ItemTableController;

@interface VTButton : NSButton
{
    
}

//properties

//parent object
@property(assign)ItemTableController *delegate;

//button's row index

//flag indicating press
@property BOOL mouseDown;

//flag indicating exit
@property BOOL mouseExit;



@end
