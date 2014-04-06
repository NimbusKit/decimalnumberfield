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

#import "NIDecimalNumberField.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "NimbusKit requires ARC support."
#endif

static const CGFloat kCaretWidth = 2; // Should this be variable based on the font?

// Calculated display metrics for the decimal number field.
@interface NIDecimalNumberFieldDisplayMetrics : NSObject
@property (nonatomic) CGSize boundingSize;
@property (nonatomic) CGRect frame;
@property (nonatomic) CGRect frameOfNumbers;
@property (nonatomic) CGRect frameOfDecimalPart; // Includes the decimal separator.
@property (nonatomic) NSRange rangeOfNumbers;
@property (nonatomic) NSRange rangeOfDecimalPart; // Includes the decimal separator.
@property (nonatomic) NSDictionary* attributes; // May differ from the original attributes due to scaling.
@property (nonatomic) UIEdgeInsets numberInset; // Insets of the decimals from the bounds.
@property (nonatomic) UIEdgeInsets decimalInset; // Insets specifically for the decimal values, if applicable.
@end

@implementation NIDecimalNumberFieldDisplayMetrics
@end

@interface NIDecimalNumberField () <UIKeyInput>
@end

@implementation NIDecimalNumberField {
  NSMutableString* _backingString;
  NSString* _displayString;

  UIView* _caretView;
  NSTimer* _caretTimer;

  NIDecimalNumberFieldDisplayMetrics* _displayMetrics;

  NSNumberFormatter* _numberFormatter;
  NSString* _decimalSeparator;

  BOOL _resetOnFirstModification;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor whiteColor];

    // Properties Affecting Display
    _locale = [NSLocale autoupdatingCurrentLocale];
    _font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _textColor = [UIColor blackColor];
    _textAlignment = NSTextAlignmentRight;
    _minimumScaleFactor = 0.5;
    _maximumIntegerDigits = NSUIntegerMax;
    _maximumFractionDigits = NSUIntegerMax;

    _numberFormatter = [[NSNumberFormatter alloc] init];
    _numberFormatter.locale = _locale;
    _numberFormatter.generatesDecimalNumbers = YES;
    [self refreshNumberFormatter];

    // Backing State
    _backingString = [NSMutableString string];

    // Views
    _caretView = [[UIView alloc] init];
    _caretView.backgroundColor = self.tintColor;
    _caretView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    _caretView.hidden = YES;
    [self addSubview:_caretView];

    // Public State
    self.allowDecimals = YES;
    self.stripZeroCents = YES;
    self.numberStyle = NSNumberFormatterNoStyle;

    // Private State
    _clearsOnBeginEditing = YES;

    // Handle locale changes so that we react to autoupdatingCurrentLocale changing from under us.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentLocaleDidChangeNotification:) name:NSCurrentLocaleDidChangeNotification object:nil];
  }
  return self;
}

#pragma mark -
#pragma mark UIView

- (CGSize)intrinsicContentSize {
  return CGSizeMake(UIViewNoIntrinsicMetric, [[self attributesForText][NSFontAttributeName] lineHeight]);
}

- (CGSize)sizeThatFits:(CGSize)size {
  NIDecimalNumberFieldDisplayMetrics* metrics = [self displayMetricsWithSize:size];
  return metrics.frame.size;
}

- (void)setNeedsDisplay {
  [super setNeedsDisplay];

  // Clear cached properties - they'll be recreated when we need them again.
  _displayString = nil;
  _displayMetrics = nil;
}

- (void)tintColorDidChange {
  [super tintColorDidChange];

  _caretView.backgroundColor = self.tintColor;
}

#pragma mark -
#pragma mark Rendering

- (void)drawRect:(CGRect)rect {
  [super drawRect:rect];
  NIDecimalNumberFieldDisplayMetrics* metrics = [self displayMetricsWithSize:self.bounds.size];

  // Draw the selection background.
  if (self.isFirstResponder && _resetOnFirstModification) {
    [[_caretView.backgroundColor colorWithAlphaComponent:0.25] setFill];
    CGContextRef cx = UIGraphicsGetCurrentContext();
    CGContextFillRect(cx, metrics.frameOfNumbers);
  }

  [[self displayString] drawInRect:metrics.frame withAttributes:metrics.attributes];
}

