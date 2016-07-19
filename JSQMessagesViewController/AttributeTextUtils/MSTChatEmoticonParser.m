//
//  MSTChatEmoticonParser.m
//  Mansinthe
//
//  Created by Euan Chan on 11/28/15.
//  Copyright © 2015 cncn.com. All rights reserved.
//

#import <NSAttributedString+YYText.h>
#import <libkern/OSAtomic.h>
#import "MSTChatEmoticonParser.h"

@interface MSTChatEmoticonParser ()

@property (strong, nonatomic) NSRegularExpression *emoticonParseRegex;

@end

@implementation MSTChatEmoticonParser {
    NSRegularExpression *_emoticonRegex;
    NSDictionary *_mapper;
    OSSpinLock _lock;
}

#define LOCK(...)           \
    OSSpinLockLock(&_lock); \
    __VA_ARGS__;            \
    OSSpinLockUnlock(&_lock);

- (instancetype)init
{
    if (self = [super init]) {
        _lock = OS_SPINLOCK_INIT;
    }
    return self;
}

//- (void)configureWithEmoticonParseRegexString:(NSString *)emoticonParseRegexString
//                  emoticonMapperPlistFilePath:(NSString *)emoticonMapperPlistFilePath
//{
//    NSDictionary *emoticonMapper = [[NSDictionary alloc] initWithContentsOfFile:emoticonMapperPlistFilePath];
//    self.emoticonParseRegex = [[NSRegularExpression alloc] initWithPattern:emoticonParseRegexString
//                                                                   options:NSRegularExpressionCaseInsensitive
//                                                                     error:nil];
//    self.emoticonMapper = emoticonMapper;
//}

- (NSDictionary *)emoticonMapper
{
    LOCK(NSDictionary *mapper = _mapper);
    return mapper;
}

- (NSRegularExpression *)emoticonRegex
{
    return _emoticonRegex;
}

- (void)setEmoticonMapper:(NSDictionary *)emoticonMapper
{
    LOCK(
        _mapper = emoticonMapper.copy;
        if (_mapper.count == 0) {
            _emoticonRegex = nil;
        } else {
            NSMutableString *pattern = @"(".mutableCopy;
            NSArray *allKeys = _mapper.allKeys;
            NSCharacterSet *charset = [NSCharacterSet characterSetWithCharactersInString:@"$^?+*.,#|{}[]()\\"];
            for (NSUInteger i = 0, max = allKeys.count; i < max; i++) {
                NSMutableString *one = [allKeys[i] mutableCopy];

                // escape regex characters
                for (NSUInteger ci = 0, cmax = one.length; ci < cmax; ci++) {
                    unichar c = [one characterAtIndex:ci];
                    if ([charset characterIsMember:c]) {
                        [one insertString:@"\\" atIndex:ci];
                        ci++;
                        cmax++;
                    }
                }

                [pattern appendString:one];
                if (i != max - 1) [pattern appendString:@"|"];
            }
            [pattern appendString:@")"];
            _emoticonRegex = [[NSRegularExpression alloc] initWithPattern:pattern options:kNilOptions error:nil];
        });
}

// correct the selected range during text replacement
- (NSRange)_replaceTextInRange:(NSRange)range withLength:(NSUInteger)length selectedRange:(NSRange)selectedRange
{
    // no change
    if (range.length == length) return selectedRange;
    // right
    if (range.location >= selectedRange.location + selectedRange.length) return selectedRange;
    // left
    if (selectedRange.location >= range.location + range.length) {
        selectedRange.location = selectedRange.location + length - range.length;
        return selectedRange;
    }
    // same
    if (NSEqualRanges(range, selectedRange)) {
        selectedRange.length = length;
        return selectedRange;
    }
    // one edge same
    if ((range.location == selectedRange.location && range.length < selectedRange.length) || (range.location + range.length == selectedRange.location + selectedRange.length && range.length < selectedRange.length)) {
        selectedRange.length = selectedRange.length + length - range.length;
        return selectedRange;
    }
    selectedRange.location = range.location + length;
    selectedRange.length = 0;
    return selectedRange;
}

