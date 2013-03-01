//
//  PLScannerUtils.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 24/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLScannerUtils.h"

#import "PLPageSizeInfo.h"

@implementation PLScannerUtils

static PLScannerUtils * singleton = nil;

+ (id) sharedManager
{
    @synchronized (self) {
        if (singleton == nil) {
            singleton = [[PLScannerUtils alloc] init];
        }
    }
    
    return singleton;
}

- (id) init
{
    PLPageSizeInfo * page;
    
    self = [super init];
    
    _pageSizeTable = [[NSMutableArray alloc] init];
    
    page = [[PLPageSizeInfo alloc] init];
    [page setLocalizedName:NSLocalizedStringFromTable(@"A4", @"Backend", @"paper size name")];
    [page setName:@"A4"];
    [page setPageSizeId:PLScannerPageSizeA4];
    [page setSize:NSMakeSize(8.3, 11.7)];
    
    [_pageSizeTable addObject:page];
    [page release];

    page = [[PLPageSizeInfo alloc] init];
    [page setLocalizedName:NSLocalizedStringFromTable(@"Letter", @"Backend", @"paper size name")];
    [page setName:@"Letter"];
    [page setPageSizeId:PLScannerPageSizeA4];
    [page setSize:NSMakeSize(8.5, 11.)];
    
    [_pageSizeTable addObject:page];
    [page release];
    
    return self;
}

- (void) dealloc
{
    [_pageSizeTable release];
    
    [super dealloc];
}

- (NSArray *) pageSizes
{
    return _pageSizeTable;
}

- (PLPageSizeInfo *) pageSizeWithName:(NSString *)name
{
    unsigned int i;
    
    for(i = 0 ; i < [_pageSizeTable count] ; i ++) {
        PLPageSizeInfo * pageSize;
        
        pageSize = [_pageSizeTable objectAtIndex:i];
        if ([[pageSize name] isEqualToString:name])
            return pageSize;
    }
    
    if ([_pageSizeTable count] > 0) {
        return [_pageSizeTable objectAtIndex:0];
    }
    
    return nil;
}

- (PLPageSizeInfo *) pageSizeWithPageSizeId:(int)pageSizeId
{
    unsigned int i;
    
    for(i = 0 ; i < [_pageSizeTable count] ; i ++) {
        PLPageSizeInfo * pageSize;
        
        pageSize = [_pageSizeTable objectAtIndex:i];
        if ([pageSize pageSizeId] == pageSizeId)
            return pageSize;
    }
    
    return nil;
}

- (NSArray *) pageSizeLocalizedNames
{
    NSMutableArray * result;
    unsigned int i;
    
    result = [NSMutableArray array];
    for(i = 0 ; i < [_pageSizeTable count] ; i ++) {
        PLPageSizeInfo * pageSize;
        
        pageSize = [_pageSizeTable objectAtIndex:i];
        [result addObject:[pageSize localizedName]];
    }
    
    return result;
}

- (int) indexForPageSizeName:(NSString *)name
{
    unsigned int i;
    
    for(i = 0 ; i < [_pageSizeTable count] ; i ++) {
        PLPageSizeInfo * pageSize;
        
        pageSize = [_pageSizeTable objectAtIndex:i];
        if ([[pageSize name] isEqualToString:name])
            return i;
    }
    
    return 0;
}

@end
