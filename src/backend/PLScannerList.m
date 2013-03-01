//
//  PLScannerList.m
//  DocScan
//
//  Created by DINH Viêt Hoà on 6/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "PLScannerList.h"

#import "PLScanner.h"
#import "PLUtils.h"

@interface PLScannerList (Private)

- (void)setupICASupport;
- (void) registerEventNotification;
- (void) ICANotificationCalled:(NSString *)notificationType info:(NSDictionary *)info;
- (void) updateScannerList:(ICAObject)object;
- (void) updateScannerList;

@end

@implementation PLScannerList

+ (PLScannerList *) defaultManager
{
    static PLScannerList * defaultPLScannerList = nil;
    
    if (defaultPLScannerList == nil) {
        defaultPLScannerList = [[PLScannerList alloc] init];
    }
    
    return defaultPLScannerList;
}

- (id) init
{
    self = [super init];
    
    _scannerList = [[NSMutableArray alloc] init];
    [self setupICASupport];
    [self updateScannerList];
    [self registerEventNotification];
    
    return self;
}

- (void) dealloc
{
    [_scannerList release];
    
    [super dealloc];
}

- (void)setupICASupport
{
    // get the devicelist
    ICAGetDeviceListPB  pb = {};
    OSErr				err;
    
    err = ICAGetDeviceList(&pb, NULL);
    
    if (err == noErr)
        _deviceList = pb.object;
}

static void ICAIgnore(ICAHeader* header);
//static void ICANotificationCallBack(ICAHeader * pb);
static void ICANotificationCallBack(CFStringRef notificationType, CFDictionaryRef notificationDictionary);


- (void) registerEventNotification
{
    OSErr err = noErr;
	ICARegisterForEventNotificationPB pb;
	
	NSMutableArray * eventList;
	
	eventList = [[NSMutableArray alloc] init];
	[eventList addObject:(NSString *) kICANotificationTypeObjectAdded];
	[eventList addObject:(NSString *) kICANotificationTypeObjectRemoved];
	[eventList addObject:(NSString *) kICANotificationTypeObjectInfoChanged];
	[eventList addObject:(NSString *) kICANotificationTypeStoreAdded];
	[eventList addObject:(NSString *) kICANotificationTypeStoreRemoved];
	[eventList addObject:(NSString *) kICANotificationTypeStoreFull];
	[eventList addObject:(NSString *) kICANotificationTypeStoreInfoChanged];
	[eventList addObject:(NSString *) kICANotificationTypeDeviceAdded];
	[eventList addObject:(NSString *) kICANotificationTypeDeviceRemoved];
	[eventList addObject:(NSString *) kICANotificationTypeDeviceInfoChanged];
	[eventList addObject:(NSString *) kICANotificationTypeDevicePropertyChanged];
	[eventList addObject:(NSString *) kICANotificationTypeDeviceWasReset];
	[eventList addObject:(NSString *) kICANotificationTypeCaptureComplete];
	[eventList addObject:(NSString *) kICANotificationTypeRequestObjectTransfer];
	[eventList addObject:(NSString *) kICANotificationTypeTransactionCanceled];
	[eventList addObject:(NSString *) kICANotificationTypeUnreportedStatus];
	[eventList addObject:(NSString *) kICANotificationTypeProprietary];
	[eventList addObject:(NSString *) kICANotificationTypeDeviceConnectionProgress];
	[eventList addObject:(NSString *) kICANotificationTypeDownloadProgressStatus];
	[eventList addObject:(NSString *) kICANotificationTypeScanProgressStatus];
	[eventList addObject:(NSString *) kICANotificationTypeScannerSessionClosed];
	[eventList addObject:(NSString *) kICANotificationTypeScannerScanDone];
	[eventList addObject:(NSString *) kICANotificationTypeScannerPageDone];
	[eventList addObject:(NSString *) kICANotificationTypeScannerButtonPressed];
	
	pb.header.refcon = 0;
	pb.objectOfInterest = 0;
	pb.eventsOfInterest = (CFArrayRef) eventList;
	pb.notificationProc = ICANotificationCallBack;
	pb.options = NULL;
	err = ICARegisterForEventNotification(&pb, NULL);
	
	[eventList release];
}

