/**
 * @file DetailsNodeInfoViewController.m
 * @brief View controller that show details info about a node
 *
 * (c) 2013-2015 by Mega Limited, Auckland, New Zealand
 *
 * This file is part of the MEGA SDK - Client Access Engine.
 *
 * Applications using the MEGA API must present a valid application key
 * and comply with the the rules set forth in the Terms of Service.
 *
 * The MEGA SDK is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * @copyright Simplified (2-clause) BSD License.
 *
 * You should have received a copy of the license along with this
 * program.
 */

#import "NSString+MNZCategory.h"
#import "SVProgressHUD.h"

#import "Helper.h"

#import "DetailsNodeInfoViewController.h"
#import "BrowserViewController.h"
#import "CloudDriveTableViewController.h"
#import "ContactsViewController.h"
#import "MEGANavigationController.h"
#import "MEGAReachabilityManager.h"
#import "GetLinkActivity.h"
#import "ShareFolderActivity.h"
#import "OpenInActivity.h"
#import "RemoveLinkActivity.h"
#import "MEGAActivityItemProvider.h"
#import "MEGAStore.h"

@interface DetailsNodeInfoViewController () <UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, MEGADelegate> {
    UIAlertView *cancelDownloadAlertView;
    UIAlertView *renameAlertView;
    UIAlertView *removeAlertView;
    
    NSInteger actions;
    MEGAShareType accessType;
}

@property (strong, nonatomic) IBOutlet UIBarButtonItem *shareBarButtonItem;

@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *foldersFilesLabel;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation DetailsNodeInfoViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    accessType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:self.node];
    
    if (self.displayMode == DisplayModeCloudDrive && (accessType == MEGAShareTypeAccessOwner)) {
        [self.navigationItem setRightBarButtonItem:_shareBarButtonItem];
    }
    
    switch (accessType) {
        case MEGAShareTypeAccessRead:
        case MEGAShareTypeAccessReadWrite:
            if (self.displayMode == DisplayModeContact) {
                actions = 3; //Download, copy and leave
            } else {
                actions = 2; //Download and copy
            }
            break;
            
        case MEGAShareTypeAccessFull:
                actions = 4; //Download, copy, rename and leave (contacts) or delete (cloud drive)
            break;
            
        case MEGAShareTypeAccessOwner: //Cloud Drive & Rubbish Bin
            actions = 5; //Download, move, copy, rename and move to rubbish bin or remove
            break;
            
        default:
            break;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadUI];
    [[MEGASdkManager sharedMEGASdk] addMEGADelegate:self];
    [[MEGASdkManager sharedMEGASdk] retryPendingConnections];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[MEGASdkManager sharedMEGASdk] removeMEGADelegate:self];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (void)reloadUI {
    if ([self.node type] == MEGANodeTypeFile) {
        
        if ([self.node hasThumbnail]) {
            NSString *thumbnailFilePath = [Helper pathForNode:self.node searchPath:NSCachesDirectory directory:@"thumbnailsV3"];
            BOOL thumbnailExists = [[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath];
            if (!thumbnailExists) {
                [self.thumbnailImageView setImage:[Helper infoImageForNode:self.node]];
            } else {
                [self.thumbnailImageView setImage:[UIImage imageWithContentsOfFile:thumbnailFilePath]];
            }
        } else {
            [self.thumbnailImageView setImage:[Helper infoImageForNode:self.node]];
        }
        
        [_foldersFilesLabel setHidden:YES];
        
    } else if ([self.node type] == MEGANodeTypeFolder) {
        
        [self.thumbnailImageView setImage:[Helper infoImageForNode:self.node]];
        
        NSInteger files = [[MEGASdkManager sharedMEGASdk] numberChildFilesForParent:_node];
        NSInteger folders = [[MEGASdkManager sharedMEGASdk] numberChildFoldersForParent:_node];
        
        NSString *filesAndFolders = [@"" stringByFiles:files andFolders:folders];
        [_foldersFilesLabel setText:filesAndFolders];
    }
    
    struct tm *timeinfo;
    char buffer[80];
    time_t rawtime;
    if ([self.node isFile]) {
        rawtime = [[self.node modificationTime] timeIntervalSince1970];
    } else {
        rawtime = [[self.node creationTime] timeIntervalSince1970];
    }
    timeinfo = localtime(&rawtime);
    
    strftime(buffer, 80, "%d/%m/%y %H:%M", timeinfo);
    
    [self setTitle:[self.node name]];
    
    [self.nameLabel setText:[self.node name]];
    
    NSString *date = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    NSString *size = [NSByteCountFormatter stringFromByteCount:[[[MEGASdkManager sharedMEGASdk] sizeForNode:self.node] longLongValue] countStyle:NSByteCountFormatterCountStyleMemory];
    NSString *sizeAndDate = [NSString stringWithFormat:@"%@ • %@", size, date];
    
    [_infoLabel setText:sizeAndDate];
    
    [self.tableView reloadData];
}

#pragma mark - Private methods

- (void)download {
    if ([MEGAReachabilityManager isReachable]) {
        if (![Helper isFreeSpaceEnoughToDownloadNode:self.node isFolderLink:NO]) {
            return;
        }
        [Helper downloadNode:self.node folderPath:[Helper pathForOffline] isFolderLink:NO];
        [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"downloadStarted", nil)];
        
        if ([self.node isFolder]) {
            [self.navigationController popViewControllerAnimated:YES];
        }
    } else {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"noInternetConnection", @"No Internet Connection")];
    }
}

