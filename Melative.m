//
//  Melative.m
//  MelScrobbleX
//
//  Created by Tohno Minagi on 3/14/10.
//  Copyright 2010 James M.. All rights reserved. Covered under the GNU Public License V3
//

#import "Melative.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "iTunes.h"
#import "EMKeychainItem.h"

@implementation Melative
@synthesize fieldusername;
@synthesize fieldpassword;

-(IBAction)postmessage:(id)sender
{
	NSLog(@"%i",[mediatypemenu indexOfSelectedItem]);
//Post the update
	if (fieldusername == nil) {
		[self loadlogin];
	}
		if ( fieldpassword == nil ) {
			//No account information. Show error message.
			choice = NSRunCriticalAlertPanel(@"MelScrobbleX was unable to post an update since you didn't set any account information", @"Set your account information in Preferences and try again.", @"OK", nil, nil, 8);
		}
		else {

			if ( [[fieldmessage stringValue] length] == 0 && [[mediatitle stringValue]length] == 0 ) {
				//No message, show error
			choice = NSRunCriticalAlertPanel(@"MelScrobbleX was unable to post an update since you didn't enter a message", @"Enter a message and try posting again", @"OK", nil, nil, 8);
			
			}
			else {
			//Set micro/update API
			NSURL *url = [NSURL URLWithString:@"http://melative.com/api/micro/update.json"];
				ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
			//Ignore Cookies
				[request setUseCookiePersistence:NO];
				//Set Username
			[request setUsername:fieldusername];
				[request setPassword:fieldpassword];
			if ([[mediatitle stringValue]length] > 0) {
					
				//Generate the mediamessage in /<action> /<mediatype>/<mediatitle>/<segment>: <message> format
				NSString * mediamessage = @"/";
				if ( [mediatypemenu indexOfSelectedItem] == 0) {
					mediamessage = @"watching /anime/";
					// From Mplayer?
					[request setPostValue:@"mplayer" forKey:@"source"];
				}
				else if ([mediatypemenu indexOfSelectedItem] == 1) {
					mediamessage = @"listening /mu/";
					// Music Playing, must be from iTunes
					[request setPostValue:@"iTunes" forKey:@"source"];
				}
				if ([[segment stringValue]length] >0) {
					mediamessage = [mediamessage stringByAppendingFormat:@"%@/%@: %@",[mediatitle stringValue], [segment stringValue], [fieldmessage stringValue]];
				}
				else{
				mediamessage = [mediamessage stringByAppendingFormat:@"%@/: %@",[mediatitle stringValue], [fieldmessage stringValue]];
				}
				NSLog(@"%@",mediamessage);
				[request setPostValue:mediamessage forKey:@"message"];
				// Get rid of Mediamessage. Not needed
				mediamessage = nil;
				}
				else {
					//Send message only
					[request setPostValue:[fieldmessage stringValue] forKey:@"message"];
					[request setPostValue:@"MelScrobbleX" forKey:@"source"];
				}
			[request startSynchronous];
			// Get Status Code
			int statusCode = [request responseStatusCode];
			if (statusCode == 200 ) {
				NSString *response = [request responseString];
				//Post suggessful... or is it?
				choice = NSRunAlertPanel(@"Post Successful", response, @"OK", nil, nil, 8);
				//release
				response = nil;
				//Clear Message
				[fieldmessage setObjectValue:@""];
			}
			else {
				//Login Failed, show error message
				choice = NSRunCriticalAlertPanel(@"MelScrobbleX was unable to post an update since you don't have the correct username and/or password", @"Check your username and password and try posting again. If you recently changed your password, ener you new password and try again.", @"OK", nil, nil, 8);
			}
			//release
				request = nil;
				url = nil;
			}
	}
}
-(IBAction)getnowplaying:(id)sender
{
	if ([mediatypemenu indexOfSelectedItem] == 0) {
	// LSOF mplayer to get the media title and segment
		NSTask *task;
		task = [[[NSTask alloc] init]autorelease];
		[task setLaunchPath: @"/usr/sbin/lsof"];
		//lsof -c 'mplayer' -Fn		
		[task setArguments: [NSArray arrayWithObjects:@"-c", @"mplayer", @"-F", @"n", nil]];
		
		NSPipe *pipe;
		pipe = [NSPipe pipe];
		[task setStandardOutput: pipe];
		
		NSFileHandle *file;
		file = [pipe fileHandleForReading];
		
		[task launch];
		
		NSData *data;
		data = [file readDataToEndOfFile];
		
		NSString *string;
		string = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]autorelease];
		
	//Regex time
		//Setup OgreKit
		OGRegularExpressionMatch    *match;
		OGRegularExpression    *regex;
		//Get the filename first
		regex = [OGRegularExpression regularExpressionWithString:@"^.+(avi|mkv|mp4|ogm)$"];
		NSEnumerator    *enumerator;
		enumerator = [regex matchEnumeratorInString:string];		
		while ((match = [enumerator nextObject]) != nil) {
			string = [match matchedString];
		}
		//Cleanup
		regex = [OGRegularExpression regularExpressionWithString:@"^.+/"];
		string = [regex replaceAllMatchesInString:string
									   withString:@""];
		regex = [OGRegularExpression regularExpressionWithString:@"\\.\\w+$"];
		string = [regex replaceAllMatchesInString:string
									   withString:@""];
		regex = [OGRegularExpression regularExpressionWithString:@"\\s*\\[[^\\]]+\\]\\s*"];
		string = [regex replaceAllMatchesInString:string
									   withString:@""];
		regex = [OGRegularExpression regularExpressionWithString:@"\\s*\\([^\\)]+\\)$"];
		string = [regex replaceAllMatchesInString:string
									   withString:@""];
		regex = [OGRegularExpression regularExpressionWithString:@"_"];
		string = [regex replaceAllMatchesInString:string
									   withString:@" "];
		// Set Title Info
		regex = [OGRegularExpression regularExpressionWithString:@"( \\-)? (episode |ep |ep|e)?(\\d+)([\\w\\-! ]*)$"];
		[mediatitle setObjectValue:[regex replaceAllMatchesInString:string
									   withString:@""]];
		// Set Segment Info
		regex = [OGRegularExpression regularExpressionWithString:@" - "];
		string = [regex replaceAllMatchesInString:string
									   withString:@" "];
		regex = [OGRegularExpression regularExpressionWithString: [mediatitle stringValue]];
		[segment setObjectValue:[regex replaceAllMatchesInString:string
												withString:@"Episode"]];
		//release
		regex = nil;
		enumerator = nil;
		string = nil;
	}
	else if ([mediatypemenu indexOfSelectedItem] == 1) {
	// Init iTunes Scripting 
		iTunesApplication *iTunes = [[SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"]autorelease];
	//Obtain the Alubm and Track Name and place them in the Media Title and Segment Fields
		[mediatitle setObjectValue:iTunes.currentTrack.album];
		[segment setObjectValue:iTunes.currentTrack.name];
	}
}
-(void)loadlogin
{
	// Load Username
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	fieldusername = [defaults objectForKey:@"Username"];
	NSLog(@"%@",fieldusername);
	// Load Keychain, if exists
	EMGenericKeychainItem *keychainItem = [EMGenericKeychainItem genericKeychainItemForService:@"MelScrobbleX" withUsername: fieldusername];
	NSLog(@"%@", keychainItem.password);
	if (keychainItem.password != nil) {
		fieldpassword = keychainItem.password;
		// Also, set it for Melative.h
		//Melative.fieldpassword = keychainItem.username;
		//[Melative setFieldpassword:keychainItem.password];
		
	}
	//Release Keychain Item
	 [keychainItem release], keychainItem = nil;
	
}
- (void)dealloc {
    [fieldusername release];
	[fieldpassword release];
    [super dealloc];
}
@end
