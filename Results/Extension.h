//
//  Extension.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "ItemBase.h"
#import <Foundation/Foundation.h>

@interface Extension : ItemBase
{
    
}

//id
@property(nonatomic, retain)NSString* identifier;

//description
@property(nonatomic, retain)NSString* details;

//(host) browser
@property(nonatomic, retain)NSString* browser;


/* METHODS */


@end
