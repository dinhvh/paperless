//
//  PLPageSizeInfo.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 25/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum {
    PLScannerPageSizeA4,
    PLScannerPageSizeLetter,
};

@interface PLPageSizeInfo : NSObject {
    NSString * _localizedName;
    NSString * _name;
    int _pageSizeId;
    NSSize _size;
}

@property (copy) NSString * localizedName;
@property (copy) NSString * name;
@property int pageSizeId;
@property NSSize size;

@end
