//
//  PLScannerList.h
//  DocScan
//
//  Created by DINH Viêt Hoà on 6/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <Carbon/Carbon.h>
#import <TWAIN/TWAIN.h> 

#define PLSCANNERLIST_UPDATED @"org.etpan.scannerList.updated"

@interface PLScannerList : NSObject {
    NSMutableArray * _scannerList;
    ICAObject _deviceList;
}

+ (PLScannerList *) defaultManager;
- (NSArray * /* PLScanner */) getScannerList;
- (void) closeAllSession;

@end