#pragma mark -
#pragma mark UIKeyInput

- (BOOL)hasText {
  return _backingString.length > 0;
}

- (void)insertText:(NSString *)text {
  [self changeCharactersInRange:NSMakeRange(_backingString.length, 0) replacementString:text];
  [self wakeCaret];
}

- (void)deleteBackward {
  if ([self hasText]) {
    [self changeCharactersInRange:NSMakeRange(_backingString.length - 1, 1) replacementString:@""];
  }
  [self wakeCaret];
}

#pragma mark -
#pragma mark UITextInputTraits

- (UIKeyboardType)keyboardType {
  return self.allowDecimals ? UIKeyboardTypeDecimalPad : UIKeyboardTypeNumberPad;
}

- (UITextAutocapitalizationType)autocapitalizationType {
  return UITextAutocapitalizationTypeNone;
}

- (UITextAutocorrectionType)autocorrectionType {
  return UITextAutocorrectionTypeNo;
}

#pragma mark -
#pragma mark UIResponder

- (BOOL)becomeFirstResponder {
  BOOL becomeFirstResponder = [super becomeFirstResponder] && self.enabled;
  if (becomeFirstResponder) {
    _resetOnFirstModification = self.clearsOnBeginEditing;
    [self didGainFocus];
    [self setNeedsDisplay];
  }
  return becomeFirstResponder;
}

- (BOOL)resignFirstResponder {
  BOOL resignFirstResponder = [super resignFirstResponder];
  if (resignFirstResponder) {
    _resetOnFirstModification = NO;
    [self didLoseFocus];
    [self setNeedsDisplay];
  }
  return resignFirstResponder;
}

- (BOOL)canBecomeFirstResponder {
  return self.enabled;
}

- (BOOL)canResignFirstResponder {
  return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  if ([self canBecomeFirstResponder]) {
    [self becomeFirstResponder];
  }
}

#pragma mark -
#pragma mark Notifications

- (void)currentLocaleDidChangeNotification:(NSNotification *)notification {
  NSString* oldDecimalSeparator = _decimalSeparator;

  [self refreshNumberFormatter];

  NSString* decimalSeparator = [self decimalSeparator];
  [_backingString replaceOccurrencesOfString:oldDecimalSeparator
                                  withString:decimalSeparator
                                     options:0
                                       range:NSMakeRange(0, _backingString.length)];

  [self setNeedsDisplay];
}

#pragma mark -
#pragma mark Private Methods (Number Formatter)

- (void)refreshNumberFormatter {
  _decimalSeparator = nil;

  NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
  formatter.locale = [NSLocale currentLocale];
  formatter.numberStyle = self.numberStyle;

  // We always display numbers in the user's current locale, even if the currency is in a foreign
  // locale.
  _numberFormatter.currencyGroupingSeparator = formatter.currencyGroupingSeparator;
  _numberFormatter.currencyDecimalSeparator = formatter.currencyDecimalSeparator;
  _numberFormatter.decimalSeparator = formatter.decimalSeparator;
  _numberFormatter.usesGroupingSeparator = formatter.usesGroupingSeparator;
  _numberFormatter.groupingSeparator = formatter.groupingSeparator;
  _numberFormatter.groupingSize = formatter.groupingSize;

  if (_numberFormatter.numberStyle == NSNumberFormatterDecimalStyle
      || _numberFormatter.numberStyle == NSNumberFormatterNoStyle) {
    _numberFormatter.maximumFractionDigits = (_maximumFractionDigits != NSUIntegerMax) ? _maximumFractionDigits : 6;
    _numberFormatter.maximumIntegerDigits = (_maximumIntegerDigits != NSUIntegerMax) ? _maximumIntegerDigits : 4;

  } else {
    _numberFormatter.maximumFractionDigits = (_maximumFractionDigits != NSUIntegerMax) ? _maximumFractionDigits : 2;
    _numberFormatter.maximumIntegerDigits = (_maximumIntegerDigits != NSUIntegerMax) ? _maximumIntegerDigits : 7;
    _numberFormatter.minimumFractionDigits = _numberFormatter.maximumFractionDigits;
  }

  [self setNeedsDisplay];
}

#pragma mark -
#pragma mark Private Methods (Focus)