- (void)getLink {
    if ([MEGAReachabilityManager isReachable]) {
        [[MEGASdkManager sharedMEGASdk] exportNode:self.node];
    } else {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"noInternetConnection", @"No Internet Connection")];
    }
}

- (void)disableLink {
    if ([MEGAReachabilityManager isReachable]) {
        [[MEGASdkManager sharedMEGASdk] disableExportNode:self.node];
    } else {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"noInternetConnection", @"No Internet Connection")];
    }
}

- (void)browserWithAction:(NSInteger)browserAction {
    if ([MEGAReachabilityManager isReachable]) {
        MEGANavigationController *navigationController = [self.storyboard instantiateViewControllerWithIdentifier:@"BrowserNavigationControllerID"];
        [self presentViewController:navigationController animated:YES completion:nil];
        
        BrowserViewController *browserVC = navigationController.viewControllers.firstObject;
        browserVC.parentNode = [[MEGASdkManager sharedMEGASdk] rootNode];
        browserVC.selectedNodesArray = [NSArray arrayWithObject:self.node];
        [browserVC setBrowserAction:browserAction]; //
    } else {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"noInternetConnection", @"No Internet Connection")];
    }
}

- (void)rename {
    if ([MEGAReachabilityManager isReachable]) {
        if (!renameAlertView) {
            renameAlertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"rename", nil) message:AMLocalizedString(@"renameNodeMessage", @"Enter the new name") delegate:self cancelButtonTitle:AMLocalizedString(@"cancel", nil) otherButtonTitles:AMLocalizedString(@"rename", nil), nil];
        }
        
        [renameAlertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
        [renameAlertView setTag:0];
        
        UITextField *textField = [renameAlertView textFieldAtIndex:0];
        [textField setDelegate:self];
        [textField setText:[self.node name]];
        
        [renameAlertView show];
    } else {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"noInternetConnection", @"No Internet Connection")];
    }
}

