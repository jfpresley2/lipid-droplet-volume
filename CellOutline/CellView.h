//
//  CellView.h
//  CellOutline
//
//  Created by Presley Work on 13-05-17.
//  Copyright 2013 John F Presley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "COImage.h"

@interface CellView : NSViewController {
	COImage* mainImage;
	NSTextField* location;
}

@property (retain) COImage* mainImage;
@property (retain) IBOutlet NSTextField *location;

@end