- (void)didGainFocus {
  [self wakeCaret];
}

- (void)didLoseFocus {
  // Strip the trailing decimal separator.
  if ([_backingString hasSuffix:[self decimalSeparator]]) {
    NSInteger separatorLength = [self decimalSeparator].length;
    [_backingString deleteCharactersInRange:NSMakeRange(_backingString.length - separatorLength, separatorLength)];
  }

  [self sleepCaret];
}

#pragma mark -
#pragma mark Private Methods (Caret)

- (void)wakeCaret {
  // Only show the caret if we're focused and not highlighting the numbers.
  if (self.isFirstResponder && !_resetOnFirstModification) {
    [_caretTimer invalidate];
    _caretTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(caretTimerDidFire:) userInfo:nil repeats:YES];
    _caretView.hidden = NO;
    _caretView.alpha = 1;
  } else {
    [self sleepCaret];
  }
}

- (void)sleepCaret {
  [_caretTimer invalidate];
  _caretTimer = nil;
  _caretView.hidden = YES;
}

- (void)caretTimerDidFire:(NSTimer *)timer {
  if (_caretTimer == timer) {
    if (_caretView.hidden) {
      _caretView.hidden = NO;
      _caretView.alpha = 0;
      [UIView animateWithDuration:0.25 delay:0.1 options:0 animations:^{
        _caretView.alpha = 1;
      } completion:nil];
    } else {
      [UIView animateWithDuration:0.25 delay:0.1 options:0 animations:^{
        _caretView.alpha = 0;
      } completion:^(BOOL finished) {
        _caretView.hidden = YES;
      }];
    }
  } else {
    [timer invalidate];
    [self sleepCaret];
  }
}

#pragma mark -
#pragma mark Private Methods (String Modification)

- (void)changeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
  BOOL consumed = NO;
  BOOL shouldChange = NO;
  BOOL isDeleting = string.length == 0;
  BOOL isInserting = !isDeleting;
  NSDecimalNumber* originalValue = [self value];

  NSString* decimalSeparator = [self decimalSeparator];

  // Toss invalid characters ^[0-9.]. These can be typed by external keyboards.
  if (isInserting && ![string isEqualToString:decimalSeparator] && [string rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].length > 0) {
    consumed = YES;
  }

  // Ignore decimals when unwanted.
  if (!_allowDecimals && [string isEqualToString:decimalSeparator]) {
    consumed = YES;
  }

  // Replace everything on first modification.
  if (!consumed && _resetOnFirstModification) {
    range = NSMakeRange(0, _backingString.length);
    _resetOnFirstModification = NO;
    consumed = YES;
    shouldChange = YES;
  }

  // Toss leading zeros.
  if (!consumed && [string isEqualToString:@"0"] && _backingString.length == 0) {
    consumed = YES;
  }

  // Enforce max digit limits.
  if (!consumed && isInserting) {
    NSRange existingDotRange = [_backingString rangeOfString:decimalSeparator];
    if (existingDotRange.length > 0) {
      // Adding a decimal.
      if ([string isEqualToString:decimalSeparator]) {
        // Don't allow a second decimal separator to be added.
        consumed = YES;

      } else if (((existingDotRange.location + _numberFormatter.maximumFractionDigits)
                  < _backingString.length)) {
        // Enforce maximum number of fraction digits.
        consumed = YES;
      }

    } else if (![string isEqualToString:decimalSeparator]) {
      if (_numberFormatter.maximumIntegerDigits <= _backingString.length) {
        // Enforce maximum number of integer digits.
        consumed = YES;
      }
    }
  }

  if (!consumed || shouldChange) {
    [_backingString replaceCharactersInRange:range withString:string];
    NSDecimalNumber* newValue = [self value];
    if (![originalValue isEqualToNumber:newValue]) {
      [_delegate decimalNumberField:self didChangeValue:newValue];
    }
    [self setNeedsDisplay];
  }
}

#pragma mark -
#pragma mark Private Methods (String Display)

- (NSDictionary *)attributesForText {
  return @{NSFontAttributeName: _font,
           NSForegroundColorAttributeName: _textColor};
}

