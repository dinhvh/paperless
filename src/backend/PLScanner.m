//
//  PLScanner.m
//  DocScan
//
//  Created by DINH Viêt Hoà on 6/9/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "PLScanner.h"

#import <Carbon/Carbon.h>
#import <TWAIN/TWAIN.h>
#import "PLScannerUtils.h"
#import "PLPageSizeInfo.h"

// TWAIN doesn't have this:
#define ICAP_FILMTYPE 2000
#define TWFT_POSITIVE 0
#define TWFT_NEGATIVE 1

@interface PLScanner (Private)

- (void) openSession;
- (void) openSessionDone;
- (void) getParameters;
- (void) getParametersDone;
- (void) overview;
- (void) overviewDone;
+ (int) registerCallback:(void *)data;
+ (void) unregisterCallback:(int)value;
- (void) fetchImage:(ICAObject)object;
- (void) fetchImageDone;
- (void) fetchImageAndOverviewDone;
- (void) scanDone;

@end

#if 0
struct pageInfo {
    NSString * localizedString;
    NSString * name;
    int pageSizeId;
    NSSize size;
};

static struct pageInfo pageSizeTable[] = {
    {NULL, @"A4", PLScannerPageSizeA4, {8.3, 11.7}},
    {NULL, @"Letter", PLScannerPageSizeLetter, {8.5, 11.}},
};
#endif

@implementation PLScanner

#if 0
+ (void) initialize
{
	pageSizeTable[0].localizedString = NSLocalizedStringFromTable(@"A4", @"Backend", @"paper size name");
	pageSizeTable[1].localizedString = NSLocalizedStringFromTable(@"Letter", @"Backend", @"paper size name");
}
#endif

/* set values */

- (void) set_oneValue:(id) value
               forKey:(NSString*)key
         userScanArea:(NSMutableDictionary*)userScanArea
{
    NSDictionary *	capDict;
    
    capDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                value,
                            @"value",
                            @"TWON_ONEVALUE",
                            @"type",
                            NULL];
    [userScanArea setObject:capDict
                     forKey:key];
}

- (void) set_ICAP_FilmType:(int)filmType
              userScanArea:(NSMutableDictionary*)userScanArea
{
    [self set_oneValue:[NSNumber numberWithInt: filmType]
                forKey:@"ICAP_FILMTYPE"
          userScanArea:userScanArea];
}

- (void) set_ICAP_PixelType:(int)pixelType
               userScanArea:(NSMutableDictionary*)userScanArea
{
    [self set_oneValue:[NSNumber numberWithInt: pixelType]
                forKey:@"ICAP_PIXELTYPE"
          userScanArea:userScanArea];
}

- (void) set_ICAP_BitDepth:(int)bitDepth
              userScanArea:(NSMutableDictionary*)userScanArea
{
    [self set_oneValue:[NSNumber numberWithInt: bitDepth]
                forKey:@"ICAP_BITDEPTH"
          userScanArea:userScanArea];
}

- (void) set_ICAP_LightPath:(int)lightPath
               userScanArea:(NSMutableDictionary*)userScanArea
{
    [self set_oneValue:[NSNumber numberWithInt: lightPath]
                forKey:@"ICAP_LIGHTPATH"
          userScanArea:userScanArea];
}

- (void) set_ICAP_xResolution:(float)res
                 userScanArea:(NSMutableDictionary*)userScanArea
{
    [self set_oneValue:[NSNumber numberWithFloat: res]
                forKey:@"ICAP_XRESOLUTION"
          userScanArea:userScanArea];
}

- (void) set_ICAP_yResolution:(float)res
                 userScanArea:(NSMutableDictionary*)userScanArea
{
    [self set_oneValue:[NSNumber numberWithFloat: res]
                forKey:@"ICAP_YRESOLUTION"
          userScanArea:userScanArea];
}

- (void) set_ICAP_PlanarChunky:(int)planarChuncky
                  userScanArea:(NSMutableDictionary*)userScanArea
{
    [self set_oneValue:[NSNumber numberWithInt: planarChuncky]
                forKey:@"ICAP_PLANARCHUNKY"
          userScanArea:userScanArea];
}