static void ICAIgnore(ICAHeader* header)
{
	//NSLog(@"ICAIgnore");
}

static void ICANotificationCallBack(CFStringRef notificationType, CFDictionaryRef notificationDictionary)
{
    PLScannerList * manager;
    
    manager = [PLScannerList defaultManager];
	//NSLog(@"%@", notificationType);
	
	[manager ICANotificationCalled:(NSString *) notificationType info:(NSDictionary *) notificationDictionary];
}

- (void) ICANotificationCalled:(NSString *)notificationType info:(NSDictionary *)info
{
	unsigned int i;
	NSNumber * nbDevice;

	if ([(NSString *) notificationType isEqualToString:(NSString *) kICANotificationTypeObjectAdded]) {
		nbDevice = [info objectForKey:(NSString *) kICANotificationDeviceICAObjectKey];
		for(i = 0 ; i < [_scannerList count] ; i ++) {
			PLScanner * scanner;
			
			scanner = [_scannerList objectAtIndex:i];
			if ([nbDevice intValue] == [scanner scannerObject]) {
                NSNumber * nbObject;
				
                nbObject = [info objectForKey:(NSString *) kICANotificationICAObjectKey];
				[scanner privateGotOverview:[nbObject intValue]];
			}
		}
	}
	else if (([(NSString *) notificationType isEqualToString:(NSString *) kICANotificationTypeDeviceAdded]) ||
			 ([(NSString *) notificationType isEqualToString:(NSString *) kICANotificationTypeDeviceRemoved])) {
        [self updateScannerList];
	}
}

- (void) updateScannerList
{
	ICACopyObjectPropertyDictionaryPB infoPb = {};
	OSErr err;
	NSDictionary * info;
	NSArray * list;
    NSMutableArray * oldDeviceList;
    unsigned int k;
	unsigned int i;
	
	//NSLog(@"update scanner");
	infoPb.object = _deviceList;
	//infoPb.theDict = (CFDictionaryRef) [[NSMutableDictionary alloc] init];
	infoPb.theDict = (CFDictionaryRef *) &info;
    err = ICACopyObjectPropertyDictionary(&infoPb, NULL);
	//NSLog(@"%i", err);
	if (err != noErr) {
		[_scannerList removeAllObjects];
		return;
	}
	
	//NSLog(@"%@", info);
	
    oldDeviceList = [_scannerList mutableCopy];
    [_scannerList removeAllObjects];

	list = [info objectForKey:@"devices"];
	for(i = 0 ; i < [list count] ; i ++) {
		NSDictionary * deviceDict;
		PLScanner * scanner;
		
		deviceDict = [list objectAtIndex:i];
	
		scanner = [[PLScanner alloc] initWithDictionary:deviceDict];
		
		PLScanner * found = nil;
		for(k = 0 ; k < [oldDeviceList count] ; k ++) {
			PLScanner * oldScanner;
			
			oldScanner = [oldDeviceList objectAtIndex:k];
			if ([scanner scannerObject] == [oldScanner scannerObject]) {
				found = oldScanner;
				break;
			}
		}
		if (found != nil)
			[_scannerList addObject:found];
		else
			[_scannerList addObject:scanner];
		[scanner closeScannerSession];
		[scanner release];
	}
	
    for(k = 0 ; k < [oldDeviceList count] ; k ++) {
        PLScanner * oldScanner;
        
        oldScanner = [oldDeviceList objectAtIndex:k];
        [oldScanner unplug];
    }
    
    [oldDeviceList release];
    //NSLog(@"scanner: %i", [_scannerList count]);
	
	[info release];
	
    POSTNOTIFICATION(PLSCANNERLIST_UPDATED, self, nil);
}

- (NSArray * /* PLScanner */) getScannerList
{
    return _scannerList;
}

- (void) closeAllSession
{
	unsigned int i;

	for(i = 0 ; i < [_scannerList count] ; i ++) {
		PLScanner * scanner;
	
		scanner = [_scannerList objectAtIndex:i];
		[scanner closeScannerSession];
	}
}

@end