- (NSString *)displayString {
  if (nil == _displayString) {
    NSDecimalNumber* value = [self value];
    NSString* formattedString = [_numberFormatter stringFromNumber:value];

    if (self.numberStyle == NSNumberFormatterCurrencyStyle) {
      formattedString = [self stringMassagedFromCurrencyFormattedString:formattedString];

    } else if (self.numberStyle == NSNumberFormatterDecimalStyle
               || self.numberStyle == NSNumberFormatterNoStyle) {
      formattedString = [self stringMassagedFromDefaultFormattedString:formattedString];
    }

    if (self.labelFormat) {
      formattedString = [NSString stringWithFormat:self.labelFormat, formattedString];
    }

    _displayString = formattedString;
  }
  return _displayString;
}

- (void)calculateFontForDisplayMetrics:(NIDecimalNumberFieldDisplayMetrics *)metrics {
  // Calculate the scaled font size.
  NSMutableDictionary* attributes = [[self attributesForText] mutableCopy];
  UIFont* originalFont = [self attributesForText][NSFontAttributeName];
  CGFloat originalFontHeight = [originalFont pointSize];

  NSString* displayString = [self displayString];
  CGSize textSize;
  CGFloat scale = 1;
  do {
    textSize = [displayString sizeWithAttributes:attributes];
    if (textSize.width > metrics.boundingSize.width) {
      scale -= 0.05;

      UIFont* font = attributes[NSFontAttributeName];
      attributes[NSFontAttributeName] = [font fontWithSize:originalFont.pointSize * scale];
    } else {
      break;
    }
  } while(self.minimumScaleFactor > 0 && scale > self.minimumScaleFactor);

  CGFloat shrunkenFontHeight = [attributes[NSFontAttributeName] pointSize];
  CGFloat alignmentOffset = 0;
  if (_textAlignment == NSTextAlignmentRight) {
    alignmentOffset = self.bounds.size.width - textSize.width;
  } else if (_textAlignment == NSTextAlignmentCenter) {
    alignmentOffset = NICenterX(self.bounds.size, textSize);
  }

  metrics.frame = CGRectMake(alignmentOffset, originalFontHeight - shrunkenFontHeight,
                             textSize.width, textSize.height);
  metrics.attributes = attributes;
}

