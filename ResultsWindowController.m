//
//  ResultsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import "Utilities.h"
#import "AppDelegate.h"
#import "ResultsWindowController.h"

@implementation ResultsWindowController

@synthesize details;
@synthesize detailsLabel;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//initialize window
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
    
    //set details
    self.detailsLabel.stringValue = self.details;
    
    //set unknown items
    self.vtDetailsLabel.stringValue = self.vtDetails;
    
    //toggle 'Submit' button
    self.submitToVT.hidden = !(self.unknownItems.count);
    
    //make 'close' button active
    [self.window makeFirstResponder:self.closeButton];
    
    return;
}

//callback into app delegate to submit
-(IBAction)submitToVT:(id)sender
{
    //disable submit
    self.submitToVT.enabled = NO;
    
    //disable close
    self.closeButton.enabled = NO;
    
    //start spinner
    [self.submissionActivityIndicator startAnimation:nil];
    
    //set message
    self.submissionStatus.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Submitting %lu item(s) to VirusTotal...", @"Submitting %lu item(s) to VirusTotal..."), self.unknownItems.count];
    
    //show it
    self.submissionStatus.hidden = NO;
    
    //submit in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //nap for UI messages
        sleep(1);
        
        //submit
        [self submit];
        
    });
    
    return;
}

//update UI now that submission is done
-(void)submissionComplete:(NSUInteger)successes httpResponses:(NSMutableArray*)httpResponses
{
    //enable close
    self.closeButton.enabled = YES;
    
    //stop spinner
    [self.submissionActivityIndicator stopAnimation:nil];
    
    //success
    if(successes == self.unknownItems.count)
    {
        //update message
        self.submissionStatus.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Submissions complete. (In subsequent scans item's VT detection ratios will now be displayed).", @"Submissions complete. (In subsequent scans item's VT detection ratios will now be displayed).")];
    }
    else
    {
        //update message
        self.submissionStatus.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Submissions complete, though errors were encountered (HTTP response: %@).", @"Submissions complete, though errors were encountered (HTTP responses: %@)."), httpResponses];
    }
    
    return;
}

//submit unknown items to VT
// note: runs in background!
-(void)submit
{
    //VT object
    VirusTotal* vtObj = nil;
    
    //result (from VT)
    NSDictionary* result = nil;
    
    //error code(s)
    NSMutableArray* httpResponses = nil;
    
    //scan ids
    NSMutableDictionary* scanIDs = nil;
    
    //successful scans
    NSUInteger successes = 0;
    
    //alloc/init VT obj
    vtObj = [[VirusTotal alloc] init];
    
    //alloc
    scanIDs = [NSMutableDictionary dictionary];
    
    //alloc
    httpResponses = [NSMutableArray array];
    
    //submit all unknown items
    for(ItemBase* item in self.unknownItems)
    {
        //scan id from VT
        NSString* scanID = nil;
        
        //skip non-file items
        if(YES != [item isKindOfClass:[File class]])
        {
            //skip
            continue;
        }
        
        //skip item's without hashes
        // ...not sure how this could ever happen
        if(nil == ((File*)item).hashes[KEY_HASH_SHA1])
        {
            //skip
            continue;
        }
        
        //submit file to VT
        result = [vtObj submit:(File*)item];
        
        //save non-200 HTTP OK codes
        if(200 != (long)[(NSHTTPURLResponse *)result[VT_HTTP_RESPONSE] statusCode])
        {
            //add
            [httpResponses addObject:[NSNumber numberWithUnsignedLong:[(NSHTTPURLResponse *)result[VT_HTTP_RESPONSE] statusCode]]];
        }
        
        //extract scan id
        scanID = result[VT_RESULTS_SCANID];
        if(nil == scanID)
        {
            //err msg
            NSLog(@"KNOCKKNOCK ERROR: failed to submit %@", item.path);
            
            //update UI
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //update
                self.submissionStatus.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Failed to submit '%@'", @"Failed to submit '%@'"), ((File*)item).name];
            });
            
            //nap (for UI)
            sleep(1);
            
            continue;
        }
        
        //reset file's VT info
        // as we've just submittted
        ((File*)item).vtInfo = nil;
        
        //update UI
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //set item's VT status in UI to pending (...)
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) itemProcessed:(File*)item];
        
        });
        
        //save
        scanIDs[scanID] = item;
    }
    
    //only continue if there were submissions
    if(0 != scanIDs.count)
    {
        //nap for VT to process
        sleep(5);
        
        //update UI
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //update
            self.submissionStatus.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Awaiting results...", @"Awaiting results...")];
        });
        
        //nap more VT to process
        sleep(5);
        
        //get VT results
        for(NSString* scanID in scanIDs.allKeys)
        {
            //get results for item
            // waits until recieved (and updates UI on success)
            if(YES != [vtObj getInfoForItem:(File*)scanIDs[scanID] scanID:scanID])
            {
                //update UI
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    //update
                    self.submissionStatus.stringValue = [NSString stringWithFormat:@"Failed to get results for '%@'", ((File*)scanIDs[scanID]).name];
                });
                
                //nap for UI
                sleep(1);
                
                continue;
            }
            
            //happy
            // results will show up in UI
            successes++;
        }
    }
    
    //tell UI all is done
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //complete
        [self submissionComplete:successes httpResponses:httpResponses];
        
    });
    
    return;

}

//automatically invoked when user clicks 'OK'
// ->close window
-(IBAction)close:(id)sender
{
    //close
    [[self window] close];
        
    return;
}

//automatically invoked when window is closing
// ->make ourselves unmodal
-(void)windowWillClose:(NSNotification *)notification
{
    //make un-modal
    [[NSApplication sharedApplication] stopModal];
    
    return;
}

@end
