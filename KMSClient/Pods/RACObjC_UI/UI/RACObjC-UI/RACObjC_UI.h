
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double RACObjC_UIUIVersionNumber;

FOUNDATION_EXPORT const unsigned char RACObjC_UIUIVersionString[];

#if TARGET_OS_WATCH
#elif TARGET_OS_IOS || TARGET_OS_TV
    #import <RACObjC_UI/UIBarButtonItem+RACCommandSupport.h>
    #import <RACObjC_UI/UIButton+RACCommandSupport.h>
    #import <RACObjC_UI/UICollectionReusableView+RACSignalSupport.h>
    #import <RACObjC_UI/UIControl+RACSignalSupport.h>
    #import <RACObjC_UI/UIGestureRecognizer+RACSignalSupport.h>
    #import <RACObjC_UI/UISegmentedControl+RACSignalSupport.h>
    #import <RACObjC_UI/UITableViewCell+RACSignalSupport.h>
    #import <RACObjC_UI/UITableViewHeaderFooterView+RACSignalSupport.h>
    #import <RACObjC_UI/UITextField+RACSignalSupport.h>
    #import <RACObjC_UI/UITextView+RACSignalSupport.h>

    #if TARGET_OS_IOS
        #import <RACObjC_UI/MKAnnotationView+RACSignalSupport.h>
        #import <RACObjC_UI/UIActionSheet+RACSignalSupport.h>
        #import <RACObjC_UI/UIAlertView+RACSignalSupport.h>
        #import <RACObjC_UI/UIDatePicker+RACSignalSupport.h>
        #import <RACObjC_UI/UIImagePickerController+RACSignalSupport.h>
        #import <RACObjC_UI/UIRefreshControl+RACCommandSupport.h>
        #import <RACObjC_UI/UISlider+RACSignalSupport.h>
        #import <RACObjC_UI/UIStepper+RACSignalSupport.h>
        #import <RACObjC_UI/UISwitch+RACSignalSupport.h>
    #endif
#elif TARGET_OS_MAC
    #import <RACObjC_UI/NSControl+RACCommandSupport.h>
    #import <RACObjC_UI/NSControl+RACTextSignalSupport.h>
    #import <RACObjC_UI/NSObject+RACAppKitBindings.h>
    #import <RACObjC_UI/NSText+RACSignalSupport.h>
#endif
