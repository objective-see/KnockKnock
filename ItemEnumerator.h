//
//  ItemEnumerator.h
//  KnockKnock
//
//  Created by Patrick Wardle on 4/24/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ItemEnumerator : NSObject
{
    
}

/* iVars */

//'main' enumerator thread
@property(nonatomic, retain)NSThread* enumeratorThread;


//launch daemons and agents
@property(nonatomic, retain)NSMutableArray* launchItems;

//installed apps
@property(nonatomic, retain)NSMutableArray* applications;

//launch item enumerator thread
@property(nonatomic, retain)NSThread* launchItemsEnumerator;

//installed applications enumerator thread
@property(nonatomic, retain)NSThread* applicationsEnumerator;

/* METHODS */

//enumerate all 'shared' items
// ->that is to say, items that multiple plugins scan/process
-(void)start;

//cancel all enumerator threads
-(void)stop;

@end
