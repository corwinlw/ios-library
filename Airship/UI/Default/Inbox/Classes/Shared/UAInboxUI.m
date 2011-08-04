/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAInboxUI.h"
#import "UAInboxMessageListController.h"
#import "UAInboxMessageViewController.h"

#import "UAInboxMessageList.h"
#import "UAInboxPushHandler.h"

@implementation UAInboxUI
@synthesize localizationBundle, rootViewController, inboxParentController, isVisible;

SINGLETON_IMPLEMENTATION(UAInboxUI)

static BOOL runiPhoneTargetOniPad = NO;

+ (void)setRuniPhoneTargetOniPad:(BOOL)value {
    runiPhoneTargetOniPad = value;
}

- (void)dealloc {
    RELEASE_SAFELY(localizationBundle);
	RELEASE_SAFELY(alertHandler);
    RELEASE_SAFELY(rootViewController);
    RELEASE_SAFELY(inboxParentController);
    [super dealloc];
} 

- (id)init {
    if (self = [super init]) {
		
        NSString* path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"UAInboxLocalization.bundle"];
        self.localizationBundle = [NSBundle bundleWithPath:path];
		
        self.isVisible = NO;
        
        UAInboxMessageListController *mlc = [[UAInboxMessageListController alloc] initWithNibName:@"UAInboxMessageListController" bundle:nil];
        mlc.title = @"Inbox";
        mlc.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(inboxDone:)] autorelease];
        
        self.rootViewController = [[[UINavigationController alloc] initWithRootViewController:mlc] autorelease];
        
        alertHandler = [[UAInboxAlertHandler alloc] init];
        
        [[UAInbox shared].messageList addObserver:self];
		
    }
    return self;
}

- (void)inboxDone:(id)sender {
    [self quitInbox:NORMAL_QUIT];
}

+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated {
	
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)viewController popToRootViewControllerAnimated:NO];
    }

	[UAInboxUI shared].isVisible = YES;
    
    UALOG(@"present modal");
    [viewController presentModalViewController:[UAInboxUI shared].rootViewController animated:animated];
} 



+ (void)displayMessage:(UIViewController *)viewController message:(NSString *)messageID {
	
    if(![UAInboxUI shared].isVisible) {
        UALOG(@"UI needs to be brought up!");
		// We're not inside the modal/navigationcontroller setup so lets start with the parent
		[UAInboxUI displayInbox:[UAInboxUI shared].inboxParentController animated:NO]; // BUG?
	}
	
    // If the message view is already open, just load the first message.
    if ([viewController isKindOfClass:[UINavigationController class]]) {
		
        // For iPhone
        UINavigationController *navController = (UINavigationController *)viewController;
        UAInboxMessageViewController *mvc;
        
		if ([navController.topViewController class] == [UAInboxMessageViewController class]) {
            mvc = (UAInboxMessageViewController *) navController.topViewController;
            [mvc loadMessageForID:messageID];
        } else {
			
            mvc = [[[UAInboxMessageViewController alloc] initWithNibName:@"UAInboxMessageViewController" bundle:nil] autorelease];			
            [mvc loadMessageForID:messageID];
            [navController pushViewController:mvc animated:YES];
        }
    }
}

+ (void)quitInbox {
    [[UAInboxUI shared] quitInbox:NORMAL_QUIT];
}

- (void)quitInbox:(QuitReason)reason {
    if (reason == DEVICE_TOKEN_ERROR) {
        UALOG(@"Inbox not initialized. Waiting for Device Token.");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Inbox_Not_Ready_Title")
                                                        message:UA_INBOX_TR(@"UA_Error_Get_Device_Token")
                                                       delegate:nil
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else if (reason == USER_ERROR) {
        UALOG(@"Inbox not initialized. Waiting for Device Token.");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Inbox_Not_Ready_Title")
                                                        message:UA_INBOX_TR(@"UA_Inbox_Not_Ready")
                                                       delegate:nil
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        NSLog(@"reason=%d", reason);
    }
    

    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)rootViewController popToRootViewControllerAnimated:NO];
    }
	
    self.isVisible = NO;
    
    //added iOS 5 parent/presenting view getter
    UIViewController *con;
    if ([self.rootViewController respondsToSelector:@selector(presentingViewController)]) {
        con = self.rootViewController.presentingViewController;
    } else {
        con = self.rootViewController.parentViewController;
    }
    
    [con dismissModalViewControllerAnimated:YES];
    
    // BUG: Workaround. ModalViewController does not handle resizing correctly if
    // dismissed in landscape when status bar is visible
    if (![UIApplication sharedApplication].statusBarHidden)
        con.view.frame = UAFrameForCurrentOrientation(con.view.frame);
}

// handle both in app notification and launching notification
- (void)messageListLoaded {
	[UAInboxUI loadLaunchMessage];
}


+ (void)loadLaunchMessage {
	
	// if pushhandler has a messageID load it
	if([[UAInbox shared].pushHandler viewingMessageID] != nil) {

		UAInboxMessage *msg = [[UAInbox shared].messageList messageForID:[[UAInbox shared].pushHandler viewingMessageID]];
		if (msg == nil) {
			return;
		}
        
        UIViewController *rvc = [UAInboxUI shared].rootViewController;
		        
		[UAInboxUI displayMessage:rvc message:[[UAInbox shared].pushHandler viewingMessageID]];
		
		[[UAInbox shared].pushHandler setViewingMessageID:nil];
		[[UAInbox shared].pushHandler setHasLaunchMessage:NO];
	}

}

+ (void)land {
	[[UAInboxMessageList shared] removeObserver:self];  
}

+ (id<UAInboxAlertProtocol>)getAlertHandler {
    UAInboxUI* ui = [UAInboxUI shared];
    return ui->alertHandler;
}

@end
