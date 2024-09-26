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

//(path to) plist
//@property(nonatomic, retain)NSString* plist;

//signing info
//@property(nonatomic, retain)NSDictionary* signingInfo;

//plist contents
@property (unsafe_unretained) IBOutlet NSTextView *contents;

//plist path
//@property (weak) IBOutlet NSTextField *path;

@end