- (void) set_ICAP_Scaling:(float)scaling
             userScanArea:(NSMutableDictionary*)userScanArea
{
    [self set_oneValue:[NSNumber numberWithFloat: scaling]
                forKey:@"ICAP_XSCALING"
          userScanArea:userScanArea];
    [self set_oneValue:[NSNumber numberWithFloat: scaling]
                forKey:@"ICAP_YSCALING"
          userScanArea:userScanArea];
}

- (float) get_floatICAP:(NSString*)iCAP
            dictionary:(NSDictionary*)dict
{
    NSDictionary * cap;
    NSString * type;
    float value = 0.;
    
    cap = [dict objectForKey:iCAP];
    if (cap) {
        type = [cap objectForKey: @"type"];
        if ([type isEqualToString: @"TWON_ONEVALUE"])
            value = [[cap objectForKey: @"value"] floatValue];
    }
    return value;
}

- (int) get_intICAP:(NSString*)iCAP
         dictionary:(NSDictionary*)dict
{
    NSDictionary*  	cap;
    NSString * 		type;
    int value = 0;

    cap = [dict objectForKey:iCAP];
    if (cap) {
        type = [cap objectForKey: @"type"];
        if ([type isEqualToString: @"TWON_ONEVALUE"])
            value = [[cap objectForKey: @"value"] intValue];
    }
    return value;
}

/* init */

- (id) initWithDictionary:(NSDictionary *)dict
{
    ICAObject scannerObject;
    
    self = [super init];
    
    scannerObject = (ICAObject) [[dict objectForKey: @"icao"] unsignedLongValue];
    _scannerObject = scannerObject;
    _scannerName = [[dict objectForKey:@"ifil"] copy];
    _sessionID = 0;
    _scanType =  PLScannerDocTypeColor;
    _pageSize = PLScannerPageSizeA4;
    _resolution = 300;
    _waitingOverview = NO;
    
    return self;
}

- (void) dealloc
{
    [self unplug];
    
    [_scannerParameters release];
    [_scannerName release];
    [_filename release];
    [_error release];
    [super dealloc];
}

/* parameters */

- (ICAObject) scannerObject
{
    return _scannerObject;
}

- (NSString *) scannerName
{
    return _scannerName;
}

- (void) setScanType:(int)type
{
    _scanType = type;
}

- (void) setPageSizeFromName:(NSString *)pageSizeName
{
    PLPageSizeInfo * pageSize;
    
    pageSize = [[PLScannerUtils sharedManager] pageSizeWithName:pageSizeName];
    _pageSize = [pageSize pageSizeId];
}

- (void) setResolution:(int)resolution
{
    _resolution = resolution;
}

- (int) resolution
{
    return _resolution;
}

- (void) setDelegate:(id <PLScannerDelegate>)delegate
{
    _delegate = delegate;
}

- (int) maxResolution
{
    return _maxResolution;
}

- (NSSize) maxPageSize
{
    return _maxPageSize;
}

- (NSError *) error
{
    return [[_error retain] autorelease];
}

- (NSString *) filename
{
    return [[_filename retain] autorelease];
}

- (void) scanInit
{
    [_filename release];
    _filename = nil;
    [_error release];
    _error = nil;
}

- (void) scan
{
    [self retain];
    
    _waitingOverview = YES;
    
    [self scanInit];
    [self openSession];
}

/* scanner session */

- (void) openSession
{
	//NSLog(@"open session");
    if (_sessionID != 0) {
        [self openSessionDone];
        return;
    }
    
    [NSThread detachNewThreadSelector:@selector(openSessionInThread)
                             toTarget:self
                           withObject:nil];
}

