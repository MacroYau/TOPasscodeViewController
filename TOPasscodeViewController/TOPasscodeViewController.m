//
//  TOPasscodeViewController.m
//  TOPasscodeViewControllerExample
//
//  Created by Tim Oliver on 5/15/17.
//  Copyright © 2017 Timothy Oliver. All rights reserved.
//

#import "TOPasscodeViewController.h"
#import "TOPasscodeView.h"
#import "TOPasscodeViewControllerAnimatedTransitioning.h"
#import "TOPasscodeKeypadView.h"
#import "TOPasscodeInputField.h"

@interface TOPasscodeViewController () <UIViewControllerTransitioningDelegate>

/* State */
@property (nonatomic, assign, readwrite) TOPasscodeType passcodeType;
@property (nonatomic, assign) CGFloat keyboardHeight;

/* Views */
@property (nonatomic, strong, readwrite) UIVisualEffectView *backgroundEffectView;
@property (nonatomic, strong, readwrite) UIView *backgroundView;
@property (nonatomic, strong, readwrite) TOPasscodeView *passcodeView;
@property (nonatomic, strong, readwrite) UIButton *biometricButton;
@property (nonatomic, strong, readwrite) UIButton *cancelButton;



@end

@implementation TOPasscodeViewController

#pragma mark - Instance Creation -

- (instancetype)initWithStyle:(TOPasscodeViewStyle)style passcodeType:(TOPasscodeType)type
{
    if (self = [super initWithNibName:nil bundle:nil]) {
        _style = style;
        _passcodeType = type;
        [self setUp];
    }

    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [self setUp];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

#pragma mark - View Setup -

- (void)setUp
{
    self.transitioningDelegate = self;
    self.view.backgroundColor = [UIColor clearColor];
    self.automaticallyPromptForBiometricValidation = NO;

    if (TOPasscodeViewStyleIsTranslucent(self.style)) {
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    }
    else {
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:)
                                                     name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)setUpBackgroundEffectViewForStyle:(TOPasscodeViewStyle)style
{
    BOOL translucent = TOPasscodeViewStyleIsTranslucent(style);

    // Return if it already exists when it should
    if (translucent && self.backgroundEffectView) { return; }

    // Return if it doesn't exist when it shouldn't
    if (!translucent && !self.backgroundEffectView) { return; }

    // Remove it if we're now opaque
    if (!translucent) {
        [self.backgroundEffectView removeFromSuperview];
        self.backgroundEffectView = nil;
        return;
    }

    // Create it otherwise
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:[self blurEffectStyleForStyle:style]];
    self.backgroundEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.backgroundEffectView.frame = self.view.bounds;
    self.backgroundEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.backgroundEffectView atIndex:0];
}

- (void)setUpBackgroundViewForStyle:(TOPasscodeViewStyle)style
{
    BOOL translucent = TOPasscodeViewStyleIsTranslucent(style);

    if (!translucent && self.backgroundView) { return; }

    if (translucent && !self.backgroundView) { return; }

    if (translucent) {
        [self.backgroundView removeFromSuperview];
        self.backgroundView = nil;
        return;
    }

    self.backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.backgroundView atIndex:0];
}

- (UIBlurEffectStyle)blurEffectStyleForStyle:(TOPasscodeViewStyle)style
{
    switch (self.style) {
        case TOPasscodeViewStyleTranslucentDark: return UIBlurEffectStyleDark;
        case TOPasscodeViewStyleTranslucentLight: return UIBlurEffectStyleExtraLight;
        default: return 0;
    }

    return 0;
}

