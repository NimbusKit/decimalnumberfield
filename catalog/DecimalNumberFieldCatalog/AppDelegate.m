//
// Copyright 2014 Jeff Verkoeyen
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

#import "AppDelegate.h"

#import "MONDecimalNumberField.h"

@interface AppDelegate () <MONDecimalNumberFieldDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor whiteColor];

  UIViewController* vc = [[UIViewController alloc] init];
  self.window.rootViewController = vc;

  __block CGFloat topEdge = [UIApplication sharedApplication].statusBarFrame.size.height + 10;

  MONDecimalNumberField* (^createField)() = ^() {
    MONDecimalNumberField* field = [[MONDecimalNumberField alloc] init];
    field.delegate = self;
    CGFloat height = [field sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].height;
    field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    field.frame = CGRectMake(10, topEdge, vc.view.bounds.size.width - 20, floorf(height));
    [vc.view addSubview:field];

    topEdge = CGRectGetMaxY(field.frame) + 5;
    return field;
  };

  {
    MONDecimalNumberField* field = createField();
    field.labelFormat = @"Default: %@";
  }
  {
    MONDecimalNumberField* field = createField();
    field.value = [NSDecimalNumber decimalNumberWithString:@"100.32"];
    field.labelFormat = @"Initialized: %@";
  }
  {
    MONDecimalNumberField* field = createField();
    field.value = [NSDecimalNumber decimalNumberWithString:@"100.32"];
    field.clearsOnBeginEditing = NO;
    field.labelFormat = @"No Clear: %@";
  }
  {
    MONDecimalNumberField* field = createField();
    field.numberStyle = NSNumberFormatterCurrencyStyle;
    field.labelFormat = @"This Device's Currency: %@";
  }
  {
    MONDecimalNumberField* field = createField();
    field.numberStyle = NSNumberFormatterCurrencyStyle;
    NSArray* identifiers = [NSLocale availableLocaleIdentifiers];
    field.locale = [NSLocale localeWithLocaleIdentifier:identifiers[arc4random_uniform(identifiers.count)]];
    field.labelFormat = @"Random Currency: %@";
  }
  {
    MONDecimalNumberField* field = createField();
    field.numberStyle = NSNumberFormatterCurrencyStyle;
    field.allowDecimals = NO;
    field.value = [NSDecimalNumber decimalNumberWithString:@"100.52"];
    field.labelFormat = @"No Decimals: %@";
  }
  {
    MONDecimalNumberField* field = createField();
    field.numberStyle = NSNumberFormatterCurrencyStyle;
    field.stripZeroCents = NO;
    field.value = [NSDecimalNumber decimalNumberWithString:@"100.00"];
    field.labelFormat = @"No 0 strip: %@";
  }
  {
    MONDecimalNumberField* field = createField();
    field.numberStyle = NSNumberFormatterCurrencyStyle;
    field.maximumFractionDigits = 3;
    field.labelFormat = @"3 digit fractional currency: %@";
  }

  [self.window makeKeyAndVisible];
  return YES;
}

#pragma mark -
#pragma mark MONDecimalNumberFieldDelegate

- (void)decimalNumberField:(MONDecimalNumberField *)field didChangeValue:(NSDecimalNumber *)value {
  NSLog(@"%@", value);
}

@end