- (void) openSessionInThread
{
    ICAScannerOpenSessionPB pb = {};
    OSErr err;
    NSAutoreleasePool * pool;
    
    pool = [[NSAutoreleasePool alloc] init];
	memset(&pb, 0, sizeof(pb));
    pb.object = _scannerObject;
	//NSLog(@"x1 %u", _scannerObject);
    err = ICAScannerOpenSession(&pb, NULL);
	//NSLog(@"x2");
    if (err == noErr) {
		//NSLog(@"%i", pb.sessionID);
        _sessionID = pb.sessionID;
		
		/*
		ICAScannerInitializePB initPb = {};
		memset(&initPb, 0, sizeof(initPb));
		initPb.sessionID = pb.sessionID;
		err = ICAScannerInitialize(&initPb, NULL);  
		NSLog(@"toto %i", err);
		*/
    }
    else {
        NSMutableDictionary * errorDict;
        
        errorDict = [[NSMutableDictionary alloc] init];
        [errorDict setObject:NSLocalizedStringFromTable(@"Could not establish connection with the scanner", @"Backend", @"error description") forKey:NSLocalizedDescriptionKey];
        [errorDict setObject:NSLocalizedStringFromTable(@"A session could not be opened to establish a connection with the scanner.", @"Backend", @"error failure reason") forKey:NSLocalizedFailureReasonErrorKey];
        [errorDict setObject:NSLocalizedStringFromTable(@"Check the connection of the scanner.", @"Backend", @"error recovery suggestion") forKey:NSLocalizedRecoverySuggestionErrorKey];
        _error = [[NSError errorWithDomain:@"PLScanner"
                                      code:PLScannerDocErrorSession
                                  userInfo:errorDict] retain];
        [errorDict release];
    }
	
	[self performSelectorOnMainThread:@selector(openSessionDone)
                           withObject:nil waitUntilDone:NO];
    
    [pool release];
}

- (void) closeSession
{
    ICAScannerCloseSessionPB pb = {};
    OSErr err;
	
    if (_sessionID == 0)
        return;
    
	//NSLog(@"close session");
	memset(&pb, 0, sizeof(pb));
    pb.sessionID = _sessionID;
    err = ICAScannerCloseSession(&pb, NULL);
	//NSLog(@"close session %i", err);
    _sessionID = 0;
}

- (void) openSessionDone
{
    if (_error != nil) {
		//NSLog(@"open session err");
        [self scanDone];
        return;
    }
    
	//NSLog(@"open session ok");
    [self getParameters];
}

- (void) getParameters
{
	//NSLog(@"get parameters");
    if (_scannerParameters != nil) {
        [self getParametersDone];
        return;
    }
    
    [NSThread detachNewThreadSelector:@selector(getParametersInThread)
                             toTarget:self
                           withObject:nil];
}

- (void) getParametersInThread
{
    ICAScannerGetParametersPB getPPB = {};
    OSErr err;
    NSAutoreleasePool * pool;
    
    pool = [[NSAutoreleasePool alloc] init];
    
	//NSLog(@"get parameters in thread");
    _scannerParameters = [[NSMutableDictionary alloc] init];
    
    getPPB.sessionID = _sessionID;
    getPPB.theDict   = (CFMutableDictionaryRef) _scannerParameters;
    err = ICAScannerGetParameters(&getPPB, NULL);
    
    if (noErr == err) {
        int maxXResolution;
        int maxYResolution;
        
    	//NSLog(@"%@", _scannerParameters);
        NSDictionary * device = [_scannerParameters objectForKey: @"device"];
        
        _maxPageSize.width  = [self get_floatICAP:@"ICAP_PHYSICALWIDTH"
                                       dictionary:device];
        _maxPageSize.width = [self get_floatICAP:@"ICAP_PHYSICALHEIGHT"
                                      dictionary:device];
        
        maxXResolution = [self get_intICAP:@"ICAP_XNATIVERESOLUTION"
                                 dictionary:device];
        maxYResolution = [self get_intICAP:@"ICAP_YNATIVERESOLUTION"
                                 dictionary:device];
        _maxResolution = maxXResolution;
        if (maxYResolution < _maxResolution)
            _maxResolution = maxYResolution;
        //NSLog(@"%@", device);
    }
    else {
        NSMutableDictionary * errorDict;
        
        errorDict = [[NSMutableDictionary alloc] init];
        [errorDict setObject:NSLocalizedStringFromTable(@"Information could not be retrieved from the scanner", @"Backend", @"error description") forKey:NSLocalizedDescriptionKey];
        [errorDict setObject:NSLocalizedStringFromTable(@"Parameters could not be retrieved from the scanner.", @"Backend", @"error failure reason") forKey:NSLocalizedFailureReasonErrorKey];
        [errorDict setObject:NSLocalizedStringFromTable(@"Check the connection of the scanner.", @"Backend", @"error recovery suggestion") forKey:NSLocalizedRecoverySuggestionErrorKey];
        _error = [[NSError errorWithDomain:@"PLScanner"
                                      code:PLScannerDocErrorParameters
                                  userInfo:errorDict] retain];
        [errorDict release];
    }
    
    [self performSelectorOnMainThread:@selector(getParametersDone)
                           withObject:nil waitUntilDone:NO];
    
    [pool release];
}

