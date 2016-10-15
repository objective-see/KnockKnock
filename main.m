//
//  main.m
//  KnockKnock
//
//  Created by Patrick Wardle
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
    //return var
    int retVar = -1;
    
    @autoreleasepool
    {
        //handle '-scan'
        // ->cmdline scan without UI
        if( (argc >= 2) &&
            (YES == [[NSString stringWithUTF8String:argv[1]] isEqualToString:@"-whothere"]) )
        {
            
        }
        
        //otherwise
        // ->just kick off app, as we're root now
        else
        {
            //app away
            retVar = NSApplicationMain(argc, (const char **)argv);
        }
            
    }//pool
        
    return retVar;
    
}