- (BOOL)parseText:(NSMutableAttributedString *)text selectedRange:(NSRangePointer)range
{
    if (text.length == 0)
        return NO;

    NSDictionary *mapper;
    NSRegularExpression *regex;
    LOCK(mapper = _mapper; regex = _emoticonRegex;);
    if (mapper.count == 0 || regex == nil)
        return NO;

    NSArray *matches = [regex matchesInString:text.string options:kNilOptions range:NSMakeRange(0, text.length)];
    if (matches.count == 0)
        return NO;

    NSRange selectedRange = range ? *range : NSMakeRange(0, 0);
    NSUInteger cutLength = 0;
    for (NSUInteger i = 0, max = matches.count; i < max; i++) {
        NSTextCheckingResult *one = matches[i];
        NSRange oneRange = one.range;
        if (oneRange.length == 0)
            continue;

        oneRange.location -= cutLength;
        NSString *subStr = [text.string substringWithRange:oneRange];
        NSString *emoticonName = mapper[subStr];
        UIImage *emoticon = [UIImage imageNamed:emoticonName];
        if (!emoticon)
            continue;

        CGFloat fontSize = 12; // CoreText default value
        CTFontRef font = (__bridge CTFontRef)([text yy_attribute:NSFontAttributeName atIndex:oneRange.location]);
        if (font) fontSize = CTFontGetSize(font);
        NSMutableAttributedString *atr = [NSAttributedString yy_attachmentStringWithEmojiImage:emoticon fontSize:fontSize];
        [atr yy_setTextBackedString:[YYTextBackedString stringWithString:subStr] range:NSMakeRange(0, atr.length)];
        [text replaceCharactersInRange:oneRange withString:atr.string];
        [text yy_removeDiscontinuousAttributesInRange:NSMakeRange(oneRange.location, atr.length)];
        [text addAttributes:atr.yy_attributes range:NSMakeRange(oneRange.location, atr.length)];
        selectedRange = [self _replaceTextInRange:oneRange withLength:atr.length selectedRange:selectedRange];
        cutLength += oneRange.length - 1;
    }

    if (range)
        *range = selectedRange;

    return YES;
}

/*
///--------------------------------------
#pragma mark - YYTextParser
///--------------------------------------
- (BOOL)parseText:(NSMutableAttributedString *)text selectedRange:(NSRangePointer)range
{
    if (text.length == 0)
        return NO;

    NSDictionary *mapper;
    NSRegularExpression *regex;
    LOCK(mapper = _emoticonMapper; regex = _emoticonParseRegex;);
    if (mapper.count == 0 || regex == nil) return NO;

    NSArray *matches = [regex matchesInString:text.string options:kNilOptions range:NSMakeRange(0, text.length)];
    if (matches.count == 0) return NO;

    NSRange selectedRange = range ? *range : NSMakeRange(0, 0);
    NSUInteger cutLength = 0;
    for (NSUInteger i = 0, max = matches.count; i < max; i++) {
        NSTextCheckingResult *one = matches[i];
        NSRange oneRange = one.range;
        if (oneRange.length == 0) continue;
        oneRange.location -= cutLength;
        NSString *subStr = [text.string substringWithRange:oneRange];
        NSString *imageName = mapper[subStr];

        //如果当前获得key后面有多余的，这个需要记录下
        NSString *otherAppendStr = nil;
        if (!imageName) {
            // 匹配 /微笑哈哈哈 中的/微笑
            // 微信的表情没有结束符号,所以有可能会发现过长的只有头部才是表情的段，需要循环检测一次。微信最大表情特殊字符是8个长度，检测8次即可
            if (!imageName && subStr.length > 2) {
                NSUInteger maxDetctIndex = (subStr.length > 8 + 2) ? 8 : (subStr.length - 2);
                for (NSUInteger i = 0; i < maxDetctIndex; i++) {
                    imageName = mapper[[subStr substringToIndex:3 + i]];
                    if (imageName) {
                        otherAppendStr = [subStr substringWithRange:NSMakeRange(3 + i, subStr.length - 3 - i)];
                        break;
                    }
                }
            }
        }




        UIImage *emoticon = mapper[subStr];
        if (!emoticon)
            continue;

        CGFloat fontSize = 12; // CoreText default value
        CTFontRef font = (__bridge CTFontRef)([text yy_attribute:NSFontAttributeName atIndex:oneRange.location]);
        if (font) fontSize = CTFontGetSize(font);
        NSMutableAttributedString *atr = [NSAttributedString yy_attachmentStringWithEmojiImage:emoticon fontSize:fontSize];
        [atr yy_setTextBackedString:[YYTextBackedString stringWithString:subStr] range:NSMakeRange(0, atr.length)];
        [text replaceCharactersInRange:oneRange withString:atr.string];
        [text yy_removeDiscontinuousAttributesInRange:NSMakeRange(oneRange.location, atr.length)];
        [text addAttributes:atr.yy_attributes range:NSMakeRange(oneRange.location, atr.length)];
        selectedRange = [self _replaceTextInRange:oneRange withLength:atr.length selectedRange:selectedRange];
        cutLength += oneRange.length - 1;
    }
    if (range) *range = selectedRange;

    return YES;
}
*/
@end
