//
//  DiffWindowController.h
//  KnockKnock
//
//  Created by Patrick Wardle on 09/01/24.
//  Copyright (c) 2024 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DiffWindowController : NSWindowController

//differences
@property(nonatomic, retain)NSString* differences;

//plist contents
@property (unsafe_unretained) IBOutlet NSTextView *contents;

@end
