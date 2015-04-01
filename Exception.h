//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.

#import <syslog.h>
#import <signal.h>


//install exception/signal handlers
void installExceptionHandlers();

//exception handler for Obj-C exceptions
void exceptionHandler(NSException *exception);

//signal handler for *nix style exceptions
void signalHandler(int signal, siginfo_t *info, void *context);

//display an alert
void showAlert();