- (void) getParametersDone
{
	//NSLog(@"get parameters done");
    [self overview];
}

- (NSSize) getSizeFromPageSize:(int)pageSizeId
{
    PLPageSizeInfo * pageSize;
    
    pageSize = [[PLScannerUtils sharedManager] pageSizeWithPageSizeId:pageSizeId];
    
    return [pageSize size];
}

static void overviewDoneCallback(ICAHeader* pb);

- (void) overview
{
	//NSLog(@"overview");
    [NSThread detachNewThreadSelector:@selector(overviewInThread)
                             toTarget:self
                           withObject:nil];
}

- (void) overviewInThread
{
    OSErr err;
    ICAScannerSetParametersPB pbSetParam;
    NSMutableDictionary * dict;
    NSMutableDictionary * userScanArea;
    NSSize size;
    NSAutoreleasePool * pool;
    
    pool = [[NSAutoreleasePool alloc] init];
    
    userScanArea = [[[NSMutableDictionary alloc] init] autorelease];
    
	//NSLog(@"overview in thread");
    switch (_scanType) {
    case PLScannerDocTypeBW:
        [self set_ICAP_PixelType:TWPT_BW
                    userScanArea: userScanArea];
        [self set_ICAP_BitDepth:1
                   userScanArea:userScanArea];
        break;
    case PLScannerDocTypeGrayScale:
        [self set_ICAP_PixelType:TWPT_GRAY
                    userScanArea:userScanArea];
        [self set_ICAP_BitDepth:8
                   userScanArea:userScanArea];
        break;
    case PLScannerDocTypeColor:
    default:
        [self set_ICAP_PixelType:TWPT_RGB
                    userScanArea:userScanArea];
        [self set_ICAP_BitDepth:8
                   userScanArea:userScanArea];
        break;
    }
    [self set_ICAP_LightPath:0
                userScanArea:userScanArea];
    [self set_ICAP_xResolution:_resolution
                  userScanArea:userScanArea];
    [self set_ICAP_yResolution:_resolution
                  userScanArea:userScanArea];
    [self set_ICAP_PlanarChunky:TWPC_CHUNKY
                   userScanArea:userScanArea];
    [self set_ICAP_Scaling:1.0
              userScanArea:userScanArea];
    [self set_ICAP_FilmType:TWFT_POSITIVE
               userScanArea:userScanArea];
    
    [userScanArea setObject: [NSNumber numberWithFloat: 0]
                     forKey: @"offsetX"];
    [userScanArea setObject: [NSNumber numberWithFloat: 0]
                     forKey: @"offsetY"];
    
    size = [self getSizeFromPageSize:_pageSize];
    [userScanArea setObject: [NSNumber numberWithFloat: size.width]
                     forKey: @"width"];
    [userScanArea setObject: [NSNumber numberWithFloat: size.height]
                     forKey: @"height"];
    
    NSAssert(_scannerParameters != nil, @"scanner parameters not initialized");
    dict = [[_scannerParameters mutableCopy] autorelease];
    [dict setObject: [NSArray arrayWithObject: userScanArea]
             forKey: @"userScanArea"];
    
    //NSLog(@"parameters : %@", dict);
    
    memset(&pbSetParam, 0, sizeof(ICAScannerSetParametersPB));
    pbSetParam.sessionID = _sessionID;
    pbSetParam.theDict   = (CFMutableDictionaryRef)dict;
    //NSLog(@"%@", dict);
	
	static done_once = 0;
	if (!done_once) {
		done_once = 0;
		err = ICAScannerSetParameters(&pbSetParam, NULL);
	}
	else {
		err = noErr;
	}
	
    if (noErr == err) {
        ICAScannerStartPB startPB = {};
        int value;
        
		//NSLog(@"overview in thread 1");
        value = [[self class] registerCallback:self];
        
        // doing the overview scan
        startPB.header.refcon = value;
        startPB.sessionID = _sessionID;
        err = ICAScannerStart(&startPB, overviewDoneCallback);
		//NSLog(@"overview in thread 1.1");
        if (noErr != err) {
            NSMutableDictionary * errorDict;
            
            //NSLog(@"overview error");
            errorDict = [[NSMutableDictionary alloc] init];
            [errorDict setObject:NSLocalizedStringFromTable(@"Scanner could not be started", @"Backend", @"error description") forKey:NSLocalizedDescriptionKey];
            [errorDict setObject:NSLocalizedStringFromTable(@"Scanning operation could not be started.", @"Backend", @"error failure reason") forKey:NSLocalizedFailureReasonErrorKey];
            [errorDict setObject:NSLocalizedStringFromTable(@"Check the connection of the scanner.", @"Backend", @"error recovery suggestion") forKey:NSLocalizedRecoverySuggestionErrorKey];
            _error = [[NSError errorWithDomain:@"PLScanner"
                                          code:PLScannerDocErrorScan
                                      userInfo:errorDict] retain];
            [errorDict release];
            
            [self performSelectorOnMainThread:@selector(scanDone)
                                   withObject:nil waitUntilDone:NO];
        }
    }
    else {
        NSMutableDictionary * errorDict;
        
		//NSLog(@"overview in thread 2 %i", err);
        errorDict = [[NSMutableDictionary alloc] init];
        [errorDict setObject:NSLocalizedStringFromTable(@"Parameters of scan are invalid", @"Backend", @"error description") forKey:NSLocalizedDescriptionKey];
        [errorDict setObject:NSLocalizedStringFromTable(@"Parameters could not be set to the scanner.", @"Backend", @"error failure reason") forKey:NSLocalizedFailureReasonErrorKey];
        [errorDict setObject:NSLocalizedStringFromTable(@"Check the connection of the scanner.", @"Backend", @"error recovery suggestion") forKey:NSLocalizedRecoverySuggestionErrorKey];
        _error = [[NSError errorWithDomain:@"PLScanner"
                                      code:PLScannerDocErrorParameters
                                  userInfo:errorDict] retain];
        [errorDict release];
        
        [self performSelectorOnMainThread:@selector(scanDone)
                               withObject:nil waitUntilDone:NO];
    }
    
    [pool release];
}

