//
//  VTInfoWindow.m
//  KnockKnock
//
//  Created by Patrick Wardle on 3/29/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "File.h"
#import "Consts.h"
#import "Utilities.h"
#import "VirusTotal.h"
#import "AppDelegate.h"
#import "VTInfoWindowController.h"
#import "3rdParty/HyperlinkTextField.h"


#import <QuartzCore/QuartzCore.h>

@interface VTInfoWindowController ()

@end

@implementation VTInfoWindowController

@synthesize windowController;


//init method
// ->save item and load nib
-(id)initWithItem:(File*)selectedItem
{
    self = [super init];
    if(nil != self)
    {
        //load nib
        self.windowController = [[VTInfoWindowController alloc] initWithWindowNibName:@"VTInfoWindow"];
    
        //save item
        self.windowController.fileObj = selectedItem;
    }
    
    return self;
}


//automatically invoked
// ->make it white
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //make it modal
    //[[NSApplication sharedApplication] runModalForWindow:self.window];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //make close button selected
    [self.window makeFirstResponder:self.closeButton];

    return;
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
    //flag
    BOOL isKnown = NO;
    
    //detection ratio
    NSString* vtDetectionRatio = nil;
    
    //color
    NSColor* textColor = nil;
    
    //get status
    if(nil != self.fileObj.vtInfo[VT_RESULTS_URL])
    {
        //known
        isKnown = YES;
    }
    
    //file status (known/unknown)
    if(YES == isKnown)
    {
        //default color to black
        textColor = [NSColor blackColor];
        
        //set color to red if its flagged
        if(0 != [self.fileObj.vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue])
        {
            //red
            textColor = [NSColor redColor];
        }
        
        //generate detection ratio
        vtDetectionRatio = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)[self.fileObj.vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue], (unsigned long)[self.fileObj.vtInfo[VT_RESULTS_TOTAL] unsignedIntegerValue]];
        
        //set name
        [self.fileName setStringValue:self.fileObj.name];
        
        //set color
        self.fileName.textColor = textColor;
        
        //detection ratio
        [self.detectionRatio setStringValue:vtDetectionRatio];
        
        //set color
        self.detectionRatio.textColor = textColor;
        
        //analysis url
        [self.analysisURL setStringValue:@"VirusTotal report"];
        
        //make analysis url a hyperlink
        makeTextViewHyperlink(self.analysisURL, [NSURL URLWithString:self.fileObj.vtInfo[VT_RESULTS_URL]]);
        
        //set 'submit' button text to 'rescan'
        self.submitButton.title = @"rescan?";
    }
    //unknown file
    else
    {
        //hide file name label
        self.fileNameLabel.hidden = YES;
        
        //hide file name
        self.fileName.hidden = YES;
        
        //hide detection ratio label
        self.detectionRatioLabel.hidden = YES;
        
        //hide detection ratio
        self.detectionRatio.hidden = YES;
        
        //hide analysis url label
        self.analysisURLLabel.hidden = YES;
        
        //hide analysis url
        self.analysisURL.hidden = YES;
        
        //set unknown file msg
        [self.unknownFile setStringValue:[NSString stringWithFormat:@"no results found for '%@'", self.fileObj.name]];
        
        //show 'unknown file' msg
        self.unknownFile.hidden = NO;
    }
    
    return;
}

//automatically invoked when user clicks 'close'
// ->just close window
-(IBAction)closeButtonHandler:(id)sender
{
    //close
    [self.window close];
    
    return;
}

//automatically invoked when window is closing
// ->tell OS that we are done with window so it can (now) be freed
-(void)windowWillClose:(NSNotification *)notification
{
    //stop spinner
    // ->will hide too
    [self.progressIndicator stopAnimation:nil];
    
    return;
}

