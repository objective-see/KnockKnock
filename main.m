//
//  main.m
//  KnockKnock
//
//  Created by Patrick Wardle
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "main.h"

int main(int argc, char *argv[])
{
    //status
    int status = -1;
    
    @autoreleasepool
    {
        //handle '-h' or '-help'
        if( (YES == [NSProcessInfo.processInfo.arguments containsObject:@"-h"]) ||
            (YES == [NSProcessInfo.processInfo.arguments containsObject:@"-help"]) )
        {
            //print usage
            usage();
            
            //done
            goto bail;
        }
        
        //handle '-scan'
        // cmdline scan without UI
        if(YES == [NSProcessInfo.processInfo.arguments containsObject:@"-whosthere"])
        {
            //set flag
            cmdlineMode = YES;
            
            //set flag
            isVerbose = [NSProcessInfo.processInfo.arguments containsObject:@"-verbose"];
            
            //scan
            cmdlineScan();
            
            //happy
            status = 0;
            
            //done
            goto bail;
        }
        
        //otherwise
        // just kick off app for UI instance
        else
        {
            //set flag
            cmdlineMode = NO;
            
            //make foreground so it has an dock icon, etc
            transformProcess(kProcessTransformToForegroundApplication);
            
            //app away
            status = NSApplicationMain(argc, (const char **)argv);
        }
            
    }//pool
    
bail:
    
    return status;
}

//print usage
void usage(void)
{
    //usage
    printf("\nKNOCKNOCK USAGE:\n");
    printf(" -h or -help  display this usage info\n");
    printf(" -whosthere   perform command line scan\n");
    printf(" -verbose     display detailed output\n");
    printf(" -pretty      final output is 'pretty-printed'\n");
    printf(" -apple       include apple/system items\n");
    printf(" -skipVT      do not query VirusTotal with item hashes\n\n");
    
    return;
}

//perform a cmdline scan
void cmdlineScan(void)
{
    //virus total obj
    VirusTotal* virusTotal = nil;
    
    //virus total thread
    NSThread* virusTotalThread = nil;
    
    //start time
    NSDate* startTime = nil;
    
    //total items
    NSUInteger items = 0;
    
    //flagged items
    NSUInteger flaggedItems = 0;
    
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
    
    //init
    startTime = [NSDate date];
    
    //init filter object
    itemFilter = [[Filter alloc] init];
    
    //init virus total object
    virusTotal = [[VirusTotal alloc] init];
   
    //alloc shared item enumerator
    sharedItemEnumerator = [[ItemEnumerator alloc] init];
    
    //start shared enumerator
    [sharedItemEnumerator start];
    
    //dbg msg
    if(YES == isVerbose)
    {
        //msg
        printf("starting scan...\n");
    }
    
    //set flag
    // include apple items?
    includeApple = [NSProcessInfo.processInfo.arguments containsObject:@"-apple"];
    
    //set flag
    // skip virus total?
    skipVirusTotal = [NSProcessInfo.processInfo.arguments containsObject:@"-skipVT"];
    
    //set flag
    // pretty print json?
    prettyPrint = [NSProcessInfo.processInfo.arguments containsObject:@"-pretty"];
    
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
        
        //dbg msg
        if(YES == isVerbose)
        {
            //msg
            printf("\n%s\n now scanning...\n", plugin.name.uppercaseString.UTF8String);
        }
        
        //scan
        [plugin scan];
        
        //add up
        items += plugin.allItems.count;
        
        //add plugin's flagged items
        flaggedItems += plugin.flaggedItems.count;
        
        //dbg msg
        if(YES == isVerbose)
        {
            //msg
            printf(" found %lu %s\n", (unsigned long)plugin.allItems.count, plugin.name.UTF8String);
        }
        
        //query VT
        // unless no items or user explicity says otherwise
        if( (YES != skipVirusTotal) &&
            (0 != plugin.allItems.count) )
        {
            //dbg msg
            if(YES == isVerbose)
            {
                //msg
                printf(" scanning via Virus Total\n");
            }
            
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
    
    //dbg msg
    if(YES == isVerbose)
    {
        //compute duration
        NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:startTime];
        int minutes = (int)(timeInterval / 60);
        int seconds = (int)(timeInterval - (minutes * 60));
        
        //msg
        printf("\nscan completed in %02d minutes, %02d seconds\n\n", minutes, seconds);
        printf("RESULTS:\n %lu persistent items\n %lu flagged items\n\n", (unsigned long)items, (unsigned long)flaggedItems);
    }
    
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
    
    return;
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
    
    //convert to JSON
    // wrap since we are serializing JSON
    @try
    {
        //serialize
        object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        //covert to pretty data
        prettyData =  [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:nil];
    }
    @catch(NSException *exception)
    {
        ;
    }
    
    //covert to pretty string
    if(nil != prettyData)
    {
        //convert to string
        prettyString = [[NSString alloc] initWithData:prettyData encoding:NSUTF8StringEncoding];
    }
    else
    {
        //error
        prettyString = @"{\"ERROR\" : \"failed to covert output to JSON\"}";
    }
    
    //output
    printf("%s\n", prettyString.UTF8String);

    return;
}