- (void)setUpAccessoryButtons
{
    UIFont *buttonFont = [UIFont systemFontOfSize:16.0f];
    BOOL isPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;

    if (!self.leftAccessoryButton && self.allowBiometricValidation && !self.biometricButton) {
        self.biometricButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.biometricButton setTitle:@"Touch ID" forState:UIControlStateNormal];
        [self.biometricButton addTarget:self action:@selector(accessoryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        if (isPad) {
            self.passcodeView.leftButton = self.biometricButton;
        }
        else {
            [self.view addSubview:self.biometricButton];
        }
    }
    else {
        if (self.leftAccessoryButton) {
            [self.biometricButton removeFromSuperview];
            self.biometricButton = nil;
        }
    }

    if (!self.rightAccessoryButton && !self.cancelButton) {
        self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.cancelButton setTitle:NSLocalizedString(@"Cancel", @"Cancel") forState:UIControlStateNormal];
        self.cancelButton.titleLabel.font = buttonFont;
        [self.cancelButton addTarget:self action:@selector(accessoryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        if (isPad) {
            self.passcodeView.rightButton = self.cancelButton;
        }
        else {
            [self.view addSubview:self.cancelButton];
        }
    }
    else {
        if (self.rightAccessoryButton) {
            [self.cancelButton removeFromSuperview];
            self.cancelButton = nil;
        }
    }

    [self updateAccessoryButtonFontsForWidth:self.view.bounds.size.width];
}

#pragma mark - View Management -
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.layer.allowsGroupOpacity = NO;
    [self setUpBackgroundEffectViewForStyle:self.style];
    [self setUpBackgroundViewForStyle:self.style];
    [self setUpAccessoryButtons];
    [self applyThemeForStyle:self.style];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // Automatically trigger biometric validation if available
    if (self.allowBiometricValidation && self.automaticallyPromptForBiometricValidation) {
        [self accessoryButtonTapped:self.biometricButton];
    }
}

- (void)viewDidLayoutSubviews
{
    CGSize bounds = self.view.bounds.size;

    // Update the accessory button sizes
    [self updateAccessoryButtonFontsForWidth:bounds.width];

    // Re-layout the accessory buttons
    [self layoutAccessoryButtonsForWidth:bounds.width];

    // Resize the pin view to scale to the new size
    [self.passcodeView sizeToFitWidth:bounds.width];

    // Re-center the pin view
    CGRect frame = self.passcodeView.frame;
    frame.origin.x = (bounds.width - frame.size.width) * 0.5f;
    frame.origin.y = ((bounds.height - self.keyboardHeight) - frame.size.height) * 0.5f;
    self.passcodeView.frame = CGRectIntegral(frame);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setNeedsStatusBarAppearanceUpdate];

    // Force an initial layout if the view hasn't been presented yet
    [UIView performWithoutAnimation:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];

    // Show the keyboard if we're
    if (self.passcodeType == TOPasscodeTypeCustomAlphanumeric) {
        [self.passcodeView.inputField becomeFirstResponder];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    // Dismiss the keyboard if it is visible
    if (self.passcodeView.inputField.isFirstResponder) {
        [self.passcodeView.inputField resignFirstResponder];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return TOPasscodeViewStyleIsDark(self.style) ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

#pragma mark - View Styling -
- (void)applyThemeForStyle:(TOPasscodeViewStyle)style
{
    BOOL isDark = TOPasscodeViewStyleIsDark(style);

    // Apply the tint color to the accessory buttons
    UIColor *accessoryTintColor = self.accessoryButtonTintColor;
    if (!accessoryTintColor) {
        accessoryTintColor = isDark ? [UIColor whiteColor] : nil;
    }

    self.biometricButton.tintColor = accessoryTintColor;
    self.cancelButton.tintColor = accessoryTintColor;
    self.leftAccessoryButton.tintColor = accessoryTintColor;
    self.rightAccessoryButton.tintColor = accessoryTintColor;

    self.backgroundView.backgroundColor = isDark ? [UIColor colorWithWhite:0.1f alpha:1.0f] : [UIColor whiteColor];
}

- (void)updateAccessoryButtonFontsForWidth:(CGFloat)width
{
    CGFloat pointSize = 17.0f;
    if (width < TOPasscodeViewContentSizeMedium) {
        pointSize = 14.0f;
    }
    else if (width < TOPasscodeViewContentSizeDefault) {
        pointSize = 16.0f;
    }

    UIFont *accessoryFont = [UIFont systemFontOfSize:pointSize];

    self.biometricButton.titleLabel.font = accessoryFont;
    self.cancelButton.titleLabel.font = accessoryFont;
    self.leftAccessoryButton.titleLabel.font = accessoryFont;
    self.rightAccessoryButton.titleLabel.font = accessoryFont;
}

- (void)layoutAccessoryButtonsForWidth:(CGFloat)width
{
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone) { return; }

    CGFloat verticalInset = 54.0f;
    if (width < TOPasscodeViewContentSizeMedium) {
        verticalInset = 37.0f;
    }
    else if (width < TOPasscodeViewContentSizeDefault) {
        verticalInset = 43.0f;
    }

    CGFloat inset = self.passcodeView.keypadButtonInset;
    CGPoint point = (CGPoint){0.0f, (self.view.bounds.size.height - self.keyboardHeight) - verticalInset};

    UIButton *leftButton = self.leftAccessoryButton ? self.leftAccessoryButton : self.biometricButton;
    if (leftButton) {
        [leftButton sizeToFit];
        point.x = self.passcodeView.frame.origin.x + inset;
        leftButton.center = point;
    }

    UIButton *rightButton = self.rightAccessoryButton ? self.rightAccessoryButton : self.cancelButton;
    if (rightButton) {
        [rightButton sizeToFit];
        point.x = CGRectGetMaxX(self.passcodeView.frame) - inset;
        rightButton.center = point;
    }
}

#pragma mark - Interactions -
- (void)accessoryButtonTapped:(id)sender
{
    if (sender == self.cancelButton) {
        // When entering keyboard input, just leave the button as 'cancel'
        if (self.passcodeType != TOPasscodeTypeCustomAlphanumeric && self.passcodeView.passcode.length > 0) {
            [self.passcodeView deleteLastPasscodeCharacterAnimated:YES];
            [self keypadButtonTapped];
            return;
        }

        if ([self.delegate respondsToSelector:@selector(didTapCancelInPasscodeViewController:)]) {
            [self.delegate didTapCancelInPasscodeViewController:self];
        }
    }
    else if (sender == self.biometricButton) {
        if ([self.delegate respondsToSelector:@selector(didPerformBiometricValidationRequestInPasscodeViewController:)]) {
            [self.delegate didPerformBiometricValidationRequestInPasscodeViewController:self];
        }
    }
}

- (void)keypadButtonTapped
{
    NSString *title = self.passcodeView.passcode.length > 0 ? @"Delete" : @"Cancel";
    [UIView performWithoutAnimation:^{
        [self.cancelButton setTitle:title forState:UIControlStateNormal];
    }];
}

- (void)didCompleteEnteringPasscode:(NSString *)passcode
{
    if (![self.delegate respondsToSelector:@selector(passcodeViewController:isCorrectCode:)]) {
        return;
    }

    // Validate the code
    BOOL isCorrect = [self.delegate passcodeViewController:self isCorrectCode:passcode];
    if (!isCorrect) {
        [self.passcodeView resetPasscodeAnimated:YES playImpact:YES];
        return;
    }

    // Perform handler if correctly entered
    if ([self.delegate respondsToSelector:@selector(didInputCorrectPasscodeInPasscodeViewController:)]) {
        [self.delegate didInputCorrectPasscodeInPasscodeViewController:self];
    }
    else {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Keyboard Handling -
- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    // Extract the keyboard information we need from the notification
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];
    UIViewAnimationOptions animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    // Work out the on-screen height of the keyboard
    self.keyboardHeight = self.view.bounds.size.height - keyboardFrame.origin.y;
    self.keyboardHeight = MAX(self.keyboardHeight, 0.0f);

    // Set that the view needs to be laid out
    [self.view setNeedsLayout];

    if (animationDuration < FLT_EPSILON) {
        return;
    }

    // Animate the content sliding up and down with the keyboard
    [UIView animateWithDuration:animationDuration
                          delay:0.0f
//         usingSpringWithDamping:1.0f
//          initialSpringVelocity:1.0f
                        options:animationCurve
                     animations:^{ [self.view layoutIfNeeded]; }
                     completion:nil];
}

#pragma mark - Transitioning Delegate -
- (nullable id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                            presentingController:(UIViewController *)presenting
                                                                                sourceController:(UIViewController *)source
{
    return [[TOPasscodeViewControllerAnimatedTransitioning alloc] initWithPasscodeViewController:self dismissing:NO];
}

- (nullable id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return [[TOPasscodeViewControllerAnimatedTransitioning alloc] initWithPasscodeViewController:self dismissing:YES];
}

#pragma mark - Public Accessors -
- (TOPasscodeView *)passcodeView
{
    if (_passcodeView) { return _passcodeView; }

    _passcodeView = [[TOPasscodeView alloc] initWithStyle:self.style passcodeType:self.passcodeType];
    _passcodeView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
                                    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [_passcodeView sizeToFit];
    _passcodeView.center = self.view.center;
    [self.view addSubview:_passcodeView];

    __weak typeof(self) weakSelf = self;
    _passcodeView.passcodeCompletedHandler = ^(NSString *passcode) {
        [weakSelf didCompleteEnteringPasscode:passcode];
    };

    _passcodeView.passcodeDigitEnteredHandler = ^{
        [weakSelf keypadButtonTapped];
    };

    return _passcodeView;
}

- (void)setStyle:(TOPasscodeViewStyle)style
{
    if (style == _style) { return; }
    _style = style;

    self.passcodeView.style = style;
    [self setUpBackgroundEffectViewForStyle:style];
}

- (void)setAllowBiometricValidation:(BOOL)allowBiometricValidation
{
    if (_allowBiometricValidation == allowBiometricValidation) {
        return;
    }

    _allowBiometricValidation = allowBiometricValidation;
    [self setUpAccessoryButtons];
    [self applyThemeForStyle:self.style];
}

- (void)setTitleLabelColor:(UIColor *)titleLabelColor
{
    self.passcodeView.titleLabelColor = titleLabelColor;
}

- (UIColor *)titleLabelColor { return self.passcodeView.titleLabelColor; }

- (void)setInputProgressViewTintColor:(UIColor *)inputProgressViewTintColor
{
    self.passcodeView.inputProgressViewTintColor = inputProgressViewTintColor;
}

- (UIColor *)inputProgressViewTintColor { return self.passcodeView.inputProgressViewTintColor; }

- (void)setkeypadButtonBackgroundTintColor:(UIColor *)keypadButtonBackgroundTintColor
{
    self.passcodeView.keypadButtonBackgroundColor = keypadButtonBackgroundTintColor;
}

- (UIColor *)keypadButtonBackgroundTintColor { return self.passcodeView.keypadButtonBackgroundColor; }

- (void)setKeypadButtonTextColor:(UIColor *)keypadButtonTextColor
{
    self.passcodeView.keypadButtonTextColor = keypadButtonTextColor;
}

- (UIColor *)keypadButtonTextColor { return self.passcodeView.keypadButtonTextColor; }

- (void)setKeypadButtonHighlightedTextColor:(UIColor *)keypadButtonHighlightedTextColor
{
    self.passcodeView.keypadButtonHighlightedTextColor = keypadButtonHighlightedTextColor;
}

- (UIColor *)keypadButtonHighlightedTextColor { return self.passcodeView.keypadButtonHighlightedTextColor; }

- (void)setAccessoryButtonTintColor:(UIColor *)accessoryButtonTintColor
{
    if (accessoryButtonTintColor == _accessoryButtonTintColor) { return; }
    _accessoryButtonTintColor = accessoryButtonTintColor;
    [self applyThemeForStyle:self.style];
}

@end
