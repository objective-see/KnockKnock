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
@synthesize flaggedItems;
@synthesize unknownItems;


//init method
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc items array
        allItems = [NSMutableArray array];
        
        //alloc unknown items array
        unknownItems = [NSMutableArray array];
        
        //alloc flagged items array
        flaggedItems = [NSMutableArray array];
    }
    
    return self;
}

//reset plugin
// ->remove all items
-(void)reset
{
    //sync
    // ->VT threads might still be accessing
    @synchronized(self.allItems)
    {
        //remove all items
        [self.allItems removeAllObjects];
        
    }//sync
    
    //sync
    // ->VT threads might still be accessing
    @synchronized(self.unknownItems)
    {
        //remove unknown items
        [self.unknownItems removeAllObjects];
        
    }//sync
    
    //sync
    // ->VT threads might still be accessing
    @synchronized(self.flaggedItems)
    {
        //remove flagged items
        [self.flaggedItems removeAllObjects];
    }
    
    return;
}


//process and item
// save and report (if necessary)
-(void)processItem:(ItemBase*)item
{
    //exit if scanner (self) thread was cancelled
    // ->will prevent UI from updating after scan is cancelled
    if(YES == [[NSThread currentThread] isCancelled])
    {
        //exit
        [NSThread exit];
    }
    
    //sync
    // ->just to be safe
    @synchronized(self.allItems)
    {
        //save item into 'allItems'
        [self.allItems addObject:item];
    }
    
    //for unknown items
    // ->save seperately as well
    if(YES != item.isTrusted)
    {
        //sync
        // ->just to be safe
        @synchronized(self.unknownItems)
        {
            //save
            [self.unknownItems addObject:item];
        }
    }
    
    //invoke callback
    if(nil != self.callback)
    {
        //invoke
        self.callback(item);
    }
    
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
