//
//  AppDelegate.m
//  Screentool
//
//  Created by Aliksandr Andrashuk on 16.03.13.
//  Copyright (c) 2013 Aliksandr Andrashuk. All rights reserved.
//

#import "AppDelegate.h"

static NSString * kSettingsCaptureWindowShadow = @"captureShadows";
static NSString * kSettingSaveImages = @"saveImages";
static NSString * kSettingPlaySoundWhenCapture = @"playSoundWhenCapture";
static NSString * kSettingVisualEffects = @"visualEffectsEnabled";
static NSString * kSettingSelectedSystemSound = @"selectedSystemSound";
static NSString * kSettingSaveImagesTo = @"saveImagesTo";

@interface AppDelegate ()
@property (weak) IBOutlet NSButton *customButton;
@property (weak) IBOutlet NSMenu *statusMenu;
@property (strong) NSStatusItem *statusItem;
@property (strong) NSDateFormatter *dateFormatter;
@property (strong) NSArray *systemSounds;
@property (strong) NSNumber *selectedSystemSound;
@property (strong) NSArray *directoriesList;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    self.dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    
    self.statusItem = [bar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.highlightMode = YES;
    self.statusItem.menu = self.statusMenu;
    self.statusItem.image = [NSImage imageNamed:@"icon-gradient"];
    
    [self setupInitialSettings];
    self.systemSounds = [self generateSystemSoundsList];
    self.directoriesList = [self generateDirectoriesList];
}

#pragma mark - Settings

- (void) setupInitialSettings { 
    if (![[NSUserDefaults standardUserDefaults] valueForKey:kSettingsCaptureWindowShadow]) {
        [[NSUserDefaults standardUserDefaults] setValue:@(YES) forKey:kSettingsCaptureWindowShadow];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:kSettingSaveImages]) {
        [[NSUserDefaults standardUserDefaults] setValue:@(YES) forKey:kSettingSaveImages];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:kSettingPlaySoundWhenCapture]) {
        [[NSUserDefaults standardUserDefaults] setValue:@(YES) forKey:kSettingPlaySoundWhenCapture];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:kSettingVisualEffects]) {
        [[NSUserDefaults standardUserDefaults] setValue:@(YES) forKey:kSettingVisualEffects];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:kSettingSelectedSystemSound]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"Blow" forKey:kSettingSelectedSystemSound];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:kSettingSaveImagesTo]) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
        [[NSUserDefaults standardUserDefaults] setValue:[paths[0] lastPathComponent] forKey:kSettingSaveImagesTo];
    }
}

- (NSArray *) generateSystemSoundsList {
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:@"/System/Library/Sounds" error:&error];
    return [files valueForKey:@"stringByDeletingPathExtension"];
}

- (IBAction)systemSoundChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self playCurrentSystemSound];
}

- (NSArray *) generateDirectoriesList {
    NSMutableArray *directories = [NSMutableArray array];
    NSArray *dirs = @[ @(NSUserDirectory), @(NSDocumentDirectory), @(NSDesktopDirectory), @(NSDownloadsDirectory), @(NSPicturesDirectory), @(NSSharedPublicDirectory)];
    for (NSNumber *dir in dirs) {
        [directories addObjectsFromArray:NSSearchPathForDirectoriesInDomains([dir intValue], NSUserDomainMask, YES)];
    }
    return [directories valueForKey:@"lastPathComponent"];
}

#pragma mark - Sound

- (void) playCurrentSystemSound {
    NSString *soundName = [[NSUserDefaults standardUserDefaults] valueForKey:kSettingSelectedSystemSound];
    [[NSSound soundNamed:soundName] play];
}

#pragma mark - Shotting

- (NSURL *) saveCGImageAsScreenShot:(CGImageRef)screenshot {
    NSURL *url = [self fileURLInDesktopWithFilename:[self generateFilenameWithExtension:@"png"]];
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)(url), kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(destination, screenshot, NULL);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    
    NSLog(@"Screenshot saved at %@", url);
    return url;
}

- (NSURL *) shotScreen {
    return [self saveCGImageAsScreenShot:CGDisplayCreateImage(CGMainDisplayID())];
}

