//
//  COImage.h
//  CellOutline
//
//  Created by Presley Work on 13-05-18.
//  Copyright 2013 John F Presley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface COImage : NSView {

	NSImage* mainImage;
	NSTextField* location;
	float lastx;
	float lasty;
	NSMutableArray *polyList;
	NSMutableArray *polygon;
}

@property (retain) NSImage* mainImage;
@property (retain) IBOutlet NSTextField* location;
@property (assign) float lastx;
@property (assign) float lasty;
@property (retain) NSMutableArray *polyList;
@property (retain) NSMutableArray *polygon;

- (NSPoint) lastPoint;
- (void) storeCurrentPolygon;
- (void) deleteCurrentPolygon;
- (void) loadImage:(NSString*) path;

@end
