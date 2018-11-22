//
//  InfoWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/21/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "File.h"
#import "Consts.h"
#import "Command.h"
#import "Extension.h"
#import "Utilities.h"
#import "InfoWindowController.h"


@implementation InfoWindowController

@synthesize itemObj;
@synthesize plistWindowController;

//automatically invoked when window is loaded
// ->set to white
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    return;
}

//init method
// ->save item and load nib
-(id)initWithItem:(ItemBase*)selectedItem
{
    self = [super init];
    if(nil != self)
    {
        //load file info window
        if(YES == [selectedItem isKindOfClass:[File class]])
        {
            //load nib
            self.windowController = [[InfoWindowController alloc] initWithWindowNibName:@"FileInfoWindow"];
        }
        //load extension info window
        else if(YES == [selectedItem isKindOfClass:[Extension class]])
        {
            //load nib
            self.windowController = [[InfoWindowController alloc] initWithWindowNibName:@"ExtensionInfoWindow"];
        }
    
        //save item
        self.windowController.itemObj = selectedItem;
    }
        
    return self;
}


//automatically called when nib is loaded
// ->save self into iVar, and center window
-(void)awakeFromNib
{
    //configure UI
    [self configure];
    
    //center
    [self.window center];
}

//configure window
// ->add item's attributes (name, path, etc.)
-(void)configure
{
    //handle File class
    if(YES == [self.itemObj isKindOfClass:[File class]])
    {
        //set icon
        self.icon.image = getIconForBinary(self.itemObj.path, ((File*)itemObj).bundle);
        
        //set name
        [self.name setStringValue:self.itemObj.name];
        
        //flagged files
        // ->make name red!
        if( (nil != ((File*)self.itemObj).vtInfo) &&
            (0 != [((File*)self.itemObj).vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue]) )
        {
            //set color (light red)
            self.name.textColor = [NSColor redColor];
        }
        
        //set path
        [self.path setStringValue:self.itemObj.path];
        
        //set hash
        [self.hashes setStringValue:[NSString stringWithFormat:@"%@ / %@", ((File*)self.itemObj).hashes[KEY_HASH_MD5], ((File*)self.itemObj).hashes[KEY_HASH_SHA1]]];
        
        //set size
        [self.size setStringValue:[NSString stringWithFormat:@"%llu bytes", ((File*)self.itemObj).attributes.fileSize]];
        
        //set date
        [self.date setStringValue:[NSString stringWithFormat:@"%@ (created) / %@ (modified)", ((File*)self.itemObj).attributes.fileCreationDate, ((File*)self.itemObj).attributes.fileModificationDate]];
        
        //set plist
        if(nil != ((File*)self.itemObj).plist)
        {
            //create/set attributes string
            self.plist.attributedStringValue = [[NSMutableAttributedString alloc] initWithString:((File*)self.itemObj).plist attributes:@{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:11], NSLinkAttributeName:[NSURL URLWithString:@"#"], NSForegroundColorAttributeName:[NSColor blueColor], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSSingleUnderlineStyle]}];
            
            //add click event handler
            [self.plist addGestureRecognizer:[[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(showPlist:)]];
        }
        //no plist
        else
        {
            //set
            [self.plist setStringValue:@"no plist for item"];
        }
        
        //set signing info
        [self.sign setStringValue:[(File*)self.itemObj formatSigningInfo]];
    }
    
    //handle Extension class
    if(YES == [self.itemObj isKindOfClass:[Extension class]])
    {
        //set icon
        self.icon.image = getIconForBinary(((Extension*)itemObj).browser, nil);
        
        //set name
        [self.name setStringValue:self.itemObj.name];
        
        //set path
        [self.path setStringValue:self.itemObj.path];
        
        //set description
        // ->optional
        if(nil != ((Extension*)self.itemObj).details)
        {
            //set
            [self.details setStringValue:[NSString stringWithFormat:@"%@", ((Extension*)self.itemObj).details]];
        }
               
        //set id
        [self.identifier setStringValue:[NSString stringWithFormat:@"%@", ((Extension*)self.itemObj).identifier]];
        
        //set date
        [self.date setStringValue:[NSString stringWithFormat:@"%@ (created) / %@ (modified)", ((File*)self.itemObj).attributes.fileCreationDate, ((File*)self.itemObj).attributes.fileModificationDate]];
        
        //set signing info
        //[self.sign setStringValue:[(File*)self.itemObj formatSigningInfo]];
    }
    
    return;
}

//invoked when user clicks on plist
// display plist window pane w/ contents
- (void)showPlist:(id)sender
{
    //alloc sheet
    self.plistWindowController = [[PlistWindowController alloc] initWithWindowNibName:@"PlistWindow"];
    
    //set path
    self.plistWindowController.plist = ((File*)self.itemObj).plist;
    
    //show entitlements
    [self.window beginSheet:self.plistWindowController.window completionHandler:^(NSModalResponse returnCode) {
        
        //unset window controller
        self.plistWindowController = nil;
        
    }];
    
    return;
}


//automatically invoked when user clicks 'close'
// ->just close window
-(IBAction)closeWindow:(id)sender
{
    //close
    [self.window close];
}
@end