- (NSURL *) shotWindow {
    NSString *ownerPIDKey = (__bridge NSString *)kCGWindowOwnerPID;
    NSString *windowIDKey = (__bridge NSString *)kCGWindowNumber;
    NSString *layerKey = (__bridge NSString *)kCGWindowLayer;
    NSString *boundsKey = (__bridge NSString *)kCGWindowBounds;
    NSString *windowNameKey = (__bridge NSString *)kCGWindowName;
    
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSRunningApplication *frontmostApplication = [workspace frontmostApplication];
    
    CFArrayRef windowsInfoRaw = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    NSArray *windowsInfo = (__bridge NSArray *)(windowsInfoRaw);
    CFRelease(windowsInfoRaw);

    NSDictionary *windowInfo;
    NSMutableArray *possibleWindows = [NSMutableArray array];
   
    for (NSDictionary *info in windowsInfo) {
        if ([info[ownerPIDKey] integerValue] == frontmostApplication.processIdentifier && [info[layerKey] intValue] == 0) {
            [possibleWindows addObject:info];
        }
    }
    
    BOOL frontWindowFound = YES;
    CGWindowID windowID = [windowInfo[windowIDKey] intValue];
    while (frontWindowFound) {
        CGWindowListCreate(kCGWindowListOptionOnScreenAboveWindow, windowID);
        CFArrayRef array = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenAboveWindow, windowID);
        NSArray *windows = (__bridge NSArray *)(array);
        CFRelease(array);
        
        frontWindowFound = NO;
        for (NSDictionary *info in windows) {
            if ([info[ownerPIDKey] integerValue] == frontmostApplication.processIdentifier && [info[layerKey] intValue] == 0) { 
                windowInfo = info;
                frontWindowFound = YES;
                break;
            }
        }
        
        windowID = [windowInfo[windowIDKey] intValue];
    }
    
    CGImageRef image = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, windowID, 0);

    return [self saveCGImageAsScreenShot:image];
}

#pragma mark - Name generation

- (NSString *)generateFilenameWithExtension:(NSString *)extension {
    return [[[self.dateFormatter stringFromDate:[NSDate date]] stringByAppendingFormat:@".%@", extension] stringByReplacingOccurrencesOfString:@" " withString:@"_"];
}

- (NSURL *)fileURLInDesktopWithFilename:(NSString *)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", paths[0], filename]];
}
- (NSString *)filePathInDesktopWithFilename:(NSString *)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
    return [NSString stringWithFormat:@"%@/%@", paths[0], filename];
}

- (IBAction)captureWindowSelected:(NSMenuItem *)sender {
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        NSURL *url = [self shotWindow];
        if (sender.tag == 4) {
            [[NSWorkspace sharedWorkspace] openFile:url.path withApplication:@"Mail"];
        }
        else if (sender.tag == 7) {
            [[NSWorkspace sharedWorkspace] openFile:url.path withApplication:@"Preview"];
        }
        [self playCurrentSystemSound];
    });
}

- (IBAction)captureScreenSelected:(NSMenuItem *)sender {
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        NSURL *url = [self shotScreen];
        if (sender.tag == 5) {
            [[NSWorkspace sharedWorkspace] openFile:url.path withApplication:@"Mail"];
        }
        else if (sender.tag == 8) {
            [[NSWorkspace sharedWorkspace] openFile:url.path withApplication:@"Preview"];
        }
        [self playCurrentSystemSound];
    });
}

- (IBAction)captureSelectionSelected:(NSMenuItem *)sender {
    NSString *path = [self filePathInDesktopWithFilename:[self generateFilenameWithExtension:@"png"]];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/screencapture";
    task.arguments = @[@"-i", @"-x", @"-s", path];
    task.terminationHandler = ^(NSTask *task) {
        [self playCurrentSystemSound];
        if (sender.tag == 6) {
            [[NSWorkspace sharedWorkspace] openFile:path withApplication:@"Mail"];
        }
        else if (sender.tag == 9) {
            [[NSWorkspace sharedWorkspace] openFile:path withApplication:@"Preview"];
        }
    };
    [task launch];
}

@end
