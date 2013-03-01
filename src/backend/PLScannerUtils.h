//
//  PLScannerUtils.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 24/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PLPageSizeInfo;

@interface PLScannerUtils : NSObject {
    NSMutableArray * _pageSizeTable;
}

+ (id) sharedManager;

- (id) init;
- (void) dealloc;

- (NSArray *) pageSizes;
- (PLPageSizeInfo *) pageSizeWithName:(NSString *)name;
- (PLPageSizeInfo *) pageSizeWithPageSizeId:(int)pageSizeId;
- (NSArray *) pageSizeLocalizedNames;

- (int) indexForPageSizeName:(NSString *)name;

@end