#define CALLBACKTABLE_MAXSIZE 128
static unsigned int callbackTableCount = 0;
static void * callbackTable[CALLBACKTABLE_MAXSIZE];

+ (int) registerCallback:(void *)data
{
    unsigned int i;
    
    for(i = 0 ; i < callbackTableCount ; i ++) {
        if (callbackTable[i] == NULL) {
            callbackTable[i] = data;
            return i;
        }
    }
    
    if (callbackTableCount + 1 > CALLBACKTABLE_MAXSIZE)
        NSAssert(0, @"callback table exhausted");
    
    callbackTable[callbackTableCount] = data;
    callbackTableCount ++;
    
    return callbackTableCount - 1;
}

+ (void) unregisterCallback:(int)value
{
    callbackTable[value] = NULL;
}

static void overviewDoneCallback(ICAHeader* pb)
{
    /* pb is (ICAScannerStartPB *) */
    
    //NSLog(@"overview done err %u", pb->err);
    PLScanner * scanner = callbackTable[pb->refcon];
    [PLScanner unregisterCallback:pb->refcon];
    [scanner overviewDone];
}

- (void) overviewDone
{
    //NSLog(@"overview done");
}

- (void) privateGotOverview:(ICAObject)object
{
    //NSLog(@"got overview");
    [self fetchImage:object];
}