- (void)delete {
    if ([MEGAReachabilityManager isReachable]) {
        //Leave folder or remove folder in a incoming shares
        if (self.displayMode == DisplayModeContact || (self.displayMode == DisplayModeCloudDrive && accessType == MEGAShareTypeAccessFull)) {
            [[MEGASdkManager sharedMEGASdk] removeNode:self.node];
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            
            //Delete permanently
            if (self.displayMode == DisplayModeRubbishBin) {
                if ([self.node type] == MEGANodeTypeFolder) {
                    removeAlertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"remove", nil) message:AMLocalizedString(@"removeFolderToRubbishBinMessage", nil) delegate:self cancelButtonTitle:AMLocalizedString(@"cancel", nil) otherButtonTitles:AMLocalizedString(@"ok", nil), nil];
                } else {
                    removeAlertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"remove", nil) message:AMLocalizedString(@"removeFileToRubbishBinMessage", nil) delegate:self cancelButtonTitle:AMLocalizedString(@"cancel", nil) otherButtonTitles:AMLocalizedString(@"ok", nil), nil];
                }
            }
            
            //Move to rubbish bin
            if (self.displayMode == DisplayModeCloudDrive) {
                removeAlertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"moveToTheRubbishBin", nil) message:AMLocalizedString(@"moveFileToRubbishBinMessage", nil) delegate:self cancelButtonTitle:AMLocalizedString(@"cancel", nil) otherButtonTitles:AMLocalizedString(@"ok", nil), nil];
            }
            
            [removeAlertView setTag:1];
            [removeAlertView show];
        }
    } else {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"noInternetConnection", @"No Internet Connection")];
    }
}

- (void)showWarningAfterActionOnNode:(MEGANode *)nodeUpdated {
    NSString *alertTitle = @"";
    
    nodeUpdated = [[MEGASdkManager sharedMEGASdk] nodeForHandle:[self.node handle]];
    if (nodeUpdated != nil) { //Is nil if you don't have access to it
        if (nodeUpdated.parentHandle == self.node.parentHandle) { //Same place as before
            //Node renamed, update UI with the new info.
            //Also when you get link, share folder or remove link
            self.node = nodeUpdated;
            [self reloadUI];
        } else {
            //Node moved to the Rubbish Bin or moved inside the same shared folder
            if (nodeUpdated.parentHandle == [[[MEGASdkManager sharedMEGASdk] rubbishNode] handle]) {
                if ([self.node isFile]) {
                    alertTitle = @"fileMovedToTheRubbishBin_alertTitle";
                } else {
                    alertTitle = @"folderMovedToTheRubbishBin_alertTitle";
                }
            } else {
                if ([self.node isFile]) {
                    alertTitle = @"fileMoved_alertTitle";
                } else {
                    alertTitle = @"folderMoved_alertTitle";
                }
            }
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(alertTitle, nil)
                                                                message:nil
                                                               delegate:self
                                                      cancelButtonTitle:nil otherButtonTitles:AMLocalizedString(@"ok", nil), nil];
            [alertView setTag:3];
            [alertView show];
        }
    } else {
        //Node removed from the Rubbish Bin or moved outside of the shared folder
        if ([self.node isFile]) {
            alertTitle = @"youNoLongerHaveAccessToThisFile_alertTitle";
        } else {
            alertTitle = @"youNoLongerHaveAccessToThisFolder_alertTitle";
        }
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(alertTitle, nil)
                                                            message:nil
                                                           delegate:self
                                                  cancelButtonTitle:nil otherButtonTitles:AMLocalizedString(@"ok", nil), nil];
        [alertView setTag:3];
        [alertView show];
    }
}

#pragma mark - IBActions