//automatically invoked when user clicks 'rescan'/'submit'
// ->rescan or upload to VT!
-(IBAction)vtButtonHandler:(id)sender
{
    //VT object
    VirusTotal* vtObj = nil;
    
    //result(s) from VT
    __block NSDictionary* result = nil;
    
    //analyis URL
    NSMutableAttributedString* hyperlinkString = nil;
    
    //VT scan ID
    __block NSString* scanID = nil;
    
    //alloc/init VT obj
    vtObj = [[VirusTotal alloc] init];
    
    //disable button
    ((NSButton*)sender).enabled = NO;
    
    //disable close button
    self.closeButton.enabled = NO;

    //get current string
    hyperlinkString = [self.analysisURL.attributedStringValue mutableCopy];
    
    //start editing
    [hyperlinkString beginEditing];
    
    //remove url/link
    [hyperlinkString removeAttribute:NSLinkAttributeName range:NSMakeRange(0, [hyperlinkString length])];
    
    //done editing
    [hyperlinkString endEditing];
    
    //set text
    // ->will look the same, but the URL will be disabled!
    [self.analysisURL setAttributedStringValue:hyperlinkString];
    
    //pre-req
    [self.overlayView setWantsLayer:YES];
    
    //set overlay's view color to black
    self.overlayView.layer.backgroundColor = [NSColor whiteColor].CGColor;

    //make it semi-transparent
    self.overlayView.alphaValue = 0.85;
    
    //show it
    self.overlayView.hidden = NO;
    
    //show spinner
    self.progressIndicator.hidden = NO;
    
    //animate it
    [self.progressIndicator startAnimation:nil];

    //rescan file?
    if(YES == [((NSButton*)sender).title isEqualToString:@"rescan?"])
    {
        //set status msg
        [self.statusMsg setStringValue:[NSString stringWithFormat:@"submitting re-scan request for %@", self.fileObj.name]];
            
        //show status msg
        self.statusMsg.hidden = NO;

        //submit rescan request in background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //make request to VT
            result = [vtObj reScan:self.fileObj];
            
            //got result
            // ->update UI and launch browswer to show report
            if(nil != result)
            {
                //grab scan ID
                // ->need this for (re)queries
                scanID = result[VT_RESULTS_SCANID];
                
                //if file was flagged
                // ->remove it from list of plugin's flagged
                if(0 != [self.fileObj.vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue])
                {
                    //sync
                    // ->since array will be reset if user clicks 'stop' scan
                    @synchronized(self.fileObj.plugin.flaggedItems)
                    {
                        //remove
                        [self.fileObj.plugin.flaggedItems removeObject:self.fileObj];
                    }
                }
                
                //remove file's VT info (since it'd now out of date)
                self.fileObj.vtInfo = nil;
                
                //with a scan id can re-query VT
                // ->will update VT button in UI once results are retrieved
                if(nil != scanID)
                {
                    //kick off task to re-query VT
                    // ->wait 60 seconds though to give VT servers some time to process
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [vtObj getInfoForItem:self.fileObj scanID:scanID];
                    });
                }
                
                //ask app delegate to update item in table
                // ->will change the item's VT status to ... (pending)
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]) itemProcessed:self.fileObj];
                
                //nap so user can see msg 'submitting' msg
                [NSThread sleepForTimeInterval:0.5];
                
                //update status msg
                dispatch_sync(dispatch_get_main_queue(), ^{

                    //update
                    [self.statusMsg setStringValue:@"request submitted"];
                    
                });
                    
                //nap so user can see msg
                [NSThread sleepForTimeInterval:0.5];
                
                //launch browser to show rew report
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:result[@"permalink"]]];
                
                //wait to browser is up and happy
                [NSThread sleepForTimeInterval:0.5];
                
                //close window
                dispatch_sync(dispatch_get_main_queue(), ^{

                    //close
                    [self.window close];
                    
                });
            }
            
            //error
            else
            {
                //show error msg
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    //update status msg
                    [self.statusMsg setStringValue:@"failed to submit request :("];
                    
                    //stop activity indicator
                    [self.progressIndicator stopAnimation:nil];

                });
            }
            
        });
    }
    
    //submit file
    else
    {
        //set status msg
        [self.statusMsg setStringValue:[NSString stringWithFormat:@"submitting %@", self.fileObj.name]];
            
        //show status msg
        self.statusMsg.hidden = NO;
        
        //submit rescan request in background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
            //submit file to VT
            result = [vtObj submit:self.fileObj];
            
            //got response
            // ->requery VT to get scan results
            if( (nil != result) &&
                (nil != result[VT_RESULTS_SCANID]) )
            {
                //reset file's VT info
                self.fileObj.vtInfo = nil;
            
                //kick off task to re-query VT
                // ->pass in scan result ID
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [vtObj getInfoForItem:self.fileObj scanID:result[VT_RESULTS_SCANID]];
                });
            
                //ask app delegate to update item in table
                // ->will change the item's VT status to ... (pending)
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]) itemProcessed:self.fileObj];
                
                //update status msg
                dispatch_sync(dispatch_get_main_queue(), ^{
                    
                    //update
                    [self.statusMsg setStringValue:@"file submitted"];
                    
                });
                
                //nap so user can see msg
                [NSThread sleepForTimeInterval:0.5];
                
                //launch browser to show rew report
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:result[@"permalink"]]];
                
                //wait to browser is up and happy
                [NSThread sleepForTimeInterval:0.5];
                
                //close window
                dispatch_sync(dispatch_get_main_queue(), ^{
                    
                    //close
                    [self.window close];
                    
                });
            
            }//got result
            
            //error
            else
            {
                //show error msg
                dispatch_sync(dispatch_get_main_queue(), ^{
                    
                    //update status msg
                    [self.statusMsg setStringValue:@"failed to submit request :("];
                    
                    //stop activity indicator
                    [self.progressIndicator stopAnimation:nil];
                    
                });
            }
            
        });
    }
    
//bail
bail:
    


    return;
}
@end
