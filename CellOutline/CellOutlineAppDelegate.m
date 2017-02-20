//
//  CellOutlineAppDelegate.m
//  CellOutline
//
//  Created by Presley Work on 13-04-09.
//  Copyright 2013 John F Presley. All rights reserved.
//

#import "CellOutlineAppDelegate.h"
#import "COMainWindow.h"

@implementation CellOutlineAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	COMainWindow*  windowController;
	NSLog(@"CellOutline about to load window.");
    windowController = [[COMainWindow alloc] initWithWindowNibName:@"COMainWindow"];
	[windowController loadWindow];
	[windowController showWindow:self];
	NSLog(@"CellOutline Window Shown.");
	self.window = windowController;
}

@end