- (IBAction)shareTouchUpInside:(UIBarButtonItem *)sender {
    
    UIActivityViewController *activityVC;
    NSMutableArray *activityItemsMutableArray = [[NSMutableArray alloc] init];
    NSMutableArray *activitiesMutableArray = [[NSMutableArray alloc] init];
    
    NSMutableArray *excludedActivityTypesMutableArray = [[NSMutableArray alloc] init];
    [excludedActivityTypesMutableArray addObjectsFromArray:@[UIActivityTypePrint, UIActivityTypeCopyToPasteboard, UIActivityTypeAssignToContact, UIActivityTypeSaveToCameraRoll, UIActivityTypeAddToReadingList, UIActivityTypeAirDrop]];
    
    GetLinkActivity *getLinkActivity = [[GetLinkActivity alloc] initWithNode:self.node];
    [activitiesMutableArray addObject:getLinkActivity];
    
    MOOfflineNode *offlineNodeExist = [[MEGAStore shareInstance] fetchOfflineNodeWithFingerprint:[[MEGASdkManager sharedMEGASdk] fingerprintForNode:self.node]];
    if (offlineNodeExist) {
        if ([self.node type] == MEGANodeTypeFolder) {
            ShareFolderActivity *shareFolderActivity = [[ShareFolderActivity alloc] initWithNode:self.node];
            [activitiesMutableArray addObject:shareFolderActivity];
            
            BOOL isPublicLink = NO;
            MEGAShareList *outSharesList = [[MEGASdkManager sharedMEGASdk] outSharesForNode:self.node];
            for (NSInteger i = 0; i < outSharesList.size.integerValue; i++) {
                if ([[outSharesList shareAtIndex:i] user] == nil) {
                    isPublicLink = TRUE;
                    break;
                }
            }
            if (isPublicLink) {
                RemoveLinkActivity *removeLinkActivity = [[RemoveLinkActivity alloc] initWithNode:self.node];
                [activitiesMutableArray addObject:removeLinkActivity];
            }
            
        } else {
            NSURL *fileURL = [NSURL fileURLWithPath:[[Helper pathForOffline] stringByAppendingPathComponent:[offlineNodeExist localPath]]];
            [activityItemsMutableArray addObject:fileURL];
            [excludedActivityTypesMutableArray removeObject:UIActivityTypeAirDrop];
            
            OpenInActivity *openInActivity = [[OpenInActivity alloc] initOnBarButtonItem:_shareBarButtonItem];
            [activitiesMutableArray addObject:openInActivity];
        }
        
    } else {
        
        if ([self.node type] == MEGANodeTypeFolder) {
            
            ShareFolderActivity *shareFolderActivity = [[ShareFolderActivity alloc] initWithNode:self.node];
            [activitiesMutableArray addObject:shareFolderActivity];
            
            BOOL isPublicLink = NO;
            MEGAShareList *outSharesList = [[MEGASdkManager sharedMEGASdk] outSharesForNode:self.node];
            for (NSInteger i = 0; i < outSharesList.size.integerValue; i++) {
                if ([[outSharesList shareAtIndex:i] user] == nil) {
                    isPublicLink = TRUE;
                    break;
                }
            }
            if (isPublicLink) {
                RemoveLinkActivity *removeLinkActivity = [[RemoveLinkActivity alloc] initWithNode:self.node];
                [activitiesMutableArray addObject:removeLinkActivity];
            }
            
        }
        
        MEGAActivityItemProvider *activityItemProvider = [[MEGAActivityItemProvider alloc] initWithPlaceholderString:self.node.name node:self.node];
        [activityItemsMutableArray addObject:activityItemProvider];

    }
    
    activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItemsMutableArray applicationActivities:activitiesMutableArray];
    [activityVC setExcludedActivityTypes:excludedActivityTypesMutableArray];
    
    if ([activityVC respondsToSelector:@selector(popoverPresentationController)]) {
        [activityVC.popoverPresentationController setBarButtonItem:_shareBarButtonItem];
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - UIAlertDelegate

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView {
    BOOL shouldEnable;
    if ([alertView tag] == 0) {
        UITextField *textField = [alertView textFieldAtIndex:0];
        NSString *newName = [textField text];
        NSString *newNameExtension = [newName pathExtension];
        NSString *newNameWithoutExtension = [newName stringByDeletingPathExtension];
        
        NSString *nodeNameString = [self.node name];
        NSString *nodeNameExtension = [NSString stringWithFormat:@".%@", [nodeNameString pathExtension]];
        
        switch ([self.node type]) {
            case MEGANodeTypeFile: {
                if ([newName isEqualToString:@""] ||
                    [newName isEqualToString:nodeNameString] ||
                    [newName isEqualToString:nodeNameExtension] ||
                    ![[NSString stringWithFormat:@".%@", newNameExtension] isEqualToString:nodeNameExtension] || //Particular case, for example: (.jp == .jpg)
                    [newNameWithoutExtension isEqualToString:nodeNameExtension]) {
                    shouldEnable = NO;
                } else {
                    shouldEnable = YES;
                }
                break;
            }
                
            case MEGANodeTypeFolder: {
                if ([newName isEqualToString:@""] || [newName isEqualToString:nodeNameString]) {
                    shouldEnable = NO;
                } else {
                    shouldEnable = YES;
                }
                break;
            }
                
            default:
                shouldEnable = NO;
                break;
        }
        
    } else {
        shouldEnable = YES;
    }
    
    return shouldEnable;
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([alertView tag] == 0) {
        UITextField *textField = [alertView textFieldAtIndex:0];
        [textField setSelectedTextRange:nil];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    switch ([alertView tag]) {
        case 0: {
            if (buttonIndex == 1) {
                UITextField *alertViewTextField = [alertView textFieldAtIndex:0];
                [[MEGASdkManager sharedMEGASdk] renameNode:self.node newName:[alertViewTextField text]];
            }
            break;
        }
            
        case 1: {
            if (buttonIndex == 1) {
                if (self.displayMode == DisplayModeRubbishBin) {
                    [[MEGASdkManager sharedMEGASdk] removeNode:self.node];
                } else {
                    [[MEGASdkManager sharedMEGASdk] moveNode:self.node newParent:[[MEGASdkManager sharedMEGASdk] rubbishNode]];
                }
                [self.navigationController popViewControllerAnimated:YES];
            }
            break;
        }
            
        case 2: {
            if (buttonIndex == 1) {
                NSNumber *transferTag = [[Helper downloadingNodes] objectForKey:self.node.base64Handle];
                if (transferTag != nil) {
                    [[MEGASdkManager sharedMEGASdk] cancelTransferByTag:transferTag.integerValue];
                }
            }
            break;
        }
            
        case 3: {
            [self.navigationController popViewControllerAnimated:YES];
            break;
        }
    }
}

#pragma mark - UIDocumentInteractionController

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return actions;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"NodeDetailsTableViewCellID"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"NodeDetailsTableViewCellID"];
    }
    
    //Is the same for all posibilities
    if (indexPath.row == 0) {
        if ([[Helper downloadingNodes] objectForKey:self.node.base64Handle] != nil) {
            [cell.imageView setImage:[UIImage imageNamed:@"download"]];
            [cell.textLabel setText:AMLocalizedString(@"queued", @"Queued")];
            return cell;
        } else {
            
            MOOfflineNode *offlineNode = [[MEGAStore shareInstance] fetchOfflineNodeWithFingerprint:[[MEGASdkManager sharedMEGASdk] fingerprintForNode:self.node]];
            
            if (offlineNode != nil) {
                [cell.imageView setImage:[UIImage imageNamed:@"downloaded"]];
                [cell.textLabel setText:AMLocalizedString(@"savedForOffline", @"Saved for offline")];
            } else {
                [cell.imageView setImage:[UIImage imageNamed:@"download"]];
                [cell.textLabel setText:AMLocalizedString(@"saveForOffline", @"Save for Offline")];
            }
        }
    }
    
    switch (accessType) {
        case MEGAShareTypeAccessReadWrite:
        case MEGAShareTypeAccessRead:
            switch (indexPath.row) {
                case 1:
                    [cell.imageView setImage:[UIImage imageNamed:@"copy"]];
                    [cell.textLabel setText:AMLocalizedString(@"copy", @"Copy")];
                    break;
                    
                case 2:
                    [cell.imageView setImage:[UIImage imageNamed:@"leaveShare"]];
                    [cell.textLabel setText:AMLocalizedString(@"leaveFolder", @"Leave")];
                    break;
            }
            break;
            
        case MEGAShareTypeAccessFull:
            switch (indexPath.row) {
                case 1:
                    [cell.imageView setImage:[UIImage imageNamed:@"copy"]];
                    [cell.textLabel setText:AMLocalizedString(@"copy", nil)];
                    break;
                
                case 2:
                    [cell.imageView setImage:[UIImage imageNamed:@"rename"]];
                    [cell.textLabel setText:AMLocalizedString(@"rename", nil)];
                    break;
                    
                case 3:
                    if (self.displayMode == DisplayModeCloudDrive) {
                        [cell.imageView setImage:[UIImage imageNamed:@"remove"]];
                        [cell.textLabel setText:AMLocalizedString(@"remove", nil)];
                    } else {
                        [cell.imageView setImage:[UIImage imageNamed:@"leaveShare"]];
                        [cell.textLabel setText:AMLocalizedString(@"leaveFolder", @"Leave")];
                    }
                    
                    break;
            }
            break;
            
        case MEGAShareTypeAccessOwner:
            if (self.displayMode == DisplayModeCloudDrive) {
                switch (indexPath.row) {
                    case 1:
                        [cell.imageView setImage:[UIImage imageNamed:@"move"]];
                        [cell.textLabel setText:AMLocalizedString(@"move", nil)];
                        break;
                        
                    case 2:
                        [cell.imageView setImage:[UIImage imageNamed:@"copy"]];
                        [cell.textLabel setText:AMLocalizedString(@"copy", nil)];
                        break;
                        
                    case 3:
                        [cell.imageView setImage:[UIImage imageNamed:@"rename"]];
                        [cell.textLabel setText:AMLocalizedString(@"rename", nil)];
                        break;
                        
                    case 4:
                        [cell.imageView setImage:[UIImage imageNamed:@"rubbishBin"]];
                        [cell.textLabel setText:AMLocalizedString(@"moveToTheRubbishBin", @"Move to the rubbish bin")];
                        break;
                }
                // Rubbish bin
            } else {
                switch (indexPath.row) {
                    case 1:
                        [cell.imageView setImage:[UIImage imageNamed:@"move"]];
                        [cell.textLabel setText:AMLocalizedString(@"move", nil)];
                        break;
                        
                    case 2:
                        [cell.imageView setImage:[UIImage imageNamed:@"copy"]];
                        [cell.textLabel setText:AMLocalizedString(@"copy", nil)];
                        break;
                        
                    case 3:
                        [cell.imageView setImage:[UIImage imageNamed:@"rename"]];
                        [cell.textLabel setText:AMLocalizedString(@"rename", nil)];
                        break;
                        
                    case 4:
                        [cell.imageView setImage:[UIImage imageNamed:@"remove"]];
                        [cell.textLabel setText:AMLocalizedString(@"remove", nil)];
                        break;
                }
            }
            
            break;
            
        default:
            break;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    switch (indexPath.row) {
        case 0: { //Save for Offline
            if ([[Helper downloadingNodes] objectForKey:self.node.base64Handle] != nil) {
                if (!cancelDownloadAlertView) {
                    cancelDownloadAlertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"downloading", @"Downloading...")
                                                                         message:AMLocalizedString(@"cancelDownloadAlertViewText", @"Do you want to cancel the download?")
                                                                        delegate:self
                                                               cancelButtonTitle:AMLocalizedString(@"cancel", nil)
                                                               otherButtonTitles:AMLocalizedString(@"ok", nil), nil];
                }
                [cancelDownloadAlertView setTag:2];
                [cancelDownloadAlertView show];
            } else {
                MOOfflineNode *offlineNodeExist = [[MEGAStore shareInstance] fetchOfflineNodeWithFingerprint:[[MEGASdkManager sharedMEGASdk] fingerprintForNode:self.node]];
                if (!offlineNodeExist) {
                    [self download];
                }
            }
            break;
        }
            
        case 1: {
            switch (accessType) {
                case MEGAShareTypeAccessRead:
                case MEGAShareTypeAccessReadWrite:
                case MEGAShareTypeAccessFull:
                    [self browserWithAction:BrowserActionCopy];
                    break;
                    
                case MEGAShareTypeAccessOwner:
                    [self browserWithAction:BrowserActionMove];
                    break;
                    
                default:
                    break;
            }
            break;
        }
            
        case 2: {
            switch (accessType) {
                case MEGAShareTypeAccessRead:
                case MEGAShareTypeAccessReadWrite:
                    [self delete];
                    break;
                    
                case MEGAShareTypeAccessFull:
                    [self rename];
                    break;
                    
                case MEGAShareTypeAccessOwner:
                    [self browserWithAction:BrowserActionCopy];
                    break;
                    
                default:
                    break;
            }
            break;
        }
            
        case 3: {
            switch (accessType) {
                case MEGAShareTypeAccessFull:
                    [self delete];
                    break;
                    
                case MEGAShareTypeAccessOwner:
                    [self rename];
                    break;
                    
                default:
                    break;
            }
            break;
        }
            
        case 4: //Move to the Rubbish Bin / Remove
            [self delete];
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    NSString *nodeName = [textField text];
    UITextPosition *beginning = textField.beginningOfDocument;
    UITextRange *textRange;
    
    switch ([self.node type]) {
        case MEGANodeTypeFile: {
            if ([[nodeName pathExtension] isEqualToString:@""] && [nodeName isEqualToString:[nodeName stringByDeletingPathExtension]]) { //File without extension
                UITextPosition *end = textField.endOfDocument;
                textRange = [textField textRangeFromPosition:beginning  toPosition:end];
            } else {
                NSRange filenameRange = [nodeName rangeOfString:@"." options:NSBackwardsSearch];
                UITextPosition *beforeExtension = [textField positionFromPosition:beginning offset:filenameRange.location];
                textRange = [textField textRangeFromPosition:beginning  toPosition:beforeExtension];
            }
            [textField setSelectedTextRange:textRange];
            break;
        }
            
        case MEGANodeTypeFolder: {
            UITextPosition *end = textField.endOfDocument;
            textRange = [textField textRangeFromPosition:beginning  toPosition:end];
            [textField setSelectedTextRange:textRange];
            break;
        }
            
        default:
            break;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    BOOL shouldChangeCharacters = YES;
    switch ([self.node type]) {
        case MEGANodeTypeFile: {
            NSString *textFieldString = [textField text];
            NSString *newName = [textFieldString stringByReplacingCharactersInRange:range withString:string];
            NSString *newNameExtension = [newName pathExtension];
            NSString *newNameWithoutExtension = [newName stringByDeletingPathExtension];
            
            NSString *nodeNameString = [self.node name];
            NSString *nodeNameExtension = [NSString stringWithFormat:@".%@", [nodeNameString pathExtension]];
            
            NSRange nodeWithoutExtensionRange = [[textFieldString stringByDeletingPathExtension] rangeOfString:[textFieldString stringByDeletingPathExtension]];
            NSRange nodeExtensionStartRange = [textFieldString rangeOfString:@"." options:NSBackwardsSearch];
            
            if ((range.location > nodeExtensionStartRange.location) ||
                (range.length > nodeWithoutExtensionRange.length) ||
                ([newName isEqualToString:newNameExtension] && [newNameWithoutExtension isEqualToString:nodeNameExtension]) ||
                ((range.location == nodeExtensionStartRange.location) && [string isEqualToString:@""])) {
                
                UITextPosition *beginning = textField.beginningOfDocument;
                UITextPosition *beforeExtension = [textField positionFromPosition:beginning offset:nodeExtensionStartRange.location];
                [textField setSelectedTextRange:[textField textRangeFromPosition:beginning toPosition:beforeExtension]];
                shouldChangeCharacters = NO;
            } else if (range.location < nodeExtensionStartRange.location) {
                shouldChangeCharacters = YES;
            }
            break;
        }
            
        case MEGANodeTypeFolder:
            shouldChangeCharacters = YES;
            break;
            
        default:
            shouldChangeCharacters = NO;
            break;
    }
    
    return shouldChangeCharacters;
}

