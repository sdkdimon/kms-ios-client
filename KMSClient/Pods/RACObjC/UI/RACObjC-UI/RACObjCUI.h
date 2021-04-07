
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double RACObjCUIVersionNumber;

FOUNDATION_EXPORT const unsigned char RACObjCUIVersionString[];

#if TARGET_OS_WATCH
#elif TARGET_OS_IOS || TARGET_OS_TV
    #import <RACObjC/UIBarButtonItem+RACCommandSupport.h>
    #import <RACObjC/UIButton+RACCommandSupport.h>
    #import <RACObjC/UICollectionReusableView+RACSignalSupport.h>
    #import <RACObjC/UIControl+RACSignalSupport.h>
    #import <RACObjC/UIGestureRecognizer+RACSignalSupport.h>
    #import <RACObjC/UISegmentedControl+RACSignalSupport.h>
    #import <RACObjC/UITableViewCell+RACSignalSupport.h>
    #import <RACObjC/UITableViewHeaderFooterView+RACSignalSupport.h>
    #import <RACObjC/UITextField+RACSignalSupport.h>
    #import <RACObjC/UITextView+RACSignalSupport.h>

    #if TARGET_OS_IOS
        #import <RACObjC/MKAnnotationView+RACSignalSupport.h>
        #import <RACObjC/UIActionSheet+RACSignalSupport.h>
        #import <RACObjC/UIAlertView+RACSignalSupport.h>
        #import <RACObjC/UIDatePicker+RACSignalSupport.h>
        #import <RACObjC/UIImagePickerController+RACSignalSupport.h>
        #import <RACObjC/UIRefreshControl+RACCommandSupport.h>
        #import <RACObjC/UISlider+RACSignalSupport.h>
        #import <RACObjC/UIStepper+RACSignalSupport.h>
        #import <RACObjC/UISwitch+RACSignalSupport.h>
    #endif
#elif TARGET_OS_MAC
    #import <RACObjC/NSControl+RACCommandSupport.h>
    #import <RACObjC/NSControl+RACTextSignalSupport.h>
    #import <RACObjC/NSObject+RACAppKitBindings.h>
    #import <RACObjC/NSText+RACSignalSupport.h>
#endif