- (NIDecimalNumberFieldDisplayMetrics *)displayMetricsWithSize:(CGSize)size {
  if (nil == _displayMetrics || !CGSizeEqualToSize(_displayMetrics.boundingSize, size)) {
    NIDecimalNumberFieldDisplayMetrics* displayMetrics = [[NIDecimalNumberFieldDisplayMetrics alloc] init];
    displayMetrics.boundingSize = size;

    NSString* displayString = [self displayString];
    [self calculateFontForDisplayMetrics:displayMetrics];

    // Calculate ranges of digits and their corresponding frames.
    NSInteger lengthOfFormatting = displayString.length - (MAX(2, self.labelFormat.length) - 2);
    NSInteger formattingStart = self.labelFormat ? [self.labelFormat rangeOfString:@"%@"].location : 0;
    NSRange formattingRange = NSMakeRange(formattingStart, lengthOfFormatting);

    NSMutableCharacterSet* set = [[NSCharacterSet decimalDigitCharacterSet] mutableCopy];
    [set addCharactersInString:[self decimalSeparator]];

    // The numerical portion of the string.
    NSInteger numbersStart = [displayString rangeOfCharacterFromSet:set options:0 range:formattingRange].location;
    NSInteger numbersEnd = [displayString rangeOfCharacterFromSet:set options:NSBackwardsSearch range:formattingRange].location;
    displayMetrics.rangeOfNumbers = NSMakeRange(numbersStart, numbersEnd - numbersStart + 1);

    // The decimal portion of the numerical portion.
    NSInteger decimalLocation = [displayString rangeOfString:[self decimalSeparator] options:0 range:formattingRange].location;
    displayMetrics.rangeOfDecimalPart = NSMakeRange(decimalLocation, numbersEnd - decimalLocation + 1);

    // The frame for the numbers.
    CGFloat offsetToNumbers = [[displayString substringToIndex:displayMetrics.rangeOfNumbers.location] sizeWithAttributes:displayMetrics.attributes].width;
    CGFloat widthOfNumbers = [[displayString substringWithRange:displayMetrics.rangeOfNumbers] sizeWithAttributes:displayMetrics.attributes].width;
    displayMetrics.frameOfNumbers = CGRectMake(displayMetrics.frame.origin.x + offsetToNumbers, displayMetrics.frame.origin.y, widthOfNumbers, displayMetrics.frame.size.height);

    CGFloat caretOffset = 0;
    if (displayMetrics.rangeOfDecimalPart.location != NSNotFound) {
      // The frame for the decimal part.
      CGFloat offsetToDecimalPart = [[displayString substringToIndex:displayMetrics.rangeOfDecimalPart.location] sizeWithAttributes:displayMetrics.attributes].width;
      CGFloat widthOfDecimalPart = [[displayString substringWithRange:displayMetrics.rangeOfDecimalPart] sizeWithAttributes:displayMetrics.attributes].width;
      displayMetrics.frameOfDecimalPart = CGRectMake(displayMetrics.frame.origin.x + offsetToDecimalPart, displayMetrics.frame.origin.y, widthOfDecimalPart, displayMetrics.frame.size.height);

      // Calculate the negative offset of the caret if we're typing the decimal.
      // This is how we show the .|00 while the user is editing the decimals.
      NSRange backingDecimalRange = [_backingString rangeOfString:[self decimalSeparator]];
      if (backingDecimalRange.location != NSNotFound) {
        NSString* backedDecimalPart = [_backingString substringFromIndex:backingDecimalRange.location];
        CGFloat backedDecimalWidth = [backedDecimalPart sizeWithAttributes:displayMetrics.attributes].width;
        caretOffset = displayMetrics.frameOfDecimalPart.size.width - backedDecimalWidth;

      } else if (_numberFormatter.maximumFractionDigits != NSUIntegerMax) {
        // No backing decimal.
        caretOffset = displayMetrics.frameOfDecimalPart.size.width;
      }
    }
    _displayMetrics = displayMetrics;

    CGFloat caretHeight = floorf([displayMetrics.attributes[NSFontAttributeName] lineHeight]);
    _caretView.frame = CGRectMake(CGRectGetMaxX(displayMetrics.frameOfNumbers) - caretOffset,
                                  displayMetrics.frame.origin.y,
                                  kCaretWidth, caretHeight);
  }
  return _displayMetrics;
}

#pragma mark -
#pragma mark Private Methods (Formatting Decimals for Display)

- (NSString *)stringMassagedFromCurrencyFormattedString:(NSString *)formattedString {
  // Strip .00 when not focused.
  if (self.stripZeroCents) {
    NSString* decimalSeparator = [self decimalSeparator];
    BOOL hasDecimalSeparator = [_backingString rangeOfString:decimalSeparator].location != NSNotFound;

    BOOL isFocused = self.isFirstResponder;
    if (!(isFocused && hasDecimalSeparator)) {
      NSString* stripString = [decimalSeparator stringByAppendingString:[@"" stringByPaddingToLength:_numberFormatter.minimumFractionDigits withString:@"0" startingAtIndex:0]];
      NSRange range = [formattedString rangeOfString:stripString];
      if (range.location != NSNotFound) {
        NSString* firstPart = [formattedString substringToIndex:range.location];
        NSString* lastPart = [formattedString substringFromIndex:NSMaxRange(range)];
        formattedString = [firstPart stringByAppendingString:lastPart];
      }
    }
  }

  return formattedString;
}

- (NSString *)stringMassagedFromDefaultFormattedString:(NSString *)formattedString {
  // Add the decimal.
  if ([_backingString hasSuffix:[self decimalSeparator]]) {
    formattedString = [formattedString stringByAppendingString:[self decimalSeparator]];

  // Add trailing zeros.
  } else if ([_backingString hasSuffix:@"0"] && [_backingString rangeOfString:[self decimalSeparator]].location != NSNotFound) {
    NSCharacterSet* nonZeroSet = [[NSCharacterSet characterSetWithCharactersInString:@"0"] invertedSet];
    NSUInteger firstNonzeroCharacter = [_backingString rangeOfCharacterFromSet:nonZeroSet options:NSBackwardsSearch].location;
    if (firstNonzeroCharacter == NSNotFound) {
      formattedString = [formattedString stringByAppendingString:_backingString];
    } else if ([[_backingString substringWithRange:NSMakeRange(firstNonzeroCharacter, 1)] isEqualToString:[self decimalSeparator]]) {
      formattedString = [formattedString stringByAppendingString:[_backingString substringFromIndex:firstNonzeroCharacter]];
    } else {
      formattedString = [formattedString stringByAppendingString:[_backingString substringFromIndex:firstNonzeroCharacter + 1]];
    }
  }

  // Add the leading zero if it's missing.
  if ([_backingString hasPrefix:[self decimalSeparator]] && ![formattedString hasPrefix:@"0"]) {
    formattedString = [@"0" stringByAppendingString:formattedString];
  }
  return formattedString;
}