#pragma mark - MEGARequestDelegate

- (void)onRequestStart:(MEGASdk *)api request:(MEGARequest *)request {
    
}

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if ([error type]) {
        return;
    }
    
    switch ([request type]) {
            
        case MEGARequestTypeGetAttrFile: {
            if ([request nodeHandle] == [self.node handle]) {
                MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:[request nodeHandle]];
                NSString *thumbnailFilePath = [Helper pathForNode:node searchPath:NSCachesDirectory directory:@"thumbnailsV3"];
                BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath];
                if (fileExists) {
                    [self.thumbnailImageView setImage:[UIImage imageWithContentsOfFile:thumbnailFilePath]];
                }
            }
            break;
        }
        case MEGARequestTypeExport: {
            //If export link
            if ([request access]) {
                [SVProgressHUD dismiss];
                
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                [pasteboard setString:[request link]];
                [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"linkCopied", @"Message shown when the link has been copied to the pasteboard")];
                
            } else { //Disable link
                [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"removeLinkSuccess", @"Message shown inside an alert if the user remove a link")];
            }
            
            break;
        }
            
        case MEGARequestTypeCancelTransfer:
            [self.tableView reloadData];
            [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"transferCanceled", @"Transfer canceled!")];
            break;
            
        default:
            break;
    }
}

