//
//  ZAudioPlayerDataLoader.h
//  ZAudioPlayerDemo
//
//  Created by AlexZhang on 20/03/2018.
//  Copyright © 2018 Jixin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class ZAudioPlayerRequestTask;
@protocol ZAudioPlayerLoaderDelegate <NSObject>

- (void)audioLoaderDidFinishLoadingWithTask:(ZAudioPlayerRequestTask *)task;
- (void)audioLoaderDidFailLoadingWithTask:(ZAudioPlayerRequestTask *)task error:(NSError *)error;

@end

@interface ZAudioPlayerDataLoader : NSObject <AVAssetResourceLoaderDelegate>

@property (nonatomic, strong) ZAudioPlayerRequestTask *task;
@property (nonatomic, weak) id<ZAudioPlayerLoaderDelegate> delegate;
@property (nonatomic, assign) BOOL needRedoTask;
@property (nonatomic, assign) NSUInteger retryCount;

- (instancetype)initWithCacheFilePath:(NSString *)cacheFilePath;

- (void)dataLoaderContinueTask;

/**
 *  对字符串做MD5 encode
 
 @param inputString 需要encode的字符串
 @return 返回encode之后的字符串
 */
+ (NSString *)encodingWithMd5:(NSString *)inputString;

/**
 *  将URL中的http，https转换为自定义的scheme，用于触发AVAssetResourceLoaderDelegate
 
 @param url 将URL中的http，https转换为自定义的scheme
 @return 替换scheme之后的URL
 */
+ (NSURL *)getCustomSchemeWithAudioURL:(NSURL *)url;

/**
 *  将自定义的scheme更换为通用的http，https
 
 @param url 将自定义scheme的URL更换为http，https
 @return 替换scheme后的URL
 */
+ (NSURL *)getNormalSchemeWithAudioURL:(NSURL *)url;

@end
