//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.

#import "Consts.h"
#import "Exception.h"
#import "Utilities.h"


//install exception/signal handlers
void installExceptionHandlers()
{
    //sigaction struct
    struct sigaction sa = {0};
    
    //init struct
    sigemptyset (&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = signalHandler;
    
    //exception handler
    NSSetUncaughtExceptionHandler(&exceptionHandler);
    
    //install signal handlers
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS,  &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
    sigaction(SIGTRAP, &sa, NULL);
    sigaction(SIGFPE, &sa, NULL);
    
    return;
}

//display error alert
void showAlert()
{
    //response
    // ->index of button click
    NSModalResponse response = 0;
    
    //alert box
    NSAlert* fullScanAlert = nil;
    
    //alloc/init alert
    fullScanAlert = [NSAlert alertWithMessageText:@"ERROR: detected unrecoverable fault" defaultButton:@"Exit" alternateButton:@"Info" otherButton:nil informativeTextWithFormat:@"click 'Info' to help fix the issue!"];
    
    //and show it
    response = [fullScanAlert runModal];
    
    //handle case where user clicks 'Info'
    // ->take 'em to error page
    if(0 == response)
    {
        //open page in browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://objective-see.com/errors.html"]];
    }
    
    //kill app
    exit(0);
    
    return;
}



//exception handler
// will be invoked for Obj-C exceptions
void exceptionHandler(NSException *exception)
{
    //error msg
    NSString* errMsg = nil;
        
    //err msg
    syslog(LOG_ERR, "OBJECTIVE-SEE ERROR: OS version: %s /App version: %s", [[[NSProcessInfo processInfo] operatingSystemVersionString] UTF8String], [getAppVersion() UTF8String]);

    //create error msg
    errMsg = [NSString stringWithFormat:@"unhandled obj-c exception caught [name: %@ / reason: %@]", [exception name], [exception reason]];
    
	//err msg
	syslog(LOG_ERR, "OBJECTIVE-SEE ERROR: %s", [errMsg UTF8String]);
    
    //err msg
    syslog(LOG_ERR, "OBJECTIVE-SEE ERROR: %s", [[[NSThread callStackSymbols] description] UTF8String]);
    
    //main thread
    // ->just show UI alert
    if(YES == [NSThread isMainThread])
    {
        //show
        showAlert();
    }
    //back thread
    // ->have to show it on main thread
    else
    {
        //show alert
        // ->in main UI thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //show
            showAlert();
            
        });
    }
    
	return;
}

//handler for signals
// will be invoked for BSD/*nix signals
void signalHandler(int signal, siginfo_t *info, void *context)
{
    //error msg
    NSString* errMsg = nil;
    
    //context
    ucontext_t *uContext = NULL;
   
    //err msg
    syslog(LOG_ERR, "OBJECTIVE-SEE ERROR: OS version: %s /App version: %s", [[[NSProcessInfo processInfo] operatingSystemVersionString] UTF8String], [getAppVersion() UTF8String]);
    
    //typecast context
	uContext = (ucontext_t *)context;

    //create error msg
    errMsg = [NSString stringWithFormat:@"unhandled exception caught, si_signo: %d  /si_code: %s  /si_addr: %p /rip: %p",
              info->si_signo, (info->si_code == SEGV_MAPERR) ? "SEGV_MAPERR" : "SEGV_ACCERR", info->si_addr, (unsigned long*)uContext->uc_mcontext->__ss.__rip];
    
    //err msg
    syslog(LOG_ERR, "OBJECTIVE-SEE ERROR: %s", [errMsg UTF8String]);
    
    //err msg
    syslog(LOG_ERR, "OBJECTIVE-SEE ERROR: %s", [[[NSThread callStackSymbols] description] UTF8String]);
    
    //main thread
    // ->just show UI alert
    if(YES == [NSThread isMainThread])
    {
        //show
        showAlert();
    }
    //back thread
    // ->have to show it on main thread
    else
    {
        //show alert
        // ->in main UI thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //show
            showAlert();
            
        });
    }
    
	return;
}