- (void)onRequestUpdate:(MEGASdk *)api request:(MEGARequest *)request {
}

- (void)onRequestTemporaryError:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
}

#pragma mark - MEGAGlobalDelegate

- (void)onUsersUpdate:(MEGASdk *)api userList:(MEGAUserList *)userList{
}

- (void)onReloadNeeded:(MEGASdk *)api {
}

- (void)onNodesUpdate:(MEGASdk *)api nodeList:(MEGANodeList *)nodeList {
    MEGANode *nodeUpdated;
    
    NSUInteger size = [[nodeList size] unsignedIntegerValue];
    for (NSUInteger i = 0; i < size; i++) {
        nodeUpdated = [nodeList nodeAtIndex:i];
        
        if ([nodeUpdated handle] == [self.node handle]) {
            [self showWarningAfterActionOnNode:nodeUpdated];
            break;
        }
    }
}

#pragma mark - MEGATransferDelegate

- (void)onTransferStart:(MEGASdk *)api transfer:(MEGATransfer *)transfer {
    if (transfer.type == MEGATransferTypeUpload) {
        return;
    }
    
    if (transfer.type == MEGATransferTypeDownload) {
        NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
        NSNumber *transferTag = [[Helper downloadingNodes] objectForKey:base64Handle];
        if (([transferTag integerValue] == transfer.tag) && ([self.node.base64Handle isEqualToString:base64Handle])) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            [cell.textLabel setText:AMLocalizedString(@"queued", @"Queued")];
        }
    }
}

