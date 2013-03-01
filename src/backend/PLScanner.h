//
//  PLScanner.h
//  DocScan
//
//  Created by DINH Viêt Hoà on 6/9/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <Carbon/Carbon.h>
#import <TWAIN/TWAIN.h> 
#import "PLScannerProtocol.h"

@class PLScanner;

@interface PLScanner : NSObject <PLScannerProtocol> {
    int _scanType;
    int _pageSize;
    int _resolution;
    ICAObject _scannerObject;
    NSString * _scannerName;
    ICAScannerSessionID _sessionID;
    NSError * _error;
    NSSize _maxPageSize;
    int _maxResolution;
    NSMutableDictionary * _scannerParameters;
    NSString * _filename;
    BOOL _waitingOverview;
    
    id <PLScannerDelegate> _delegate;
}

- (id) initWithDictionary:(NSDictionary *)dict;
- (void) dealloc;

- (ICAObject) scannerObject;
- (NSString *) scannerName;

- (void) setScanType:(int)type;
- (void) setPageSizeFromName:(NSString *)pageSizeName;
- (void) setResolution:(int)resolution;
- (void) setDelegate:(id <PLScannerDelegate>)delegate;

- (int) resolution;
- (NSSize) pageSize;

- (NSError *) error;
- (NSString *) filename;

- (int) maxResolution;
- (NSSize) maxPageSize;

- (void) scan;
- (void) closeScannerSession;
- (void) unplug;

/* for PLScannerList */
- (void) privateGotOverview:(ICAObject)object;

@end
