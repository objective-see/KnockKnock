//
//  Consts.h
//  KnockKnock
//
//  Created by Patrick Wardle on 2/4/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#ifndef KK_Consts_h
#define KK_Consts_h

//not first run
#define NOT_FIRST_TIME @"notFirstTime"

//asked for full disk access
#define REQUESTED_FULL_DISK_ACCESS @"requestedFullDiskAccess"

//supported plugins
static NSString * const SUPPORTED_PLUGINS[] = {@"AuthorizationPlugins", @"BrowserExtensions", @"CronJobs", @"DirectoryServicesPlugins", @"EventRules", @"Extensions", @"Kexts", @"LaunchItems", @"DylibInserts", @"DylibProxies", @"LoginItems", @"LogInOutHooks", @"PeriodicScripts", @"QuicklookPlugins", @"SpotlightImporters", @"StartupScripts", @"SystemExtensions"};

//sentry crash reporting URL
#define SENTRY_DSN @"https://ba5d094e87014a529b25d90bae010b1c@sentry.io/1321683"

//button text, start scan
#define START_SCAN @"Start Scan"

//button text, stop scan
#define STOP_SCAN @"Stop Scan"

//status msg
#define SCAN_MSG_STARTED @"Scanning Started"

//status msg
#define SCAN_MSG_STOPPED @"Scan Stopped"

//status msg
#define SCAN_MSG_COMPLETE @"Scan Complete"

//prefs
// ->filter out OS/known
#define PREF_SHOW_TRUSTED_ITEMS @"showTrustedItems"

//prefs
// ->disable VT querires
#define PREF_DISABLE_VT_QUERIRES @"disableVTQueries"

//prefs
// ->save output
#define PREF_SAVE_OUTPUT @"saveOutput"

//prefs
// ->no updates
#define PREF_DISABLE_UPDATE_CHECK @"noUpdateCheck"

//disabled state
#define STATE_DISABLED 0

//enabled state
#define STATE_ENABLED 1

//success
#define STATUS_SUCCESS 0

//signers
enum Signer{None, Apple, AppStore, DevID, AdHoc};

//signature status
#define KEY_SIGNATURE_STATUS @"signatureStatus"

//signer
#define KEY_SIGNATURE_SIGNER @"signatureSigner"

//signing auths
#define KEY_SIGNATURE_AUTHORITIES @"signatureAuthorities"

//code signing id
#define KEY_SIGNATURE_IDENTIFIER @"signatureIdentifier"

//entitlements
#define KEY_SIGNATURE_ENTITLEMENTS @"signatureEntitlements"

//OS version yosemite
#define OS_MINOR_VERSION_YOSEMITE 10

//executable path
#define EXECUTABLE_PATH @"@executable_path"

//loader path
#define LOADER_PATH @"@loader_path"

//rpath
#define RUN_SEARCH_PATH @"@rpath"

//path to LSOF
#define LSOF @"/usr/sbin/lsof"

//hash key, SHA1
#define KEY_HASH_SHA1 @"sha1"

//hash key, MD5
#define KEY_HASH_MD5 @"md5"

//path to crontab
#define CRONTAB @"/usr/bin/crontab"

//cron file(s) directory
#define CRON_FILES_DIRECTORY @"/private/var/at/tabs"

//path to system profiler
#define SYSTEM_PROFILER @"/usr/sbin/system_profiler"

//path for pluginkit
#define PLUGIN_KIT @"/usr/bin/pluginkit"

//dyld_ key for launch items
#define LAUNCH_ITEM_DYLD_KEY @"EnvironmentVariables"

//dyld_ key for applications
#define APPLICATION_DYLD_KEY @"LSEnvironment"

//user name
#define USER_NAME @"userName"

//user (home) directory
#define USER_DIRECTORY @"userDirectory"

//menu

//tag for prefs menu item
#define PREF_MENU_ITEM_TAG 1

//main window

//space for File's button in item table (w/ VT info)
#define TABLE_BUTTONS_FILE 200

