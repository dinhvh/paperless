//
//  PLPDFPageGeneration.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 3/23/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLPDFPageGeneration.h"

#import <Quartz/Quartz.h>
#import <ApplicationServices/ApplicationServices.h>

@interface PLPDFPageGeneration (Private)

- (void) privatePutBytes:(const void *)buffer count:(size_t)count;

@end

@implementation PLPDFPageGeneration

static size_t consumerPutBytesCallback(void * info, const void * buffer, size_t count);
static void consumerReleaseInfoCallback(void *info);

struct CGDataConsumerCallbacks callbacks = {
	consumerPutBytesCallback,
	consumerReleaseInfoCallback,
};

static size_t consumerPutBytesCallback(void * info, const void * buffer, size_t count)
{
	PLPDFPageGeneration * pdf;
	
	pdf = info;
	[pdf privatePutBytes:buffer count:count];
	
	return count;
}

static void consumerReleaseInfoCallback(void *info)
{
	PLPDFPageGeneration * pdf;
	
	pdf = info;
	[pdf release];
}

- (id) init
{
	self = [super init];
	
	return self;
}

- (void) dealloc
{
	[_document release];
	[super dealloc];
}

- (void) createDocument
{
	CGContextRef pdfContext;
	CGDataConsumerRef dataConsumer;
    CGRect pageRect;
    
	[_document release];
	_document = nil;
	
	_data = [[NSMutableData alloc] init];
	
    [self retain]; // release in callbacks
	dataConsumer = CGDataConsumerCreate(self, &callbacks);
    pageRect = CGRectMake(0, 0, _size.width * 72, _size.height * 72);
	pdfContext = CGPDFContextCreate(dataConsumer, &pageRect, NULL);
    CGContextRelease(pdfContext);
    pdfContext = NULL;
	CGDataConsumerRelease(dataConsumer);
	dataConsumer = NULL;
	
	_document = [[PDFDocument alloc] initWithData:_data];
    [_data release];
    _data = nil;
}

- (void) setImage:(NSString *)filename
{
	CGContextRef pdfContext;
	CGDataConsumerRef dataConsumer;
    CGRect pageRect;
	NSURL * url;
    CGImageSourceRef source;
	NSMutableData * data;
    CGImageDestinationRef dest;
    CFDictionaryRef sourceProps;
    NSMutableDictionary * options;
    CGImageSourceRef compressedSource;
    CGImageRef image;
	
	[_document release];
	_document = nil;
	
	_data = [[NSMutableData alloc] init];
	
    [self retain]; // release in callbacks
	dataConsumer = CGDataConsumerCreate(self, &callbacks);
    pageRect = CGRectMake(0, 0, _size.width * 72, _size.height * 72);
	pdfContext = CGPDFContextCreate(dataConsumer, &pageRect, NULL);
	
    CGContextBeginPage(pdfContext, &pageRect);
    
    url = [[NSURL alloc] initFileURLWithPath:filename];
    source = CGImageSourceCreateWithURL((CFURLRef) url, NULL);
    
	data = [[NSMutableData alloc] init];
    
	dest = CGImageDestinationCreateWithData((CFMutableDataRef) data, kUTTypeJPEG, 1, NULL);
    
    sourceProps = CGImageSourceCopyProperties(source, nil);
    CGImageDestinationSetProperties(dest, sourceProps);
    CFRelease(sourceProps);
    sourceProps = NULL;
	
    options = [[NSMutableDictionary alloc] init];
    [options setObject:[NSNumber numberWithFloat:0.8] forKey:(NSString *) kCGImageDestinationLossyCompressionQuality];
    CGImageDestinationAddImageFromSource(dest, source, 0, (CFDictionaryRef) options);
    [options release];
    options = NULL;
	
    CGImageDestinationFinalize(dest);
    
    CFRelease(dest);
    dest = NULL;
	
    compressedSource = CGImageSourceCreateWithData((CFDataRef) data, NULL);
    image = CGImageSourceCreateImageAtIndex(compressedSource, 0, NULL);
    
    CGSize imageSize;
    imageSize.width = CGImageGetWidth(image);
    imageSize.height = CGImageGetHeight(image);
    CGFloat factorWidth = pageRect.size.width / imageSize.width;
    CGFloat factorHeight = pageRect.size.height / imageSize.height;
    CGFloat factor = MIN(factorWidth, factorHeight);
    imageSize.width *= factor;
    imageSize.height *= factor;
    
    CGRect imageRect;
    imageRect.origin = CGPointZero;
    imageRect.origin.y = pageRect.size.height - imageSize.height;
    imageRect.size = imageSize;
    //CGContextDrawImage(pdfContext, pageRect, image);
    CGContextDrawImage(pdfContext, imageRect, image);
    
    CFRelease(image);
	image = NULL;
    CFRelease(compressedSource);
	compressedSource = NULL;
    
	[data release];
	data = NULL;
	
    CFRelease(source);
    source = NULL;
	
	[url release];
	url = nil;
	
    CGContextEndPage(pdfContext);
	
    CGContextRelease(pdfContext);
    pdfContext = NULL;
	CGDataConsumerRelease(dataConsumer);
	dataConsumer = NULL;
	
	_document = [[PDFDocument alloc] initWithData:_data];
	
	[_data release];
	_data = nil;
}

- (void) privatePutBytes:(const void *)buffer count:(size_t)count
{
	[_data appendBytes:buffer length:count];
}

- (PDFDocument *) document
{
	return _document;
}

- (PDFPage *) page
{
	return [_document pageAtIndex:0];
}

- (void) setPageSize:(NSSize)size
{
    _size = size;
}

- (void) setResolution:(int)resolution
{
    _resolution = resolution;
}

@end
