//
//  Diff.h
//  KnockKnock
//
//  Created by Patrick Wardle on 12/15/25.
//  Copyright © 2025 Objective-See. All rights reserved.
//

@import Foundation;

//compare two scans, return diff string
NSString* diffScans(NSDictionary* prevScan, NSDictionary* currentScan);