//space for Extension's button in item table
#define TABLE_BUTTONS_EXTENTION 120

//space for Command's button in item table
#define TABLE_BUTTONS_COMMANDS 75


//scan button
#define SCAN_BUTTON_TAG 1000

//pref button
#define PREF_BUTTON_TAG 1001

//pref button
#define SAVE_BUTTON_TAG 1002

//logo button
#define LOGO_BUTTON_TAG 1003

//category table


//id (tag) for detailed text in category table
#define TABLE_ROW_NAME_TAG 100

//id (tag) for detailed text in category table
#define TABLE_ROW_SUB_TEXT_TAG 101

//id (tag) for total's msg
#define TABLE_ROW_TOTAL_TAG 102


//item table

//id (tag) for signed icon
#define TABLE_ROW_SIGNATURE_ICON 100

//id (tag) for path
#define TABLE_ROW_PATH_LABEL 101

//id (tag) for plist
#define TABLE_ROW_PLIST_LABEL 102

//id (tag) for 'virus total' button
#define TABLE_ROW_VT_BUTTON 103

//id (tag) for 'info' button
#define TABLE_ROW_INFO_BUTTON 105

//id (tag) for 'show' button
#define TABLE_ROW_SHOW_BUTTON 107

//known kexts
#define WHITE_LISTED_KEXTS @"whitelistedKexts"

//known file hashes
#define WHITE_LISTED_FILES @"whitelistedFiles"

//known commands
#define WHITE_LISTED_COMMANDS @"whitelistedCommands"

//known extension hashes
#define WHITE_LISTED_EXTENSIONS @"whitelistedExtensions"

//scanner option key
// ->filter apple signed/known items
#define KEY_SCANNER_FILTER @"filterItems"

//plugin key
#define KEY_RESULT_PLUGIN @"plugin"

//name key
#define KEY_RESULT_NAME @"name"

//path key
#define KEY_RESULT_PATH @"path"

//plist key
#define KEY_RESULT_PLIST @"plist"

//command key
#define KEY_RESULT_COMMAND @"command"

//extension id key
#define KEY_EXTENSION_ID @"id"

//extension description key
#define KEY_EXTENSION_DETAILS @"details"

//extension (host) browser key
#define KEY_EXTENSION_BROWSER @"browser"

/* VIRUS TOTAL */

//query url
#define VT_QUERY_URL @"https://www.virustotal.com/partners/sysinternals/file-reports?apikey="

//requery url
#define VT_REQUERY_URL @"https://www.virustotal.com/vtapi/v2/file/report"

//rescan url
#define VT_RESCAN_URL @"https://www.virustotal.com/vtapi/v2/file/rescan"

//submit url
#define VT_SUBMIT_URL @"https://www.virustotal.com/vtapi/v2/file/scan"

//api key
#define VT_API_KEY @"233f22e200ca5822bd91103043ccac138b910db79f29af5616a9afe8b6f215ad"

//user agent
#define VT_USER_AGENT @"VirusTotal"

//query count
#define VT_MAX_QUERY_COUNT 25

//results
#define VT_RESULTS @"data"

//results response code
#define VT_RESULTS_RESPONSE @"response_code"

//result url
#define VT_RESULTS_URL @"permalink"

//result hash
#define VT_RESULT_HASH @"hash"

//results positives
#define VT_RESULTS_POSITIVES @"positives"

//results total
#define VT_RESULTS_TOTAL @"total"

//results scan id
#define VT_RESULTS_SCANID @"scan_id"

//output file
#define OUTPUT_FILE @"kkResults.txt"

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101

//patreon url
#define PATREON_URL @"https://www.patreon.com/bePatron?c=701171"

//product url
#define PRODUCT_URL @"https://objective-see.com/products/knockknock.html"

//product name
// ...for version check
#define PRODUCT_NAME @"KnockKnock"

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.com/products.json"

//update error
#define UPDATE_ERROR -1

//update no new version
#define UPDATE_NOTHING_NEW 0

//update new version
#define UPDATE_NEW_VERSION 1

#endif
