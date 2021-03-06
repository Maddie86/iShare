//
//  ISGoogleDriveViewController.m
//  iShare
//
//  Created by Jin Jin on 12-11-28.
//  Copyright (c) 2012年 Jin Jin. All rights reserved.
//

#import "ISGoogleDriveViewController.h"
#import "ISGoogleDriveDataSource.h"
#import "GTLDrive.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "ISGoogleAuth2ViewController.h"
#import "SVProgressHUD.h"

static NSString *const kKeychainItemName = @"Superb Share Google Drive";
static NSString *const kClientID = @"568917835566.apps.googleusercontent.com";
static NSString *const kClientSecret = @"0hiTKsfO6EIguEojJBjk3ibR";
static NSString *const kGoogleDriveAPIKey = @"AIzaSyAXGBe70QE-o0SFVXwgzf317fbgYE8Rv_0";

@interface ISGoogleDriveViewController ()

@property (nonatomic, strong) GTLServiceDrive* driveService;

@end

@implementation ISGoogleDriveViewController

+(void)removeAutherize{
    GTMOAuth2Authentication* auth = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                          clientID:kClientID
                                                                                      clientSecret:kClientSecret];
    [GTMOAuth2ViewControllerTouch revokeTokenForGoogleAuthentication:auth];
    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
}

+(BOOL)canAutherize{
    GTMOAuth2Authentication* auth = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                          clientID:kClientID
                                                                                      clientSecret:kClientSecret];
    return auth.canAuthorize;
}

-(void)viewDidLoad{
    self.title = @"Google Drive";
    [super viewDidLoad];
}

// Creates the auth controller for authorizing access to Googel Drive.
- (GTMOAuth2ViewControllerTouch *)createAuthController
{
    GTMOAuth2ViewControllerTouch *authController;
    authController = [[ISGoogleAuth2ViewController alloc] initWithScope:kGTLAuthScopeDrive
                                                                clientID:kClientID
                                                            clientSecret:kClientSecret
                                                        keychainItemName:kKeychainItemName
                                                                delegate:self
                                                        finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    return authController;
}

//auth finished callback
-(void)viewController:(GTMOAuth2ViewControllerTouch*)controller finishedWithAuth:(GTMOAuth2Authentication*)auth error:(NSError*)error{
    if (error == nil){
        self.driveService.authorizer = auth;
    }else{
        [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"alert_message_authfailed", nil)
                                  duration:2.0f];
    }
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - override super class
-(ISShareServiceBaseDataSource*)createModel{

    GTMOAuth2Authentication* auth = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                                                          clientID:kClientID
                                                                                                                      clientSecret:kClientSecret];
    self.driveService = [[GTLServiceDrive alloc] init];
    self.driveService.authorizer = auth;
    //specify to fetch all result
    self.driveService.shouldFetchNextPages = YES;
    self.driveService.retryEnabled = YES;
    
    ISGoogleDriveDataSource* datasource = [[ISGoogleDriveDataSource alloc] initWithWorkingPath:self.workingPath];
    datasource.driveSerivce = self.driveService;
    
    return datasource;
}

-(BOOL)serviceAutherized{
    return ((GTMOAuth2Authentication*)self.driveService.authorizer).canAuthorize;
}

-(void)autherizeService{
    GTMOAuth2ViewControllerTouch* controller = [self createAuthController];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:controller]
                       animated:YES
                     completion:NULL];
}

-(UIViewController*)controllerForChildFolder:(NSString *)folderPath{
    return [[ISGoogleDriveViewController alloc] initWithWorkingPath:folderPath];
}

-(void)deleteFileAtPath:(NSString *)filePath{
    
}

-(void)createNewFolder:(NSString *)folderName{

}

-(void)downloadRemoteFile:(FileShareServiceItem*)item toFolder:(NSString*)folder{
    
}

-(void)uploadSelectedFiles:(NSArray *)selectedFiles{
}

@end
