//
//  Melative_ExampleAppDelegate.m
//  Melative Example
//
//  Created by Tohno Minagi on 3/14/10.
//  Copyright 2010 James M.. All rights reserved. Covered under the GNU Public License V3
//

#import "Melative_ExampleAppDelegate.h"
#import "PreferenceController.h"
#import "PFMoveApplication.h"

@implementation Melative_ExampleAppDelegate

@synthesize window;
@synthesize historywindow;
/**
 Returns the support directory for the application, used to store the Core Data
 store file.  This code uses a directory named "MAL Updater OS X" for
 the content, either in the NSApplicationSupportDirectory location or (if the
 former cannot be found), the system's temporary directory.
 */

- (NSString *)applicationSupportDirectory {
	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"MelScrobbleX"];
}


/**
 Creates, retains, and returns the managed object model for the application 
 by merging all of the models found in the application bundle.
 */

- (NSManagedObjectModel *)managedObjectModel {
	
    if (managedObjectModel) return managedObjectModel;
	
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
    return managedObjectModel;
}


/**
 Returns the persistent store coordinator for the application.  This 
 implementation will create and return a coordinator, having added the 
 store for the application to it.  (The directory for the store is created, 
 if necessary.)
 */

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {
	
    if (persistentStoreCoordinator) return persistentStoreCoordinator;
	
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSAssert(NO, @"Managed object model is nil");
        NSLog(@"%@:%s No model to generate a store from", [self class], _cmd);
        return nil;
    }
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *applicationSupportDirectory = [self applicationSupportDirectory];
    NSError *error = nil;
    
    if ( ![fileManager fileExistsAtPath:applicationSupportDirectory isDirectory:NULL] ) {
		if (![fileManager createDirectoryAtPath:applicationSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSAssert(NO, ([NSString stringWithFormat:@"Failed to create App Support directory %@ : %@", applicationSupportDirectory,error]));
            NSLog(@"Error creating application support directory at %@ : %@",applicationSupportDirectory,error);
            return nil;
		}
    }
    
    NSURL *url = [NSURL fileURLWithPath: [applicationSupportDirectory stringByAppendingPathComponent: @"Update History.meldb"]];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: mom];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType 
												  configuration:nil 
															URL:url 
														options:nil 
														  error:&error]){
        [[NSApplication sharedApplication] presentError:error];
        [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
        return nil;
    }    
	
    return persistentStoreCoordinator;
}

/**
 Returns the managed object context for the application (which is already
 bound to the persistent store coordinator for the application.) 
 */

- (NSManagedObjectContext *) managedObjectContext {
	
    if (managedObjectContext) return managedObjectContext;
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    managedObjectContext = [[NSManagedObjectContext alloc] init];
    [managedObjectContext setPersistentStoreCoordinator: coordinator];
	
    return managedObjectContext;
}
+ (void)initialize
{
	//Create a Dictionary
	NSMutableDictionary * defaultValues = [NSMutableDictionary dictionary];
	
	// Defaults
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:@"ShowAtStartup"];
	[defaultValues setObject:[NSNumber numberWithBool:NO] forKey:@"SuccessDebug"];
	[defaultValues setObject:@"" forKey:@"APIKey"];
	[defaultValues setObject:[NSNumber numberWithInt:0] forKey:@"PlayerSel"];
	[defaultValues setObject:[NSNumber numberWithInt:0] forKey:@"MediaType"];
	//Register Dictionary
	[[NSUserDefaults standardUserDefaults]
	 registerDefaults:defaultValues];

}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	//Check if Application is in the /Applications Folder
	PFMoveToApplicationsFolderIfNecessary();
	//Show Scrobble Window at Launch?
	NSUserDefaults *defaults = [[NSUserDefaults standardUserDefaults]autorelease];;
	if ([defaults boolForKey:@"ShowAtStartup"] == 0) {
		// Hide Window
		[window orderOut:self];
	}
	else {
		// Show the Window
		[window makeKeyAndOrderFront:nil];
	}
	//Register Growl
	NSBundle *myBundle = [NSBundle bundleForClass:[Melative_ExampleAppDelegate class]];
	NSString *growlPath = [[myBundle privateFrameworksPath] stringByAppendingPathComponent:@"Growl.framework"];
	NSBundle *growlBundle = [NSBundle bundleWithPath:growlPath];
	if (growlBundle && [growlBundle load]) {
		// Register ourselves as a Growl delegate
		[GrowlApplicationBridge setGrowlDelegate:self];
	}
	else {
		NSLog(@"ERROR: Could not load Growl.framework");
	}
	
}

