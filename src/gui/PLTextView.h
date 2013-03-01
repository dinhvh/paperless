//
//  PLTextView.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 18/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PLTextView : NSTextView {
	NSString * _placeholderString;
    BOOL _hasFocus;
}

@property (copy) NSString * placeholderString;

@end
