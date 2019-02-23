
#import <Foundation/Foundation.h>

#pragma mark - global notifications

extern NSString * const MEGALogoutNotificationName;
extern NSString * const MEGANodesFetchDoneNotificationName;
extern NSString * const MEGAStorageOverQuotaNotificationName;
extern NSString * const MEGAStorageEventDidChangeNotificationName;

#pragma mark - global notification keys

extern NSString * const MEGAStorageEventStateUserInfoKey;

#pragma mark - camera upload notifications

extern NSString * const MEGACameraUploadAssetUploadDoneNotificationName;
extern NSString * const MEGACameraUploadPhotoUploadLocalDiskFullNotificationName;
extern NSString * const MEGACameraUploadVideoUploadLocalDiskFullNotificationName;
extern NSString * const MEGACameraUploadPhotoConcurrentCountChangedNotificationName;
extern NSString * const MEGACameraUploadVideoConcurrentCountChangedNotificationName;

#pragma mark - camera upload notification keys

extern NSString * const MEGAPhotoConcurrentCountUserInfoKey;
extern NSString * const MEGAVideoConcurrentCountUserInfoKey;

#pragma mark - camera upload constants

extern NSString * const MEGACameraUploadIdentifierSeparator;
extern const NSUInteger MEGACameraUploadLowDiskStorageSizeInBytes;

#pragma mark - file extension constants

extern NSString * const MEGAJPGFileExtension;
extern NSString * const MEGAMP4FileExtension;
extern NSString * const MEGAQuickTimeFileExtension;
