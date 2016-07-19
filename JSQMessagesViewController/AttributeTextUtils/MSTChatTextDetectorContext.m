//
//  MSTChatTextDetectorContext.m
//  Mansinthe
//
//  Created by Euan Chan on 11/28/15.
//  Copyright © 2015 cncn.com. All rights reserved.
//

#import <YYCategories/YYCategories.h>
#import <YYText/NSAttributedString+YYText.h>
#import "MSTChatTextDetectorContext.h"
#import "MSTChatEmoticonParser.h"

@interface MSTChatTextDetectorContext ()

@property (strong, nonatomic) MSTChatEmoticonParser *theEmoticonParser;
@property (strong, nonatomic) NSDataDetector *contentDataDetector;

@end


@implementation MSTChatTextDetectorContext

+ (instancetype)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)configureEmoticonParserWithDictMapper:(NSDictionary *)emoticonPraser
{
    (self.theEmoticonParser).emoticonMapper = emoticonPraser;
}


- (void)processEmoticonDetectorInAttributesText:(NSMutableAttributedString *)text
{
    // 配置表情解析的映射表
    NSArray *emoticonResults = [self.emoticonRegularExpression
        matchesInString:text.string
                options:kNilOptions
                  range:text.yy_rangeOfAll];
    NSUInteger emoClipLength = 0;
    for (NSTextCheckingResult *emo in emoticonResults) {
        if (emo.range.location == NSNotFound && emo.range.length <= 1)
            continue;

        NSRange range = emo.range;
        range.location -= emoClipLength;
        if ([text yy_attribute:YYTextHighlightAttributeName atIndex:range.location])
            continue;
        if ([text yy_attribute:YYTextAttachmentAttributeName atIndex:range.location])
            continue;

        NSString *emoString = [text.string substringWithRange:range];
        NSString *imageName = self.emoticonMapper[emoString];
        UIImage *image = [UIImage imageNamed:imageName];
        if (!image)
            continue;

        CGFloat height = image.size.height;

        NSAttributedString *emoText = [NSAttributedString yy_attachmentStringWithEmojiImage:image fontSize:height];
        [text replaceCharactersInRange:range withAttributedString:emoText];
        emoClipLength += range.length - 1;
    }
}

- (void)processDataDetectorInAttributeText:(NSMutableAttributedString *)text withHighlightColor:(UIColor *)highlightColor inYYTextHighlight:(YYTextHighlight *)textHighlight
{
    [self.contentDataDetector
        enumerateMatchesInString:text.string
                         options:kNilOptions
                           range:NSMakeRange(0, text.length)
                      usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                          NSString *urlString = nil;
                          switch (result.resultType) {
                              case NSTextCheckingTypeLink:
                                  urlString = (result.URL).absoluteString;
                                  break;
                              case NSTextCheckingTypePhoneNumber:
                                  urlString = result.phoneNumber;
                                  break;
                              default:
                                  break;
                          }

                          if (urlString.length > 0) {
                              [text yy_setColor:highlightColor ?: UIColorHex(0x488BC7) range:result.range];
                              YYTextHighlight *highlight = textHighlight ? [textHighlight copy] : [[YYTextHighlight alloc] init];
                              highlight.userInfo = @{
                                  @"url" : urlString,
                                  @"type" : @(result.resultType)
                              };
                              [text yy_setTextHighlight:highlight range:result.range];
                          }
                      }];
}

///--------------------------------------
#pragma mark - getter & setter
///--------------------------------------

- (id<YYTextParser>)emoticonParser
{
    return self.theEmoticonParser;
}

- (NSDictionary *)emoticonMapper
{
    return self.theEmoticonParser.emoticonMapper;
}

- (NSRegularExpression *)emoticonRegularExpression
{
    return self.theEmoticonParser.emoticonRegex;
}

- (MSTChatEmoticonParser *)theEmoticonParser
{
    if (_theEmoticonParser == nil) {
        // default emoticon
        _theEmoticonParser = [[MSTChatEmoticonParser alloc] init];
        NSString *emoticonFilePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/Messages.bundle/expressionImage_custom.plist"];
        NSDictionary *emoticonMapperDict = [[NSDictionary alloc] initWithContentsOfFile:emoticonFilePath];
        NSMutableDictionary *emoticonImageMapperDict = [NSMutableDictionary dictionary];
        for (NSString *key in emoticonMapperDict.allKeys) {
            NSString *value = emoticonMapperDict[key];
            emoticonImageMapperDict[key] = value;
        }
        _theEmoticonParser.emoticonMapper = emoticonImageMapperDict;
    }
    return _theEmoticonParser;
}

- (NSDataDetector *)contentDataDetector
{
    if (_contentDataDetector == nil) {
        _contentDataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingAllSystemTypes error:nil];
    }
    return _contentDataDetector;
}

@end