- (void) awakeFromNib{
    
    //Create the NSStatusBar and set its length
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
    
    //Used to detect where our files are
    NSBundle *bundle = [NSBundle mainBundle];
    
    //Allocates and loads the images into the application which will be used for our NSStatusItem
    statusImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"melativeicon" ofType:@"tiff"]];
    statusHighlightImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"melativeicon" ofType:@"tiff"]];
    
    //Sets the images in our NSStatusItem
    [statusItem setImage:statusImage];
    [statusItem setAlternateImage:statusHighlightImage];
    
    //Tells the NSStatusItem what menu to load
    [statusItem setMenu:statusMenu];
    //Sets the tooptip for our item
    [statusItem setToolTip:@"MelScrobbleX"];
    //Enables highlighting
    [statusItem setHighlightMode:YES];
}
- (void) dealloc {
    //Releases the 2 images we loaded into memory
    [statusImage release];
    [statusHighlightImage release];
	[window release];
	[managedObjectContext release];
    [persistentStoreCoordinator release];
    [managedObjectModel release];
	if (!preferenceController) {
	}
	else {
		[preferenceController release];
	}

    [super dealloc];
}

-(IBAction)togglescrobblewindow:(id)sender
{
	if ([window isVisible]) { 
		[window orderOut:self]; 
	} else { 
		[window makeKeyAndOrderFront:self]; 
	} 
}
-(void)showPreferences:(id)sender
{
	//Is preferenceController nil?
	if (!preferenceController) {
		preferenceController = [[PreferenceController alloc] init];
	}
		[preferenceController showWindow:self];
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	
    if (!managedObjectContext) return NSTerminateNow;
	
    if (![managedObjectContext commitEditing]) {
        NSLog(@"%@:%s unable to commit editing to terminate", [self class], _cmd);
        return NSTerminateCancel;
    }
	
    if (![managedObjectContext hasChanges]) return NSTerminateNow;
	
    NSError *error = nil;
    if (![managedObjectContext save:&error]) {
		
        // This error handling simply presents error information in a panel with an 
        // "Ok" button, which does not include any attempt at error recovery (meaning, 
        // attempting to fix the error.)  As a result, this implementation will 
        // present the information to the user and then follow up with a panel asking 
        // if the user wishes to "Quit Anyway", without saving the changes.
		
        // Typically, this process should be altered to include application-specific 
        // recovery steps.  
		
        BOOL result = [sender presentError:error];
        if (result) return NSTerminateCancel;
		
        NSString *question = NSLocalizedString(@"Could not save changes while quitting.  Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];
		
        NSInteger answer = [alert runModal];
        [alert release];
        alert = nil;
        
        if (answer == NSAlertAlternateReturn) return NSTerminateCancel;
		
    }
	
    return NSTerminateNow;
}
-(void)addrecord:(NSString *)rectitle
	mediasegment:(NSString *)recsegment
			Date:(NSDate *)date
			type:(int)mediatype
{
	// Add scrobble history record to the SQLite Database via Core Data
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSManagedObject *obj = [NSEntityDescription 
							insertNewObjectForEntityForName :@"History" 
							inManagedObjectContext: moc];
	// Set values in the new record
	[obj setValue:rectitle forKey:@"Title"];
	[obj setValue:recsegment forKey:@"Segment"];
	[obj setValue:date forKey:@"Date"];
	switch (mediatype) {
		case 0:
			[obj setValue:@"Anime" forKey:@"Type"];
			break;
		case 1:
			[obj setValue:@"Music" forKey:@"Type"];
			break;
	}
	
	// Release Managed Object
	[obj release];
}
-(IBAction)clearhistory:(id)sender
{
	// Set Up Prompt Message Window
	NSAlert * alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Yes"];
	[alert addButtonWithTitle:@"No"];
	[alert setMessageText:@"Are you sure you want to clear the Update History?"];
	[alert setInformativeText:@"Once done, this action cannot be undone."];
	// Set Message type to Warning
	[alert setAlertStyle:NSWarningAlertStyle];
	// Show as Sheet on historywindow
	[alert beginSheetModalForWindow:historywindow 
					  modalDelegate:self
					 didEndSelector:@selector(clearhistoryended:code:conext:)
						contextInfo:NULL];
}
-(void)clearhistoryended:(NSAlert *)alert
					code:(int)choice
				  conext:(void *)v
{
	if (choice == 1000) {
		// Remove All Data
		NSManagedObjectContext *moc = [self managedObjectContext];
		NSFetchRequest * allHistory = [[NSFetchRequest alloc] init];
		[allHistory setEntity:[NSEntityDescription entityForName:@"History" inManagedObjectContext:moc]];
		
		NSError * error = nil;
		NSArray * histories = [moc executeFetchRequest:allHistory error:&error];
		[allHistory release];
		//error handling goes here
		for (NSManagedObject * history in histories) {
			[moc deleteObject:history];
		}
	}

}		
-(void)setStatusToolTip:(NSString*)toolTip
{
    [statusItem setToolTip:toolTip];
}
-(IBAction)showhistory:(id)sender
{
	[historywindow makeKeyAndOrderFront:self];
	
}
@end
