//
//  ItemTableController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/18/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//


#import "File.h"
#import "Consts.h"
#import "Command.h"
#import "VTButton.h"
#import "Extension.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "Results/ItemBase.h"
#import "ItemTableController.h"
#import "InfoWindowController.h"

#import <AppKit/AppKit.h>

@implementation ItemTableController

@synthesize noItemsLabel;
@synthesize itemTableView;
@synthesize vtWindowController;
@synthesize infoWindowController;


//invoked automatically while nib is loaded
// ->note: outlets are nil here...
-(id)init
{
    self = [super init];
    if(nil != self)
    {
        ;
    }
    
    return self;
}

//prevent table rows from being highlightable
-(void)awakeFromNib
{
    //disable highlighting
    [self.itemTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    
    return;
}

//table delegate
// ->return number of rows, which is just number of items in the currently selected plugin
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    //rows
    NSUInteger rows = 0;
    
    //plugin object
    PluginBase* selectedPluginObj = nil;
    
    //set selected plugin
    selectedPluginObj =  ((AppDelegate*)[[NSApplication sharedApplication] delegate]).selectedPlugin;
    
    //invoke helper function to get array
    // ->then grab count
    rows = [[self getTableItems] count];
    
    //no items have been found?
    // display 'not found' msg
    if( (0 == rows) &&
        (nil != selectedPluginObj) )
    {
        //first time
        // ->alloc/init it
        if(nil == self.noItemsLabel)
        {
            //alloc
            noItemsLabel = [[NSTextField alloc] init];
            
            //no border
            self.noItemsLabel.bordered = NO;
            
            //no background color
            self.noItemsLabel.backgroundColor = [NSColor clearColor];
            
            //font
            self.noItemsLabel.font = [NSFont fontWithName:@"Menlo-Regular" size:13];
            
            //center text
            self.noItemsLabel.alignment = NSCenterTextAlignment;
            
            //make uneditable
            self.noItemsLabel.editable = NO;
            
            //use auto-layout
            self.noItemsLabel.translatesAutoresizingMaskIntoConstraints = NO;
            
            //add to table
            [self.itemTableView addSubview:noItemsLabel];
            
            //set width constraint
            [self.noItemsLabel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[noItemsLabel(==300)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(noItemsLabel)]];
            
            //set height constraint
            [self.noItemsLabel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[noItemsLabel(==20)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(noItemsLabel)]];
            
            //set top padding constraint
            [self.noItemsLabel.superview addConstraint:[NSLayoutConstraint constraintWithItem:self.noItemsLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.noItemsLabel.superview attribute:NSLayoutAttributeTop multiplier:1.0f constant:25.0f]];
            
            //set center constraint
            [self.noItemsLabel.superview addConstraint:[NSLayoutConstraint constraintWithItem:self.noItemsLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.noItemsLabel.superview attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
        }
        
        //show label
        self.noItemsLabel.hidden = NO;
        
        //set string
        self.noItemsLabel.stringValue = [NSString stringWithFormat:@"No %@ found", [selectedPluginObj.name lowercaseString]];
    }
    
    //there *are* items
    // ->hide label
    else
    {
        //hide
        self.noItemsLabel.hidden = YES;
    }

    return rows;
}

//table delegate method
// ->return cell for row
-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    //item cell
    NSTableCellView *itemCell = nil;
    
    //array backing table
    // ->based on filtering options, will either be all items, or only unknown ones
    NSArray* tableItems = nil;
    
    //plugin item for row
    // ->this can be a File, Command, or Extension obj
    ItemBase* item = nil;
    
    //string for name
    // ->for File objs, can be attributed w/ packed/encrypted
    NSMutableAttributedString* customizedItemName = nil;
    
    //signature icon
    NSImageView* signatureImageView = nil;
    
    //VT detection ratio
    NSString* vtDetectionRatio = nil;
    
    //virus total button
    // ->for File objects only...
    VTButton* vtButton;
    
    //attribute dictionary
    NSMutableDictionary* stringAttributes = nil;
    
    //paragraph style
    NSMutableParagraphStyle* paragraphStyle = nil;
    
    //tracking area
    NSTrackingArea* trackingArea = nil;
    
    //item path's top padding (constraint)
    NSLayoutConstraint* itemPathTopPadding = nil;
    
    //item name's left padding
    NSLayoutConstraint* itemNameLeftPadding = nil;
    
    //flag indicating row has tracking area
    // ->ensures we don't add 2x
    BOOL hasTrackingArea = NO;
    
    //get array backing table
    tableItems = [self getTableItems];

    //sanity check
    // ->make sure there is table item for row
    if(tableItems.count <= row)
    {
        //bail
        goto bail;
    }
    
    //extract plugin item for row
    item = tableItems[row];
    
    //handle Command items
    // ->vry basic row, bails when done
    if(YES == [item isKindOfClass:[Command class]])
    {
        //make table cell
        itemCell = [tableView makeViewWithIdentifier:@"CommandCell" owner:self];
        if(nil == itemCell)
        {
            //bail
            goto bail;
        }
        
        //check if cell was previously used (by checking the item name)
        // ->if so, set flag to indicated tracking area does not need to be added
        if(YES != [itemCell.textField.stringValue isEqualToString:@"Command"])
        {
            //set flag
            hasTrackingArea = YES;
        }
        
        //only have to add tracking area once
        // ->add it the first time
        if(NO == hasTrackingArea)
        {
            //init tracking area
            // ->for 'show' button
            trackingArea = [[NSTrackingArea alloc] initWithRect:[[itemCell viewWithTag:TABLE_ROW_SHOW_BUTTON] bounds]
                                                        options:(NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways)
                                                          owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:TABLE_ROW_SHOW_BUTTON]}];
            
            //add tracking area to 'show' button
            [[itemCell viewWithTag:TABLE_ROW_SHOW_BUTTON] addTrackingArea:trackingArea];
            
        }
        
        //set text to command
        [itemCell.textField setStringValue:((Command*)item).command];
        
        //set detailed text
        // ->always item's path
        [[itemCell viewWithTag:TABLE_ROW_SUB_TEXT_TAG] setStringValue:item.path];

        //all done
        goto bail;
    }

    //make table cell
    itemCell = [tableView makeViewWithIdentifier:@"FileCell" owner:self];
    if(nil == itemCell)
    {
        //bail
        goto bail;
    }
    
    //grab item's name left constraint
    itemNameLeftPadding = findConstraint(itemCell, @"itemNameLeftPadding");
    
    //grab item's path top constraint
    itemPathTopPadding = findConstraint(itemCell, @"itemPathTopPadding");
    
    //set item's name left padding to default
    if(nil != itemNameLeftPadding)
    {
        //set
        itemNameLeftPadding.constant = 23;
    }
    
    //set item's path top padding to default
    if(nil != itemPathTopPadding)
    {
        //shift up
        itemPathTopPadding.constant = 2;
    }
    
    //check if cell was previously used (by checking the item name)
    // if so, set flag to indicated tracking area does not need to be added
    if(YES != [itemCell.textField.stringValue isEqualToString:@"Item Name"])
    {
        //set flag
        hasTrackingArea = YES;
    }
    
    //default color
    itemCell.textField.textColor = NSColor.controlTextColor;
    
    //default
    // ->hide plist label
    [((NSTextField*)[itemCell viewWithTag:TABLE_ROW_PLIST_LABEL]) setHidden:YES];
    
    //set main text
    // ->name
    itemCell.textField.attributedStringValue = [[NSMutableAttributedString alloc] initWithString:item.name];
        
    //only have to add tracking area once
    // ->add it the first time
    if(NO == hasTrackingArea)
    {
        //init tracking area
        // ->for 'show' button
        trackingArea = [[NSTrackingArea alloc] initWithRect:[[itemCell viewWithTag:TABLE_ROW_SHOW_BUTTON] bounds]
                        options:(NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways)
                        owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:TABLE_ROW_SHOW_BUTTON]}];
        
        //add tracking area to 'show' button
        [[itemCell viewWithTag:TABLE_ROW_SHOW_BUTTON] addTrackingArea:trackingArea];
        
        //init tracking area
        // ->for 'info' button
        trackingArea = [[NSTrackingArea alloc] initWithRect:[[itemCell viewWithTag:TABLE_ROW_INFO_BUTTON] bounds]
                        options:(NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways)
                        owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:TABLE_ROW_INFO_BUTTON]}];
        
        //add tracking area to 'info' button
        [[itemCell viewWithTag:TABLE_ROW_INFO_BUTTON] addTrackingArea:trackingArea];
    }
    
    //get signature image view
    signatureImageView = [itemCell viewWithTag:TABLE_ROW_SIGNATURE_ICON];
    
    //set detailed text
    // ->path
    if(YES == [item isKindOfClass:[File class]])
    {
        //grab virus total button
        // ->need it for frame computations, etc
        vtButton = [itemCell viewWithTag:TABLE_ROW_VT_BUTTON];
        
        //set image
        // ->app's icon
        itemCell.imageView.image = getIconForBinary(((File*)item).path, ((File*)item).bundle);

        //set signature icon
        signatureImageView.image = getCodeSigningIcon((File*)item);
        
        //show signature icon
        signatureImageView.hidden = NO;
        
        //set detailed text
        // ->always item's path
        [[itemCell viewWithTag:TABLE_ROW_SUB_TEXT_TAG] setStringValue:item.path];
        
        //for files w/ plist
        // ->show plist
        if(nil != ((File*)item).plist)
        {
            //shift up item path
            // ->makes name for plist
            if(nil != itemPathTopPadding)
            {
                //shift up
                itemPathTopPadding.constant = -2;
            }
            
            //set plist
            [((NSTextField*)[itemCell viewWithTag:TABLE_ROW_PLIST_LABEL]) setStringValue:((File*)item).plist];
            
            //show
            [((NSTextField*)[itemCell viewWithTag:TABLE_ROW_PLIST_LABEL]) setHidden:NO];
        }
        
        //configure/show VT info
        // ->only if 'disable' preference not set
        if(YES != ((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController.disableVTQueries)
        {
            //set button delegate
            vtButton.delegate = self;
            
            //save file obj
            vtButton.fileObj = ((File*)item);
            
            //check if have vt results
            if(nil != ((File*)item).vtInfo)
            {
                //set font
                [vtButton setFont:[NSFont fontWithName:@"Menlo-Bold" size:25]];
                
                //enable
                vtButton.enabled = YES;
                
                //got VT results
                // ->check 'permalink' to determine if file is known to VT
                //   then, show ratio and set to red if file is flagged
                if(nil != ((File*)item).vtInfo[VT_RESULTS_URL])
                {
                    //alloc paragraph style
                    paragraphStyle = [[NSMutableParagraphStyle alloc] init];
                    
                    //center the text
                    [paragraphStyle setAlignment:NSCenterTextAlignment];
                    
                    //alloc attributes dictionary
                    stringAttributes = [NSMutableDictionary dictionary];
                    
                    //set underlined attribute
                    stringAttributes[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
                    
                    //set alignment (center)
                    stringAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
                    
                    //set font
                    stringAttributes[NSFontAttributeName] = [NSFont fontWithName:@"Menlo-Bold" size:15];
                    
                    //compute detection ratio
                    vtDetectionRatio = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)[((File*)item).vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue], (unsigned long)[((File*)item).vtInfo[VT_RESULTS_TOTAL] unsignedIntegerValue]];
                    
                    //known 'good' files (0 positivies)
                    // ->(re)set colors
                    if(0 == [((File*)item).vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue])
                    {
                        //(re)set title color
                        itemCell.textField.textColor = NSColor.controlTextColor;
                        
                        //(re)set color
                        stringAttributes[NSForegroundColorAttributeName] = NSColor.controlTextColor;
                        
                        //set string (vt ratio), with attributes
                        [vtButton setAttributedTitle:[[NSAttributedString alloc] initWithString:vtDetectionRatio attributes:stringAttributes]];
                        
                        //set color (gray)
                        stringAttributes[NSForegroundColorAttributeName] = [NSColor grayColor];
                        
                        //set selected text color
                        [vtButton setAttributedAlternateTitle:[[NSAttributedString alloc] initWithString:vtDetectionRatio attributes:stringAttributes]];
                    }
                    //files flagged by VT
                    // ->set name and detection to red
                    else
                    {
                        //set title red
                        itemCell.textField.textColor = [NSColor redColor];
                        
                        //set color (red)
                        stringAttributes[NSForegroundColorAttributeName] = [NSColor redColor];
                        
                        //set string (vt ratio), with attributes
                        [vtButton setAttributedTitle:[[NSAttributedString alloc] initWithString:vtDetectionRatio attributes:stringAttributes]];
                        
                        //set selected text color
                        [vtButton setAttributedAlternateTitle:[[NSAttributedString alloc] initWithString:vtDetectionRatio attributes:stringAttributes]];
                        
                    }
                    
                    //enable
                    [vtButton setEnabled:YES];
                }
            
                //file is not known
                // ->reset title to '?'
                else
                {
                    //set title
                    [vtButton setTitle:@"?"];
                }
            }
        
            //no VT results (e.g. unknown file)
            else
            {
                //set font
                [vtButton setFont:[NSFont fontWithName:@"Menlo-Bold" size:8]];
                
                //set title
                [vtButton setTitle:@"▪ ▪ ▪"];
                
                //disable
                vtButton.enabled = NO;
            }
            
            //show virus total button
            vtButton.hidden = NO;
            
            //show virus total label
            [[itemCell viewWithTag:TABLE_ROW_VT_BUTTON+1] setHidden:NO];
            
        }//show VT info (pref not disabled)
        
        //hide VT info
        else
        {
            //hide virus total button
            vtButton.hidden = YES;
            
            //hide virus total button label
            [[itemCell viewWithTag:TABLE_ROW_VT_BUTTON+1] setHidden:YES];
        }
        
        //add 'packed' / 'encrypted' in red
        // ->done here since VT stuff (above) sets name globally
        if( (YES == ((File*)item).isPacked) ||
            (YES == ((File*)item).isEncrypted) )
        {
            //init task string
            customizedItemName = [[NSMutableAttributedString alloc] initWithString:@""];
            
            //add existing name
            // ->uses existing color
            [customizedItemName appendAttributedString:[[NSMutableAttributedString alloc] initWithString:itemCell.textField.stringValue attributes:@{NSForegroundColorAttributeName:itemCell.textField.textColor}]];
            
            //add '('
            // ->color, light gray
            [customizedItemName appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" (" attributes:@{NSForegroundColorAttributeName:[NSColor lightGrayColor]}]];
            
            //add 'encrypted'
            // ->green if trusted (apple, etc), otherwise red
            if(YES == ((File*)item).isEncrypted)
            {
                //trusted; green
                if(YES == ((File*)item).isTrusted)
                {
                    //add
                    [customizedItemName appendAttributedString:[[NSAttributedString alloc] initWithString:@"encrypted" attributes:@{NSForegroundColorAttributeName:[NSColor colorWithDeviceRed:38.0f/256.0f green:191.0f/256.0f blue:99.0f/256.0f alpha:1.0f]}]];

                }
                //untrusted; red
                else
                {
                    //add
                    [customizedItemName appendAttributedString:[[NSAttributedString alloc] initWithString:@"encrypted" attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];

                }
                
            }
            //add 'packed'
            // ->can't be both; and encryption takes precedence
            else
            {
                //add
                [customizedItemName appendAttributedString:[[NSAttributedString alloc] initWithString:@"packed" attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
            }
            
            //close string with ')'
            // ->color; light gray
            [customizedItemName appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@")" attributes:@{NSForegroundColorAttributeName:[NSColor lightGrayColor]}]];
            
            //update name
            itemCell.textField.attributedStringValue = customizedItemName;
        }
        
    }//file(s)
    
    //EXTENSIONS
    else if(YES == [item isKindOfClass:[Extension class]])
    {
        //hide signature status
        signatureImageView.hidden = YES;
        
        //set item's name left padding back
        // ->extensions don't have a signing icon
        if(nil != itemNameLeftPadding)
        {
            //set
            itemNameLeftPadding.constant = 8;
        }
        
                
        //for extensions
        // ->path should start inline w/ name
        //pathFrame.origin.x = 50;
        
        //path should go to info button
        //pathFrame.size.width = ((NSTextField*)[itemCell viewWithTag:TABLE_ROW_INFO_BUTTON]).frame.origin.x - pathFrame.origin.x;
        
        //set detailed text
        // ->always item's path
        [[itemCell viewWithTag:TABLE_ROW_SUB_TEXT_TAG] setStringValue:item.path];

        //set image
        // ->will be browser's icon
        itemCell.imageView.image = getIconForBinary(((Extension*)item).browser, nil);
        
        //hide virus total icon
        [[itemCell viewWithTag:TABLE_ROW_VT_BUTTON] setHidden:YES];
        
        //hide virus total label
        [[itemCell viewWithTag:TABLE_ROW_VT_BUTTON+1] setHidden:YES];
    
    }//extension(s)

//bail
bail:
    
    return itemCell;
}

//automatically invoked when mouse entered
-(void)mouseEntered:(NSEvent*)theEvent
{
    //mouse entered
    // ->highlight (visual) state
    [self buttonAppearance:theEvent shouldReset:NO];
    
    return;
    
}

//automaticall invoked when mouse exits
-(void)mouseExited:(NSEvent*)theEvent
{
    //mouse exited
    // ->so reset button to original (visual) state
    [self buttonAppearance:theEvent shouldReset:YES];
    
    return;
}

//set or unset button's highlight
-(void)buttonAppearance:(NSEvent*)theEvent shouldReset:(BOOL)shouldReset
{
    //mouse point
    NSPoint mousePoint = {0};
    
    //row index
    NSUInteger rowIndex = -1;
    
    //current row
    NSTableCellView* currentRow = nil;
    
    //tag
    NSUInteger tag = 0;
    
    //button
    NSButton* button = nil;
    
    //image name
    NSString* imageName =  nil;
    
    //extract tag
    tag = [((NSDictionary*)theEvent.userData)[@"tag"] unsignedIntegerValue];
    
    //restore button back to default (visual) state
    if(YES == shouldReset)
    {
        //set image name
        // ->'info'
        if(TABLE_ROW_INFO_BUTTON == tag)
        {
            //set
            imageName = @"info";
        }
        //set image name
        // ->'info'
        else if(TABLE_ROW_SHOW_BUTTON == tag)
        {
            //set
            imageName = @"show";
        }
    }
    //highlight button
    else
    {
        //set image name
        // ->'info'
        if(TABLE_ROW_INFO_BUTTON == tag)
        {
            //set
            imageName = @"infoOver";
        }
        //set image name
        // ->'info'
        else if(TABLE_ROW_SHOW_BUTTON == tag)
        {
            //set
            imageName = @"showOver";
        }
    }
    
    //grab mouse point
    mousePoint = [self.itemTableView convertPoint:[theEvent locationInWindow] fromView:nil];
    
    //compute row indow
    rowIndex = [self.itemTableView rowAtPoint:mousePoint];
    
    //sanity check
    if(-1 == rowIndex)
    {
        //bail
        goto bail;
    }
    
    //get row that's about to be selected
    currentRow = [self.itemTableView viewAtColumn:0 row:rowIndex makeIfNecessary:YES];
    
    //get button
    // ->tag id of button, passed in userData var
    button = [currentRow viewWithTag:[((NSDictionary*)theEvent.userData)[@"tag"] unsignedIntegerValue]];

    //restore default button image
    // ->for 'info' and 'show' buttons
    if(nil != imageName)
    {
        //set image
        [button setImage:[NSImage imageNamed:imageName]];
    }
    
//bail
bail:
    
    return;
}

//scroll back up to top of table
-(void)scrollToTop
{
    //scroll if more than 1 row
    if([self.itemTableView numberOfRows] > 0)
    {
        //top
        [self.itemTableView scrollRowToVisible:0];
    }
}

//helper function
// ->get items array (either all or just unknown)
-(NSArray*)getTableItems
{
    //array backing table
    // ->based on filtering options, will either be all items, or only unknown ones
    NSArray* tableItems = nil;
    
    //plugin object
    PluginBase* selectedPluginObj = nil;

    //set selected plugin from app delegate
    selectedPluginObj =  ((AppDelegate*)[[NSApplication sharedApplication] delegate]).selectedPlugin;
    
    //set array backing table
    // ->case: no filtering (i.e., all items)
    if(YES == ((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController.showTrustedItems)
    {
        //set count
        tableItems = selectedPluginObj.allItems;
    }
    //set array backing table
    // ->case: filtering (i.e., unknown items)
    else
    {
        //set count
        tableItems = selectedPluginObj.unknownItems;
    }
    
    return tableItems;
}


//automatically invoked when user clicks the 'show in finder' icon
// ->open Finder to show item
-(IBAction)showInFinder:(id)sender
{
    //array backing table
    NSArray* tableItems = nil;
    
    //selected item
    // ->will either be a File, Extension, or Command obj
    ItemBase* selectedItem = nil;
    
    //index of selected row
    NSInteger selectedRow = 0;
    
    //file open error alert
    NSAlert* errorAlert = nil;
    
    //grab selected row
    selectedRow = [self.itemTableView rowForView:sender];
    
    //grab item table items
    tableItems = [self getTableItems];
    
    //sanity check
    // ->make sure row has item
    if(tableItems.count < selectedRow)
    {
        //bail
        goto bail;
    }
    
    //extract selected item
    selectedItem = tableItems[selectedRow];

    //open item in Finder
    // ->error alert shown if file open fails
    if(YES != [[NSWorkspace sharedWorkspace] selectFile:[selectedItem pathForFinder] inFileViewerRootedAtPath:@""])
    {
        //alloc/init alert
        errorAlert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"ERROR:\nfailed to open %@", [selectedItem pathForFinder]] defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"errno value: %d", errno];
        
        //show it
        [errorAlert runModal];
    }
    
//bail
bail:
        
    return;
}

//automatically invoked when user clicks the 'info' icon
// ->create/configure/display info window
-(IBAction)showInfo:(id)sender
{
    //array backing table
    NSArray* tableItems = nil;
    
    //selected item
    // ->will either be a File, Extension, or Command obj
    ItemBase* selectedItem = nil;
    
    //index of selected row
    NSInteger selectedRow = 0;

    //grab selected row
    selectedRow = [self.itemTableView rowForView:sender];
    
    //grab item table items
    tableItems = [self getTableItems];
    
    //sanity check
    // ->make sure row has item
    if(tableItems.count < selectedRow)
    {
        //bail
        goto bail;
    }
    
    //extract selected item
    // ->invoke helper function to get array backing table
    selectedItem = tableItems[selectedRow];
   
    //alloc/init info window
    infoWindowController = [[InfoWindowController alloc] initWithItem:selectedItem];
    
    //show it
    [self.infoWindowController.windowController showWindow:self];
    
//bail
bail:
    
    return;
}

//invoked when the user clicks 'virus total' icon
// ->launch browser and browse to virus total's page
-(void)showVTInfo:(NSView*)button
{
    //array backing table
    NSArray* tableItems = nil;
    
    //selected item
    File* selectedItem = nil;

    //row that button was clicked on
    NSUInteger rowIndex = -1;
    
    //get row index
    rowIndex = [self.itemTableView rowForView:button];
    
    //grab item table items
    tableItems = [self getTableItems];
    
    //sanity check
    // ->make sure row has item
    if(tableItems.count < rowIndex)
    {
        //bail
        goto bail;
    }

    //sanity check
    if(-1 != rowIndex)
    {
        //extract selected item
        // ->invoke helper function to get array backing table
        selectedItem = tableItems[rowIndex];
        
        //alloc/init info window
        vtWindowController = [[VTInfoWindowController alloc] initWithItem:selectedItem];
        
        //show it
        [self.vtWindowController.windowController showWindow:self];
      
    }
    
//bail
bail:
    
    return;
}


//set code signing image
// ->either signed, unsigned, or unknown
NSImage* getCodeSigningIcon(File* binary)
{
    //signature image
    NSImage* codeSignIcon = nil;
    
    //no signing info or signing error
    if( (nil == binary.signingInfo) ||
        (nil == binary.signingInfo[KEY_SIGNATURE_STATUS]) ||
        (errSecSuccess != [binary.signingInfo[KEY_SIGNATURE_STATUS] intValue]) )
    {
        //set
        codeSignIcon = [NSImage imageNamed:@"unknown"];
    }

    //apple?
    else if(Apple == [binary.signingInfo[KEY_SIGNATURE_SIGNER] intValue])
    {
        //set
        codeSignIcon = [NSImage imageNamed:@"signedAppleIcon"];
    }
    
    //signed
    else if(errSecSuccess == [binary.signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //set
        codeSignIcon = [NSImage imageNamed:@"signed"];
    }
    
    //unsigned
    else if(errSecCSUnsigned == [binary.signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //set
        codeSignIcon = [NSImage imageNamed:@"unsigned"];
    }
   
    return codeSignIcon;
}

@end
