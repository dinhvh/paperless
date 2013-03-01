/*
 *  PLScannerProtocol.h
 *  PaperLess2
 *
 *  Created by DINH Viêt Hoà on 24/10/2008.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

enum {
    PLScannerDocTypeBW,
    PLScannerDocTypeGrayScale,
    PLScannerDocTypeColor,
};

enum {
    PLScannerDocErrorSession,
    PLScannerDocErrorParameters,
    PLScannerDocErrorScan,
    PLScannerDocErrorDownload,
};

@protocol PLScannerProtocol;

@protocol PLScannerDelegate

- (void) plScanner_scanDone:(NSObject <PLScannerProtocol> *)scanner;

@end

@protocol PLScannerProtocol

- (NSString *) scannerName;

- (void) setResolution:(int)resolution;
- (void) setDelegate:(id <PLScannerDelegate>)delegate;
- (void) setPageSizeFromName:(NSString *)pageSizeName;
- (NSSize) pageSize;

- (void) scan;
- (NSString *) filename;
- (NSError *) error;

@end
