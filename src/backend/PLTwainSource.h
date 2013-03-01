//
//  PLTwainSource.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 05/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "twain_client.h"

@class PLTwainManager;
@class PLTwainSource;

@protocol PLTwainSourceDelegate

- (void) plTwainSource:(PLTwainSource *)source imageFileData:(void *)data length:(size_t)length;

@end

@interface PLTwainSource : NSObject {
	struct twain_source * _source;
    NSString * _name;
    PLTwainManager * _manager;
    enum twain_pixel_type _pixelType;
    CGRect _layout;
    enum twain_xfer_mode _xferMode;
    unsigned int _depth;
    float _resolution;
    id <PLTwainSourceDelegate> _delegate;
}

@property (readonly, copy) NSString * name;
@property (assign) PLTwainManager * manager;
@property (assign) id <PLTwainSourceDelegate> delegate;

- (id) initWithTwainSource:(struct twain_source *)source;
- (void) dealloc;

- (void) open;
- (void) close;

- (void) setPixelType:(enum twain_pixel_type)pixelType;
- (void) setImageLayout:(CGRect)layout;
- (void) setXferMode:(enum twain_xfer_mode)xferMode;
- (void) setBitDepth:(unsigned int)depth;
- (void) setResolution:(unsigned int)resolution;

- (void) setup;

- (void) acquire;

- (struct twain_source *) source;

- (void) imageBeginWithImageInfo:(pTW_IMAGEINFO)imageInfo;
- (void) imageDataWithRow:(unsigned int)row data:(void *)data size:(size_t)size;
- (void) imageEnd;
- (void) imageFileData:(void *)data length:(size_t)length;

@end
