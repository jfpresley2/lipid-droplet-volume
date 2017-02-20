//
//  COMainWindow.m
//  CellOutline
//
//  Created by Presley Work on 13-04-12.
//  Copyright 2013 John Presley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "COMainWindow.h"
#import "CellView.h"


@implementation COMainWindow

@synthesize window;
@synthesize currentViewController;
@synthesize location;
@synthesize inputFileName;
@synthesize outputFileName;
@synthesize img;
@synthesize polygons;
@synthesize currentPoly;

//@synthesize mainImage;

- (void) loadWindow {
	[super loadWindow];
	currentViewController = [[CellView alloc] initWithWindowNibName: @"CellView"];
	//currentViewController.location = self.location;
	[self activateViewController:currentViewController];
	[self clearVars];
}


// view management methods
- (IBAction) viewSelectionDidChange:(id) sender {
	
	
}

- (void) activateViewController: (NSViewController*) controller {
   // remove current view
	[self.currentViewController.view removeFromSuperview];
	
   // set up new view controller
    [[self.window contentView] addSubview:controller.view];
}

- (IBAction) selectImage:(id) sender {
	NSString* filename, *extension, *preExtension, *outputName;
	NSOpenPanel* openDlg = [NSOpenPanel openPanel];
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:YES];
	[openDlg setPrompt:@"Choose Image"];
	if ([openDlg runModal] == NSOKButton ) {
	    NSArray* files = [openDlg URLs];    
		filename = [[files objectAtIndex:0] absoluteString];
		[inputFileName setStringValue:filename];
		preExtension = [filename stringByDeletingPathExtension];
		extension = [filename pathExtension];
		// **** below is hardwired -- must dissect path properly
		// **** but it works now on Snow Leopard (and probably nowhere else)
		filename = [filename substringFromIndex:16];
		outputName = [preExtension stringByAppendingPathExtension:@"poly"];
		[outputFileName setStringValue:outputName];
		[img loadImage:filename];
		///****replace*****[img initWithContentsOfFile:filename];
		//[inputFileName setStringValue:filename];  -- set image name using this as prototype, then delete

	}
	
}
/*
- (IBAction) selectFile:(id)sender {
	NSString* filename, *preExtension, *extension, *outputName;
	NSOpenPanel* openDlg = [NSOpenPanel openPanel];
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:YES];
	[openDlg setPrompt:@"Choose Incorrect Input File"];
	if ([openDlg runModal] == NSOKButton ) {
	    NSArray* files = [openDlg URLs];    
		//NSArray* files = [openDlg filenames];
		filename = [[files objectAtIndex:0] absoluteString];
		[inputFileName setStringValue:filename];
		preExtension = [filename stringByDeletingPathExtension];
		NSLog(@"Path without extension is %@", preExtension);
		extension    = [filename pathExtension];
		outputName = [preExtension stringByAppendingPathExtension:@"poly"];
		NSLog(@"Output name is %@", outputName);
		[outputFileName setStringValue:outputName];
	}
}
 */

- (IBAction) addPolygon:(id) sender {
	[img storeCurrentPolygon];
}

//- (BOOL) isFlipped {
//	return YES;
//}

- (IBAction)eraseCurrentPolygon:(id) sender {
	[img deleteCurrentPolygon];
}

- (NSString*) polygonAsString:(NSArray*) poly cellNum:(int) counter {
	NSMutableString* outstr = [NSMutableString stringWithCapacity:0];
	[outstr setString:@""];
	CGPoint pt;
	int x, y;
	NSString* s;
	for (NSValue* p in poly) {
		pt = [p pointValue];
		x  = pt.x;
		y  = pt.y;
		s  = [NSString stringWithFormat:@"cell%i %i %i\n", counter, x, y];
		[outstr appendString:s];
	}
	return outstr;
}

- (NSString*) polygonListAsString:(NSArray*) ps {
    NSMutableString* outstr =[NSMutableString stringWithCapacity:0];
	[outstr setString:@""];
	int counter = 1;
	for (NSArray* p in ps) {
		NSString* polystr = [self polygonAsString:p cellNum:counter];
		[outstr appendString:polystr];
		counter += 1;
	}
	NSLog(@"@%", outstr);
	[outstr appendString:@"\n"];
	return outstr;
}

- (IBAction) finish:(id) sender {
	BOOL worked;
	NSData* polygonText;
	NSFileManager* fm = [NSFileManager defaultManager];
	polygons = [img polyList];
	currentPoly  = [img polygon];
	[polygons addObject:currentPoly];
	// *** now write out to output file the polygons
	NSURL* url = [NSURL URLWithString:[outputFileName stringValue]];
	NSString* path = [url path];
	// ***get rid of /localhost  *** do this right later
	// *** not testing yet if path exists or is long enough
	path = [path substringFromIndex:10];
	/* *** File may have to be manually truncated if it already exists!!!! ] */

    NSFileHandle *outfile = [NSFileHandle fileHandleForWritingAtPath:path];
	NSString* dat = [self polygonListAsString:polygons];
	polygonText   = [dat dataUsingEncoding:NSUTF8StringEncoding];
	polygonText   = [polygonText subdataWithRange:NSMakeRange(0, [polygonText length] - 1)];  // strip final \0 byte
	NSLog(@"Path=%@\n", path);
	NSLog(@"Text=%@\n", dat);
	//path = @"~/test.poly";
	worked = [fm createFileAtPath:path contents:polygonText attributes:nil];	
	if (! worked) {
		NSLog(@"File creation failed!!!\n");
	}
	[outfile writeData:polygonText];
	[outfile closeFile];
}


- (NSPoint) updateMouse {
	return [img lastPoint];
}

- (void) clearVars {
	currentPoly = [NSMutableArray array];
	polygons    = [NSMutableArray array];
}

@end
