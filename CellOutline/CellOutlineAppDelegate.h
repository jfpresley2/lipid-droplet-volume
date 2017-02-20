//
//  CellOutlineAppDelegate.h
//  CellOutline
//
//  Created by Presley Work on 13-04-09.
//  Copyright 2013 McGill University. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "COMainWindow.h"

@interface CellOutlineAppDelegate : NSObject <NSApplicationDelegate> {
    COMainWindow *window;
}

@property (retain) COMainWindow *window;

@end
