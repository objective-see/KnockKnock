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
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
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
        //reset
        textColor = NSColor.controlTextColor;
        
        //set color to red if its flagged
        if(0 != [self.fileObj.vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue])
        {
            //red
            textColor = [NSColor redColor];
        }
        
        //generate detection ratio
        vtDetectionRatio = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)[self.fileObj.vtInfo[VT_RESULTS_POSITIVES] unsignedIntegerValue], (unsigned long)[self.fileObj.vtInfo[VT_RESULTS_TOTAL] unsignedIntegerValue]];
        
        //set name
        self.fileName.stringValue = self.fileObj.name;
        
        //set color
        self.fileName.textColor = textColor;
        
        //detection ratio
        self.detectionRatio.stringValue = vtDetectionRatio;
        
        //set color
        self.detectionRatio.textColor = textColor;
        
        //analysis url
        self.analysisURL.stringValue = @"VirusTotal Report";
        
        //make analysis url a hyperlink
        makeTextViewHyperlink(self.analysisURL, [NSURL URLWithString:self.fileObj.vtInfo[VT_RESULTS_URL]]);
        
        //disable scan button
        self.submitButton.enabled = NO;
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

//invoked when user clicks 'submit'
// upload file to VT, open VT scan, etc...
-(IBAction)vtButtonHandler:(id)sender
{
    //VT object
    VirusTotal* vtObj = nil;
    
    //result(s) from VT
    __block NSDictionary* result = nil;
    
    //analyis URL
    NSMutableAttributedString* hyperlinkString = nil;
        
    //new report
    __block NSURL* newReport = nil;
    
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
    // will look the same, but the URL will be disabled!
    [self.analysisURL setAttributedStringValue:hyperlinkString];
    
    //pre-req
    [self.overlayView setWantsLayer:YES];
    
    //dark mode
    // set overlay to light
    if(YES == isDarkMode())
    {
        //set overlay's view color to gray
        self.overlayView.layer.backgroundColor = NSColor.lightGrayColor.CGColor;
    }
    //light mode
    // set overlay to gray
    else
    {
        //set to gray
        self.overlayView.layer.backgroundColor = NSColor.grayColor.CGColor;
    }
    
    //make it semi-transparent
    self.overlayView.alphaValue = 0.85;
    
    //show it
    self.overlayView.hidden = NO;
    
    //show spinner
    self.progressIndicator.hidden = NO;
    
    //animate it
    [self.progressIndicator startAnimation:nil];

    //set status msg
    self.statusMsg.stringValue = [NSString stringWithFormat:@"submitting %@", self.fileObj.name];
        
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
            
            //nap
            // allows msg to show up, and give VT some time
            [NSThread sleepForTimeInterval:2.0];
            
            //launch browser to show new report
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                //sanity check
                // then launch browser
                if( (nil != result[@"permalink"]) &&
                    (nil != (newReport = [NSURL URLWithString:result[@"permalink"]])) )
                {
                    //launch browser
                    [[NSWorkspace sharedWorkspace] openURL:newReport];
                }
                
            });

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
    

bail:
    
    return;
}
@end
