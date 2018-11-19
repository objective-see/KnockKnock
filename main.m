//
//  main.m
//  KnockKnock
//
//  Created by Patrick Wardle
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

@import Sentry;
#import "main.h"

int main(int argc, char *argv[])
{
    //status
    int status = -1;
    
    @autoreleasepool
    {
        //disable stderr
        // sentry dumps to this, and we want only JSON to output...
        disableSTDERR();
        
        //sentry client
        SentryClient *client = nil;
        
        //init sentry client
        client = [[SentryClient alloc] initWithDsn:@"https://ba5d094e87014a529b25d90bae010b1c@sentry.io/1321683" didFailWithError:nil];
        
        //set shared client
        SentryClient.sharedClient = client;
        
        //start crash handler
        [SentryClient.sharedClient startCrashHandlerWithError:nil];
        
        //handle '-scan'
        // cmdline scan without UI
        if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:@"-whosthere"])
        {
            //scan
            if(YES != cmdlineScan())
            {
                //err msg
                printf("\nKNOCKKNOCK ERROR: cmdline scan failed\n\n");
                
                //bail
                goto bail;
            }
            
            //happy
            status = 0;
            
            //done
            goto bail;
        }
        
        //otherwise
        // just kick off app for UI instance
        else
        {
            //app away
            status = NSApplicationMain(argc, (const char **)argv);
        }
            
    }//pool
    
bail:
    
    return status;
}

//perform a cmdline scan
BOOL cmdlineScan()
{
    //virus total obj
    VirusTotal* virusTotal = nil;
    
    //virus total thread
    NSThread* virusTotalThread = nil;
    
    //flag
    BOOL scanned = NO;
    
    //flag
    BOOL includeApple = NO;
    
    //flag
    BOOL skipVirusTotal = NO;
    
    //flag
    BOOL prettyPrint = NO;
    
    //output
    NSMutableString* output = nil;
    
    //plugin object
    PluginBase* plugin = nil;
    
    //init filter object
    itemFilter = [[Filter alloc] init];
    
    //init virus total object
    virusTotal = [[VirusTotal alloc] init];
   
    //alloc shared item enumerator
    sharedItemEnumerator = [[ItemEnumerator alloc] init];
    
    //start shared enumerator
    [sharedItemEnumerator start];
    
    //set flag
    // include apple items?
    includeApple = [[[NSProcessInfo processInfo] arguments] containsObject:@"-apple"];
    
    //set flag
    // skip virus total?
    skipVirusTotal = [[[NSProcessInfo processInfo] arguments] containsObject:@"-skipVT"];
    
    //set flag
    // pretty print json?
    prettyPrint = [[[NSProcessInfo processInfo] arguments] containsObject:@"-pretty"];
    
    //init output string
    output = [NSMutableString string];
    
    //start JSON
    [output appendString:@"{"];

    //iterate over all supported plugins
    // invoke scan method on each plugin...
    for(NSUInteger i=0; i < sizeof(SUPPORTED_PLUGINS)/sizeof(SUPPORTED_PLUGINS[0]); i++)
    {
        //init plugin
        plugin = [(PluginBase*)([NSClassFromString(SUPPORTED_PLUGINS[i]) alloc]) init];
        if(nil == plugin)
        {
            //skip
            continue;
        }
        
        //no callback needed
        plugin.callback = nil;
        
        //scan
        [plugin scan];
        
        //query VT
        // unless user explicity says otherwise
        if(YES != skipVirusTotal)
        {
            //alloc thread
            // will query virus total to get info about all detected items
            virusTotalThread = [[NSThread alloc] initWithTarget:virusTotal selector:@selector(getInfo:) object:plugin];
            
            //start thread
            [virusTotalThread start];
            
            //wait until thread is done
            while(YES != virusTotalThread.isFinished)
            {
                //nap
                [NSThread sleepForTimeInterval:1.0];
            }
        }
    
        //append plugin name to output
        [output appendString:[NSString stringWithFormat:@"\"%@\":[", plugin.name]];
        
        //iterate over all plugin items
        // convert to JSON/append to output
        for(ItemBase* item in plugin.allItems)
        {
            //skip apple / trusted items?
            if( (YES != includeApple) &&
                (YES == item.isTrusted) )
            {
                //skip
                continue;
            }
            
            //add item
            [output appendFormat:@"{%@},", [item toJSON]];
        }
        
        //remove last ','
        if(YES == [output hasSuffix:@","])
        {
            //remove
            [output deleteCharactersInRange:NSMakeRange([output length]-1, 1)];
        }
        
        //terminate list
        [output appendString:@"],"];
        
    }//all plugins
    
    //remove last ','
    if(YES == [output hasSuffix:@","])
    {
        //remove
        [output deleteCharactersInRange:NSMakeRange([output length]-1, 1)];
    }

    //terminate list
    [output appendString:@"}"];
    
    //pretty print?
    if(YES == prettyPrint)
    {
        //make me pretty!
        prettyPrintJSON(output);
    }
    else
    {
        //output
        printf("%s\n", output.UTF8String);
    }
    
    //happy
    scanned = YES;
    
bail:
    
    return scanned;
}

//pretty print JSON
void prettyPrintJSON(NSString* output)
{
    //data
    NSData* data = nil;
    
    //object
    id object = nil;
    
    //pretty data
    NSData* prettyData = nil;
    
    //pretty string
    NSString* prettyString = nil;
    
    //covert to data
    data = [output dataUsingEncoding:NSUTF8StringEncoding];
    
    //serialize
    object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    //covert to pretty data
    prettyData =  [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:nil];
    
    //covert to pretty string
    prettyString = [NSString stringWithUTF8String:prettyData.bytes];
    
    //output
    printf("%s\n", prettyString.UTF8String);

    return;
}
