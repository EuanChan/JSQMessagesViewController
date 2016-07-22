//
//  MSTChatTextDetectorContext.h
//  Mansinthe
//
//  Created by Euan Chan on 11/28/15.
//  Copyright © 2015 cncn.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <YYText/YYTextAttribute.h>
#import <YYTextParser.h>

@interface MSTChatTextDetectorContext : NSObject

@property (strong, nonatomic, readonly) id<YYTextParser> emoticonParser;

@property (copy, nonatomic, readonly) NSDictionary *emoticonMapper;
@property (strong, nonatomic, readonly) NSRegularExpression *emoticonRegularExpression;

+ (instancetype)sharedInstance;

/**
 *
 *  @param emoticonParser 
 *  @discuss
 *    The key is a specified plain string, such as @":smile:".
 *    The value is a UIImage which will replace the specified plain string in text.
 *
 */
- (void)configureEmoticonParserWithDictMapper:(NSDictionary *)emoticonParser;

// 写成category
- (void)processEmoticonDetectorInAttributesText:(NSMutableAttributedString *)text attachmentHeight:(CGFloat)attachmentHeight;
- (void)processDataDetectorInAttributeText:(NSMutableAttributedString *)text withHighlightColor:(UIColor *)highlightColor inYYTextHighlight:(YYTextHighlight *)textHighlight;

@end