- (void) fetchImage:(ICAObject)object
{
	ICACopyObjectPropertyDictionaryPB infoPb = {};
	OSErr err;
	NSData * data;
	NSDictionary * info;
	NSNumber * nbFileSize;
	long fileSize;
	long remaining;
	NSString * tempDir;
	char tmpfilename[PATH_MAX];
	int fd;
	FILE * f;
	NSString * name;
	
	//NSLog(@"fetch image");
	infoPb.object = object;
	//infoPb.theDict = (CFDictionaryRef) [[NSMutableDictionary alloc] init];
	infoPb.theDict = (CFDictionaryRef *) &info;
    err = ICACopyObjectPropertyDictionary(&infoPb, NULL);
	//NSLog(@"%i", err);
	nbFileSize = [info objectForKey:@"isiz"];
	name = [[info objectForKey:@"ifil"] copy];
	fileSize = [nbFileSize longValue];
	//NSLog(@"%@", info);
	[info release];
	
	_filename = [[@"/tmp" stringByAppendingPathComponent:name] copy];
	[name release];
	
	[self fetchImageDone];
	return;
	
	remaining = fileSize;
    tempDir = NSTemporaryDirectory();
    snprintf(tmpfilename, sizeof(tmpfilename), "%s/paperless-XXXXXX", [tempDir fileSystemRepresentation]);
	fd = mkstemp(tmpfilename);
	f = fdopen(fd, "wb");
	
	while (remaining > 0) {
		long bufSize;
		ICACopyObjectDataPB pb = {};
	
		pb.object = object;
		pb.startByte = fileSize - remaining;
		bufSize = remaining;
		if (bufSize > 4 * 1024) {
			bufSize = 4 * 1024;
		}
		//NSLog(@"fetching %i %i", pb.startByte, bufSize);
		pb.requestedSize = bufSize;
		pb.data = (CFDataRef *) &data;
		err = ICACopyObjectData(&pb, NULL);
		//NSLog(@"%i", err);
		//NSLog(@"fetching %p", data);
		break;
		//NSLog(@"fetching %u", [data length]);
		fwrite([data bytes], [data length], 1, f);
		[data release];
		remaining -= bufSize;
	}
	fclose(f);
	
	_filename = [[[NSFileManager defaultManager] stringWithFileSystemRepresentation:tmpfilename length:strlen(tmpfilename)] copy];
	
	[self fetchImageDone];
}

- (void) fetchImageDone
{
	//NSLog(@"fetch image done");
    [self scanDone];
}


- (void) scanDone
{
    // don't close session
    _waitingOverview = NO;
    [_delegate plScanner_scanDone:self];
	//[self closeSession];

    [self release];
}

- (void) closeScannerSession
{
    [self closeSession];
}

- (NSSize) pageSize
{
    return [self getSizeFromPageSize:_pageSize];
}

- (void) unplug
{
    if (_waitingOverview) {
        NSMutableDictionary * errorDict;
        
        errorDict = [[NSMutableDictionary alloc] init];
        [errorDict setObject:NSLocalizedStringFromTable(@"Scanner unplugged", @"Backend", @"error description") forKey:NSLocalizedDescriptionKey];
        [errorDict setObject:NSLocalizedStringFromTable(@"Scanner has been unplugged while scanning.", @"Backend", @"error failure reason") forKey:NSLocalizedFailureReasonErrorKey];
        [errorDict setObject:NSLocalizedStringFromTable(@"Check the connection of the scanner.", @"Backend", @"error recovery suggestion") forKey:NSLocalizedRecoverySuggestionErrorKey];
        _error = [[NSError errorWithDomain:@"PLScanner"
                                      code:PLScannerDocErrorParameters
                                  userInfo:errorDict] retain];
        [errorDict release];
        
        [self scanDone];
    }
}

@end
