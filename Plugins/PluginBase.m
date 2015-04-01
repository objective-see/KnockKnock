//
//  PluginBase.m
//  KnockKnock

#import "PluginBase.h"
#import "AppDelegate.h"

#define kErrFormat @"%@ not implemented in subclass %@"
#define kExceptName @"KK Plugin"



@implementation PluginBase

@synthesize icon;
@synthesize name;
@synthesize allItems;
@synthesize description;
@synthesize unknownItems;

//init method
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc item array
        allItems = [NSMutableArray array];
        
        //alloc unknown item array
        unknownItems = [NSMutableArray array];
    }
    
    return self;
}

//reset plugin
// ->remove all items
-(void)reset
{
    //remove all items
    [self.allItems removeAllObjects];
    
    //remove unknown items
    [self.unknownItems removeAllObjects];
}


//process and item
// ->save and report (if necessary)
-(void)processItem:(ItemBase*)item
{
    //exit if scanner (self) thread was cancelled
    // ->will prevent UI from updating after scan is cancelled
    if(YES == [[NSThread currentThread] isCancelled])
    {
        //exit
        [NSThread exit];
    }
    
    //save item into 'allItems'
    [self.allItems addObject:item];
    
    //for unknown items
    // ->save seperately as well
    if(YES != item.isTrusted)
    {
        //save
        [self.unknownItems addObject:item];
    }
    
    //report it to the UI
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) itemFound];
    
    return;
}


/* OPTIONAL METHODS */



/* REQUIRED METHODS */

//scan away!
-(void)scan
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return;
}

@end