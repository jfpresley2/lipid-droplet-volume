//
//  COImage.m
//  CellOutline
//
//  Created by Presley Work on 13-05-18.
//  Copyright 2013 John F Presley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "COImage.h"

#define RED 1
#define YELLOW 2

@implementation COImage

@synthesize mainImage;
@synthesize location;
@synthesize lastx;
@synthesize lasty;
@synthesize polygon;
@synthesize polyList;

- (BOOL) isFlipped {
    return NO;
}

- (void) loadImage:(NSString*) path {
	NSLog(@"Drawing path %@\n", path);
	mainImage = [NSImage alloc];
	[mainImage initByReferencingFile:path];	
	[self setFrameSize:[self.mainImage size]];    // **** new
	[self setNeedsDisplay:YES];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		lastx = 0.0;
		lasty = 0.0;
		polygon  = [NSMutableArray array];
		polyList = [NSMutableArray array];
		self.mainImage = [NSImage imageNamed:@"galt_noco_a_proj.jpg"];    
		[self setFrameSize:[self.mainImage size]];
	}
	else {
		NSLog(@"initWithFrame of CellView failed.");
	}
    return self;
	
}

- (void) extendPolygonList {
	[polyList addObject:polygon];
	polygon = [NSMutableArray array];
}

- (void) extendPolygon:(NSPoint) point {
	NSValue *v;
	v = [NSValue valueWithPoint:point];
    [polygon addObject:v];
	
}

- (void) drawPolygon:(NSMutableArray*) poly color:(int)color {
	CGPoint pt, firstPoint, lastPoint;
	if (color == RED) 
	    [[NSColor redColor] set];                // *** fix this later to use parameter -- may require checking documentation for NSColor
    else if (color == YELLOW) {
	    [[NSColor yellowColor] set];	
	}
	NSBezierPath* path = [NSBezierPath bezierPath];
	[path setLineWidth: 2.0];
	int start = 0;
	for (NSValue *p in poly) {
	   	pt = [p pointValue];
		if (!start) {
			start = 1;
			firstPoint = lastPoint = pt;
			[path moveToPoint: lastPoint];
		} else {
			// stroke from lastPoint
			pt = [p pointValue];
			[path lineToPoint:pt ];
			lastPoint = pt;
			[path moveToPoint: lastPoint];
		}
		[path stroke];
		[path closePath];
	}
	if (color == YELLOW) {
	   [path moveToPoint: lastPoint];
	   [path lineToPoint:firstPoint];
	   [path stroke];
	   [path closePath];
	}
}

- (void) drawPolygons  {
	for (NSMutableArray *p in polyList) {
	    [self drawPolygon: p color: YELLOW];	
	}
	[self drawPolygon: polygon color: RED];
}

- (void) drawRect:(NSRect) rect {
	NSRect bounds;
	NSBezierPath* path;
	path = [NSBezierPath bezierPath];
	NSPoint targ;
	targ.x = 0.0;
	targ.y = 0.0;
	// image sizes are variable from Zeiss 510
	// from Leica always 1390 x 1040 (only two image series)
	//bounds.origin.x    = 0;
	//bounds.origin.y    = 0;
	//bounds.size.width  = 776;
	//bounds.size.height = 776; 
	NSImage* image = self.mainImage;
	//[image setFlipped:YES];
	bounds.origin  = NSZeroPoint;
	bounds.size    = [image size];
	[image drawInRect: bounds
			 fromRect: NSZeroRect
			operation: NSCompositeSourceOver
			 fraction: 1.0];
	[path setLineWidth:2.0];
	[self drawPolygons];
	NSLog(@"Path printed.");
}

- (void) mouseDown:(NSEvent *)event {
	CGPoint p;
	NSString* locationCoordinates;
	NSLog(@"Mouse clicked.");
    NSPoint pointInWindow = event.locationInWindow;
	NSLog(@"point gotten.");
	//*****NSPoint pointInView   = [self convertPointFromBase:pointInWindow];
	NSPoint pointInView   = [self convertPoint:pointInWindow fromView:nil];
	NSLog(@"Point converted.");
	//NSPoint pointInView   = pointInWindow;
	
	if (event.clickCount > 1) {
		NSLog(@"Double click about to be recorded.");
		locationCoordinates = [NSString stringWithFormat:@"DoubleClick %f,%f", pointInView.x, pointInView.y];
		p.x = pointInView.x;
		p.y = pointInView.y;
		[self extendPolygon: p];
		[self extendPolygonList];
		NSLog(@"Double click was recorded.");
	}
	else {
		NSLog(@"Single click about to be recorded.");
	    locationCoordinates = [NSString stringWithFormat:@"OneClick %f, %f", pointInView.x, pointInView.y];
		p.x = pointInView.x;
		p.y = pointInView.y;
        [self extendPolygon: p];
		NSLog(@"Single click was recorded.");
    }
	NSLog(@"About to print location coordinates.");
	NSLog(@"Location coordinates=%@", locationCoordinates);
    location.stringValue    = locationCoordinates;
	[self setNeedsDisplay:YES];
	NSLog(@"Location pointer set successfully.");
}

- (void) storeCurrentPolygon {
	[polyList addObject:polygon];
	polygon = [NSMutableArray array];
}

- (void) deleteCurrentPolygon {
	polygon = [NSMutableArray array];
}

- (NSPoint) lastPoint {
	NSPoint p;
	p.x = lastx;
	p.y = lasty;
	return p;
}

- (NSMutableArray*) polygons {
	return polyList;	
}

- (BOOL) acceptsFirstResponder {
	return YES;	
}

- (BOOL) becomeFirstResponder {
	return YES;	
}

@end
