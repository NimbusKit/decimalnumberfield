//
// Copyright 2011-2014 NimbusKit
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <UIKit/UIKit.h>

@protocol NIDecimalNumberFieldDelegate;

/**
 * The NIDecimalNumberField class provides a control that allows a user to input formatted decimal
 * numbers using a decimal keyboard.
 */
@interface NIDecimalNumberField : UIControl

@property (nonatomic, strong) NSDecimalNumber*        value;

// Display Properties
@property (nonatomic, strong) UIColor*                textColor;            // default: [UIColor blackColor]
@property (nonatomic, strong) UIFont*                 font;                 // default: [UIFont preferredFontForTextStyle:UIFontTextStyleBody]
@property (nonatomic)         CGFloat                 minimumScaleFactor;   // default: 0.5
@property (nonatomic)         NSTextAlignment         textAlignment;        // default: NSTextAlignmentRight
@property (nonatomic, copy)   NSString*               labelFormat;          // default: nil

// User Experience
@property (nonatomic)         BOOL                    clearsOnBeginEditing; // default: YES

// Decimal Number Formatting
@property (nonatomic)         NSNumberFormatterStyle  numberStyle;          // default: NSNumberFormatterNoStyle
@property (nonatomic, strong) NSLocale*               locale;               // default: [NSLocale autoupdatingCurrentLocale]
@property (nonatomic)         BOOL                    allowDecimals;        // default: YES
@property (nonatomic)         BOOL                    stripZeroCents;       // default: YES
@property (nonatomic)         NSUInteger              maximumIntegerDigits; // default: NSUIntegerMax
@property (nonatomic)         NSUInteger              maximumFractionDigits;// default: NSUIntegerMax

@property (nonatomic, weak) id<NIDecimalNumberFieldDelegate> delegate;

@end

@protocol NIDecimalNumberFieldDelegate <NSObject>
@required

- (void)decimalNumberField:(NIDecimalNumberField *)field didChangeValue:(NSDecimalNumber *)value;

@end
