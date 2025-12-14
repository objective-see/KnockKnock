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
    
    NSArray* args = NSProcessInfo.processInfo.arguments;
    
    @autoreleasepool
    {
        //handle '-h' or '-help'
        if( (YES == [args containsObject:@"-h"]) ||
            (YES == [args containsObject:@"-help"]) )
        {
            //print usage
            usage(NO);
            
            //done
            goto bail;
        }
        
        //print version
        if(YES == [args containsObject:@"-version"])
        {
            //print usage
            version();
            
            //done
            goto bail;
        }
        
        
        //handle '-scan'
        // cmdline scan without UI
        if(YES == [args containsObject:@"-whosthere"])
        {
            //api key
            NSUInteger keyIndex = NSNotFound;
            
            //set flag
            cmdlineMode = YES;
            
            //set flag
            isVerbose = [args containsObject:@"-verbose"];
            
            //extract VT API key
            keyIndex = [args indexOfObject:@"-key"];
            if(keyIndex != NSNotFound)
            {
                //sanity check
                if(keyIndex + 1 < args.count)
                {
                    //grab
                    vtAPIKey = args[keyIndex + 1];
                }
                
                //validate
                if(vtAPIKey.length == 0)
                {
                    //usage
                    usage(YES);
                    
                    //done
                    goto bail;
                }
            }
            
            //need FDA
            if(!hasFDA())
            {
                //err msg
                fprintf(stderr,
                        "ERROR: KnockKnock (Terminal) requires Full Disk Access.\n"
                        "Please grant Full Disk Access to your Terminal app (or the app running KnockKnock), then restart KnockKnock and try again.\n\n");
             
                //done
                goto bail;
                
            }
                
            //scan
            cmdlineScan(args);
            
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

//version
void version(void) {
    NSDictionary* info = NSBundle.mainBundle.infoDictionary;
    NSString* version = info[@"CFBundleVersion"];
    if(version){
        printf("KnockKnock Version: %s\n", version.UTF8String);
    } else{
        printf("KnockKnock Version: unknown\n");
    }
    
    return;
}

//usage
void usage(BOOL error)
{
    FILE* output = error ? stderr : stdout;
    
    fprintf(output, "\nKNOCKNOCK USAGE:\n");
    fprintf(output, " -h or -help        Display this usage info\n");
    fprintf(output, " -whosthere         Perform command line scan\n");
    fprintf(output, " -version           Display current version of\n");
    fprintf(output, " -verbose           Display detailed output\n");
    fprintf(output, " -pretty            Final output is 'pretty-printed'\n");
    fprintf(output, " -apple             Include trusted platform items\n");
    fprintf(output, " -key <API key>     Your VirusTotal API key\n");
    fprintf(output, " -skipVT            Do not query VirusTotal with item hashes\n\n");
    
    return;
}

//perform a cmdline scan
void cmdlineScan(NSArray* args)
{
    //virus total obj
    VirusTotal* virusTotal = nil;
    
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
    
    //flag
    BOOL queryVT = NO;
    
    //displayed items
    // e.g. ignore apple/trusted if `-apple` not specified
    NSUInteger displayedItems = 0;
    
    //output
    NSMutableString* output = nil;
    
    //plugin object
    PluginBase* plugin = nil;
    
    //init
    startTime = [NSDate date];
    
    //init filter object
    itemFilter = [[Filter alloc] init];
    
    //alloc shared item enumerator
    sharedItemEnumerator = [[ItemEnumerator alloc] init];
    
    //start shared enumerator
    [sharedItemEnumerator start];
    
    //dbg msg
    if(isVerbose) {
        printf("Starting KnockKnock scan...\n");
        printf("\nOptions:\n");
    }

    //set flag
    // include apple items?
    includeApple = [args containsObject:@"-apple"];
    if(isVerbose) {
        printf("  Include platform items: %s\n", includeApple ? "YES" : "NO");
    }
    
    //set flag
    // skip virus total?
    skipVirusTotal = [args containsObject:@"-skipVT"];
    
    //set flag
    // pretty print json?
    prettyPrint = [args containsObject:@"-pretty"];
    if(isVerbose) {
        printf("  Pretty-print output: %s\n", prettyPrint ? "YES" : "NO");
    }
    
    //skip VT scanning if
    // user disabled queries, or no API key
    queryVT = (vtAPIKey.length) && !skipVirusTotal;
    if(isVerbose) {
        printf("  Query VirusTotal: %s\n", queryVT ? "YES" : "NO");
    }
    
    //init VT
    if(queryVT)
    {
        //init virus total object
        virusTotal = [[VirusTotal alloc] init];
    }
    
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
        if(isVerbose) {
            printf("\n%s\n now scanning...\n", plugin.name.uppercaseString.UTF8String);
        }
        
        //scan
        [plugin scan];
        
        //add up
        items += plugin.allItems.count;
        
        //add plugin's flagged items
        flaggedItems += plugin.flaggedItems.count;
        
        //dbg msg
        if(isVerbose) {
            
            //none found
            if(0 == (unsigned long)plugin.allItems.count)
            {
                //msg
                printf(" No %s found\n", plugin.name.UTF8String);
            }
            //found items
            else
            {
                //msg
                printf(" found %lu %s\n", (unsigned long)plugin.allItems.count, plugin.name.UTF8String);
                
                if(!includeApple)
                {
                    printf(" ...filtering out platform items\n");
                }
            }
        }
        
        //query VT?
        if(queryVT)
        {
            //dbg msg
            if(isVerbose) {
                printf(" querying VirusTotal...\n");
            }
            
            //check all plugin's files
            [virusTotal checkFiles:plugin apiKey:vtAPIKey uiMode:NO completion:NULL];
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
            
            //inc
            displayedItems++;
            
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
    if(isVerbose) {
        
        //compute duration
        NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:startTime];
        int minutes = (int)(timeInterval / 60);
        int seconds = (int)(timeInterval - (minutes * 60));
        
        //msg
        printf("\nScan completed in %02d minutes, %02d seconds\n\n", minutes, seconds);
        
        //if VT was include
        if(queryVT) {
            printf("RESULTS:\n %lu persistent items\n %lu (VT) flagged items\n\n", (unsigned long)displayedItems, (unsigned long)flaggedItems);
        }
        //no VT
        else {
            printf("RESULTS:\n %lu persistent items\n\n", (unsigned long)displayedItems);
            
        }
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
