//
//  dumpBTM.h
//  library
//
//  Created by Patrick Wardle on 1/20/23.
//

@import Foundation;

//keys for dictionary
#define KEY_BTM_PATH @"path"
#define KEY_BTM_ERROR @"error"
#define KEY_BTM_VERSION @"version"
#define KEY_BTM_ITEMS_BY_USER_ID @"itemsByUserIdentifier"

//keys for item(s)
#define KEY_BTM_ITEM_UUID @"uuid"
#define KEY_BTM_ITEM_NAME @"name"
#define KEY_BTM_ITEM_DEV_NAME @"devName"
#define KEY_BTM_ITEM_TEAM_ID @"teamID"
#define KEY_BTM_ITEM_TYPE @"type"
#define KEY_BTM_ITEM_TYPE_DETAILS @"typeDetails"
#define KEY_BTM_ITEM_DISPOSITION @"disposition"
#define KEY_BTM_ITEM_DISPOSITION_DETAILS @"dispositionDetails"
#define KEY_BTM_ITEM_ID @"id"
#define KEY_BTM_ITEM_URL @"url"
#define KEY_BTM_ITEM_GENERATION @"generation"
#define KEY_BTM_ITEM_BUNDLE_ID @"bundleID"
#define KEY_BTM_ITEM_ASSOCIATED_IDS @"associatedBundleIDs"
#define KEY_BTM_ITEM_PARENT_ID @"parentID"
#define KEY_BTM_ITEM_EMBEDDED_IDS @"embeddedIDs"

#define KEY_BTM_ITEM_PLIST_PATH @"plistPath"
#define KEY_BTM_ITEM_EXE_PATH @"executablePath"

//APIs
// note: path is optional
NSInteger dumpBTM(NSURL* path);
NSDictionary* parseBTM(NSURL* path);
