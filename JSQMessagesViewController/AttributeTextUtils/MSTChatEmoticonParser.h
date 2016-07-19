//
//  MSTChatEmoticonParser.h
//  Mansinthe
//
//  Created by Euan Chan on 11/28/15.
//  Copyright © 2015 cncn.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <YYTextParser.h>

@interface MSTChatEmoticonParser : NSObject <YYTextParser>

/**
 *  表情搜索正则
 */
@property (strong, nonatomic, readonly) NSRegularExpression *emoticonRegex;

/**
 *  表情转义符对应的表情图片名称转换表（plist 格式文件）
 */
@property (copy, nonatomic) NSDictionary *emoticonMapper;

//- (void)configureWithEmoticonParseRegexString:(NSString *)emoticonParseRegexString
//                  emoticonMapperPlistFilePath:(NSString *)emoticonMapperPlistFilePath;

@end
