//
//  COMainWindow.h
//  CellOutline
//
//  Created by Presley Work on 13-04-12.
//  Copyright 2013 John Presley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "COImage.h"

@interface COMainWindow : NSWindowController {
    NSWindow* window;
	NSTextField* location;
	COMainWindow* cellImage;
    NSTextField* outputFileName;
	NSTextField* inputFileName;
	NSMutableArray* polygons;
	NSMutableArray* currentPoly;
	COImage* img;
	CGPoint p;
}
 
@property (assign) IBOutlet NSWindow* window;
@property (retain) NSViewController* currentViewController;
@property (retain) IBOutlet NSTextField *location;
@property (retain) IBOutlet NSTextField *outputFileName;      // *** new
@property (retain) IBOutlet NSTextField *inputFileName;   // *** new
@property (retain) NSMutableArray* polygons;
@property (retain) IBOutlet NSMutableArray* currentPoly;  // *** new
//***@property (retain) IBOutlet NSTextField *cropA;
//***@property (retain) IBOutlet NSTextField *cropB;
//***@property (retain) IBOutlet NSTextField *bleachA;
//***@property (retain) IBOutlet NSTextField *bleachB;
@property (retain) IBOutlet COImage* img;
//@property (retain) NSImage* mainImage;

// view management methods
- (IBAction) viewSelectionDidChange:(id) sender;
- (void) activateViewController: (NSViewController*) controller;
- (IBAction) addPolygon:(id) sender;
- (IBAction) eraseCurrentPolygon:(id) sender;
- (IBAction) finish:(id) sender;
//- (IBAction) selectFile:(id)sender;
- (IBAction) selectImage:(id)sender;
//*** - (IBAction) recordCropA:(id) sender;
//*** - (IBAction) recordCropB:(id) sender;
//*** - (IBAction) logCrops:(id) sender;
//*** - (IBAction) recordBleachA:(id) sender;
//*** - (IBAction) recordBleachB:(id) sender;
//*** - (IBAction) logBleaches:(id) sender;
//*** - (IBAction) nextLog:(id)sender;
- (void) clearVars;
- (NSPoint) updateMouse;
@end