- (void)onTransferUpdate:(MEGASdk *)api transfer:(MEGATransfer *)transfer {
    if (transfer.type == MEGATransferTypeUpload) {
        return;
    }
    
    if (transfer.type == MEGATransferTypeDownload) {
        NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
        NSNumber *transferTag = [[Helper downloadingNodes] objectForKey:base64Handle];
        if (([transferTag integerValue] == transfer.tag) && ([self.node.base64Handle isEqualToString:base64Handle])) {
            float percentage = ([[transfer transferredBytes] floatValue] / [[transfer totalBytes] floatValue] * 100);
            NSString *percentageCompleted = [NSString stringWithFormat:@"%.f%%", percentage];
            NSString *speed = [NSString stringWithFormat:@"%@/s", [NSByteCountFormatter stringFromByteCount:[[transfer speed] longLongValue]  countStyle:NSByteCountFormatterCountStyleMemory]];
            
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            [cell.textLabel setText:[NSString stringWithFormat:@"%@ • %@", percentageCompleted, speed]];
        }
    }
}

- (void)onTransferFinish:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error {
    if ([error type] || ([transfer type] == MEGATransferTypeUpload)) {
        return;
    }
    
    if (transfer.type == MEGATransferTypeDownload) {
        NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
        MOOfflineNode *offlineNode = [[MEGAStore shareInstance] fetchOfflineNodeWithBase64Handle:self.node.base64Handle];
        if ((offlineNode != nil) && ([self.node.base64Handle isEqualToString:base64Handle])) {
            if (cancelDownloadAlertView.visible) {
                [cancelDownloadAlertView dismissWithClickedButtonIndex:0 animated:YES];
            }
            
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:0];
            [cell.textLabel setText:AMLocalizedString(@"savedForOffline", @"Saved for offline")];
            [self.tableView reloadData];
        }
    }
}

-(void)onTransferTemporaryError:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error {
}

@end