#pragma mark -
#pragma mark Private Methods

- (NSString *)textWithDecimalStrippedFromText:(NSString *)text {
  NSRange decimalRange = [text rangeOfString:[self decimalSeparator]];
  if (decimalRange.location != NSNotFound) {
    text = [_backingString substringToIndex:decimalRange.location];
  }
  return text;
}

- (NSString *)decimalSeparator {
  if (nil == _decimalSeparator) {
    _decimalSeparator = ((self.numberStyle == NSNumberFormatterCurrencyStyle)
                         ? _numberFormatter.currencyDecimalSeparator
                         : _numberFormatter.decimalSeparator);
  }
  return _decimalSeparator;
}

- (NSDictionary *)localeForDecimalNumbers {
  return @{NSLocaleDecimalSeparator: [self decimalSeparator]};
}

#pragma mark -
#pragma mark Public Methods

- (void)setValue:(NSDecimalNumber *)value {
  _backingString = [[value descriptionWithLocale:[self localeForDecimalNumbers]] mutableCopy];
  if (!self.allowDecimals) {
    _backingString = [[self textWithDecimalStrippedFromText:_backingString] mutableCopy];
  }
  [self setNeedsDisplay];
}

- (NSDecimalNumber *)value {
  return ((_backingString.length > 0)
          ? [NSDecimalNumber decimalNumberWithString:_backingString locale:[self localeForDecimalNumbers]]
          : [NSDecimalNumber zero]);

  // Note: NSDecimalNumber crashes if you give it a zero-length string.
  // We provide locale so that NSDecimalNumber can figure out the correct decimal separator.
}

- (void)setAllowDecimals:(BOOL)allowDecimals {
  _allowDecimals = allowDecimals;

  if (!_allowDecimals) {
    _backingString = [[self textWithDecimalStrippedFromText:_backingString] mutableCopy];
    [self setNeedsDisplay];
  }
}

- (void)setNumberStyle:(NSNumberFormatterStyle)numberStyle {
  if (numberStyle != NSNumberFormatterDecimalStyle
      && numberStyle != NSNumberFormatterCurrencyStyle
      && numberStyle != NSNumberFormatterNoStyle) {
    NSLog(@"Unsupported number style, defaulting to no style.");
    numberStyle = NSNumberFormatterNoStyle;
  }
  _numberFormatter.numberStyle = numberStyle;
  [self refreshNumberFormatter];
}

- (NSNumberFormatterStyle)numberStyle {
  return _numberFormatter.numberStyle;
}

- (void)setMaximumFractionDigits:(NSUInteger)maximumFractionDigits {
  _maximumFractionDigits = maximumFractionDigits;
  [self refreshNumberFormatter];
}

- (void)setMaximumIntegerDigits:(NSUInteger)maximumIntegerDigits {
  _maximumIntegerDigits = maximumIntegerDigits;
  [self refreshNumberFormatter];
}

- (void)setStripZeroCents:(BOOL)stripZeroCents {
  _stripZeroCents = stripZeroCents;
  [self setNeedsDisplay];
}

- (void)setLabelFormat:(NSString *)labelFormat {
  _labelFormat = [labelFormat copy];
  [self setNeedsDisplay];
}

- (void)setLocale:(NSLocale *)locale {
  _locale = locale;
  _numberFormatter.locale = _locale;
  _decimalSeparator = nil;
  [self refreshNumberFormatter];
  [self setNeedsDisplay];
}

- (void)setFont:(UIFont *)font {
  _font = font;
  [self setNeedsDisplay];
}

- (void)setTextColor:(UIColor *)textColor {
  _textColor = textColor;
  [self setNeedsDisplay];
}

@end
