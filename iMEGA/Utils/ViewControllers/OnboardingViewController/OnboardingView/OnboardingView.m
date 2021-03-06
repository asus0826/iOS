
#import "OnboardingView.h"

@interface OnboardingView ()

@property (nonatomic) UIView *customView;

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *optionalLabel;

@end

@implementation OnboardingView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self customInit];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self customInit];
    }
    
    return self;
}

- (void)prepareForInterfaceBuilder {
    [super prepareForInterfaceBuilder];
    [self customInit];
    [self.customView prepareForInterfaceBuilder];
}

#pragma mark - Private

- (void)customInit {
    self.customView = [[NSBundle bundleForClass:self.class] loadNibNamed:@"OnboardingView" owner:self options:nil].firstObject;
    [self addSubview:self.customView];
    self.customView.frame = self.bounds;
    self.customView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

#pragma mark - Setters

- (void)setType:(OnboardingViewType)type {
    _type = type;
    switch (self.type) {
        case OnboardingViewTypeEncryptionInfo:
            self.imageView.image = [UIImage imageNamed:@"onboarding1_encryption"];
            self.titleLabel.text = AMLocalizedString(@"You hold the keys", @"Title shown in a page of the on boarding screens explaining that the user keeps the encryption keys");
            self.descriptionLabel.text = AMLocalizedString(@"Security is why we exist, your files are safe with us behind a well oiled encryption machine where only you can access your files.", @"Description shown in a page of the onboarding screens explaining the encryption paradigm");
            break;
            
        case OnboardingViewTypeChatInfo:
            self.imageView.image = [UIImage imageNamed:@"onboarding2_chat"];
            self.titleLabel.text = AMLocalizedString(@"Encrypted chat", @"Title shown in a page of the on boarding screens explaining that the chat is encrypted");
            self.descriptionLabel.text = AMLocalizedString(@"Fully encrypted chat with voice and video calls, group messaging and file sharing integration with your Cloud Drive.", @"Description shown in a page of the onboarding screens explaining the chat feature");
            break;
            
        case OnboardingViewTypeContactsInfo:
            self.imageView.image = [UIImage imageNamed:@"onboarding3_contacts"];
            self.titleLabel.text = AMLocalizedString(@"Create your Network", @"Title shown in a page of the on boarding screens explaining that the user can add contacts to chat and colaborate");
            self.descriptionLabel.text = AMLocalizedString(@"Add contacts, create a network, colaborate, make voice and video calls without ever leaving MEGA", @"Description shown in a page of the onboarding screens explaining contacts");
            break;
            
        case OnboardingViewTypeCameraUploadsInfo:
            self.imageView.image = [UIImage imageNamed:@"onboarding4_camera_uploads"];
            self.titleLabel.text = AMLocalizedString(@"Your Photos in the Cloud", @"Title shown in a page of the on boarding screens explaining that the user can backup the photos automatically");
            self.descriptionLabel.text = AMLocalizedString(@"Camera Uploads is an essential feature for any mobile device and we have got you covered. Create your account now.", @"Description shown in a page of the onboarding screens explaining the camera uploads feature");
            break;
            
        case OnboardingViewTypePhotosPermission:
            self.imageView.image = [UIImage imageNamed:@"photosPermission"];
            self.imageView.contentMode = UIViewContentModeCenter;
            self.titleLabel.text = AMLocalizedString(@"Allow Access to Photos", @"Title label that explains that the user is going to be asked for the photos permission");
            self.descriptionLabel.text = AMLocalizedString(@"Please give the MEGA App permission to access Photos to share photos and videos.", @"Detailed explanation of why the user should give permission to access to the photos");
            break;
            
        case OnboardingViewTypeMicrophoneAndCameraPermissions:
            self.imageView.image = [UIImage imageNamed:@"groupChat"];
            self.imageView.contentMode = UIViewContentModeCenter;
            self.titleLabel.text = AMLocalizedString(@"Enable Microphone and Camera", @"Title label that explains that the user is going to be asked for the microphone and camera permission");
            self.descriptionLabel.text = AMLocalizedString(@"To make encrypted voice and video calls, allow MEGA access to your Camera and Microphone", @"Detailed explanation of why the user should give permission to access to the camera and the microphone");
            break;
     
        case OnboardingViewTypeNotificationsPermission:
            self.imageView.image = [UIImage imageNamed:@"micAndCamPermission"];
            self.imageView.contentMode = UIViewContentModeCenter;
            self.titleLabel.text = AMLocalizedString(@"Enable Notifications", @"Title label that explains that the user is going to be asked for the notifications permission");
            self.descriptionLabel.text = AMLocalizedString(@"We would like to send you notifications so you receive new messages on your device instantly.", @"Detailed explanation of why the user should give permission to deliver notifications");
            break;
            
        case OnboardingViewTypeContactsPermission:
            self.imageView.image = [UIImage imageNamed:@"access contact"];
            self.imageView.contentMode = UIViewContentModeCenter;
            self.titleLabel.text = AMLocalizedString(@"Enable Access to Your Address Book", @"Title label that explains that the user is going to be asked for the contacts permission ");
            self.descriptionLabel.text = AMLocalizedString(@"Easily discover contacts from your address book on MEGA.", @"Detailed explanation of why the user should give permission to contactsDetailed explanation of why the user should give permission to contacts");
            self.optionalLabel.text = AMLocalizedString(@"MEGA will not use this data for any other purpose and will never interact with your contacts without your consent.", @"Detailed explanation about MEGA not using the contacts data without permision ");
            self.optionalLabel.hidden = NO;
            break;
    }
}

@end
