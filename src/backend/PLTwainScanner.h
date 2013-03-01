//
//  PLTwainScanner.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 27/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PLScannerProtocol.h"

@class PLTwainSource;

@interface PLTwainScanner : NSObject <PLScannerProtocol> {
	PLTwainSource * _source;
    id <PLScannerDelegate> _delegate;
    NSSize _size;
    BOOL _opened;
    NSString * _filename;
}

@property (assign) id <PLScannerDelegate> delegate;

- (id) initWithTwainManagerSource:(PLTwainSource *)source;
- (void) dealloc;

- (NSString *) scannerName;

- (void) setResolution:(int)resolution;
//- (void) setDelegate:(id <PLScannerDelegate>)delegate;
- (void) setPageSizeFromName:(NSString *)pageSizeName;
- (NSSize) pageSize;

- (void) scan;
- (NSString *) filename;
- (NSError *) error;

@end
