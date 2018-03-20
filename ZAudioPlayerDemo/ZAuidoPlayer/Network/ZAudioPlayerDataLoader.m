//
//  ZAudioPlayerDataLoader.m
//  ZAudioPlayerDemo
//
//  Created by AlexZhang on 20/03/2018.
//  Copyright © 2018 Jixin. All rights reserved.
//

#import "ZAudioPlayerDataLoader.h"
#import "ZAudioPlayerRequestTask.h"
#import "ZAudioPlayerDownloadSessionManager.h"
#import "ZAudioPlayer.h"
#import "CommonCrypto/CommonDigest.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ZAudioPlayerDataLoader()

@property (nonatomic, strong) NSMutableArray *pendingRequests;
@property (nonatomic, copy) NSString *audioPath;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@property (nonatomic, strong) AVAssetResourceLoadingRequest *currentLoadingRequest;

@end

@implementation ZAudioPlayerDataLoader

- (void)dealloc {
    if (self.dataTask) {
        [self.dataTask cancel];
    }
}

- (instancetype)initWithCacheFilePath:(NSString *)cacheFilePath {
    self = [super init];
    if (self) {
        _pendingRequests = [NSMutableArray array];
        _audioPath = cacheFilePath;
        _retryCount = 0;
    }
    return self;
}

#pragma mark - Getter

- (ZAudioPlayerRequestTask *)task {
    if (!_task) {
        _task = [[ZAudioPlayerRequestTask alloc] init];
    }
    return _task;
}

#pragma mark - AVAssetResourceLoaderDelegate

/**
 *  必须返回Yes，如果返回NO，则resourceLoader将会加载出现故障的数据
 *  这里会出现很多个loadingRequest请求， 需要为每一次请求作出处理
 *  @param resourceLoader 资源管理器
 *  @param loadingRequest 每一小块数据的请求
 */
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self.pendingRequests addObject:loadingRequest];
    [self dealWithLoadingRequest:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self.pendingRequests removeObject:loadingRequest];
}

- (void)processPendingRequests {
    NSMutableArray *requestsCompleted = [NSMutableArray array];  //请求完成的数组
    if (!self.pendingRequests.count) {
        return;
    }
    //每次下载一块数据都是一次请求，把这些请求放到数组，遍历数组
    [self.pendingRequests enumerateObjectsUsingBlock:^(AVAssetResourceLoadingRequest *loadingRequest, NSUInteger idx, BOOL * _Nonnull stop) {
        [self fillInContentInformation:loadingRequest.contentInformationRequest]; //对每次请求加上长度，文件类型等信息
        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest]; //判断此次请求的数据是否处理完全
        if (didRespondCompletely) {
            [requestsCompleted addObject:loadingRequest];  //如果完整，把此次请求放进 请求完成的数组
            [loadingRequest finishLoading];
        }
    }];
    
    if (!requestsCompleted.count) {
        return;
    }
    [self.pendingRequests removeObjectsInArray:requestsCompleted];   //在所有请求的数组中移除已经完成的
}
#pragma mark other


- (void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest {
    NSString *mimeType = self.task.mimeType;
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = self.task.audioLength;
}

/**
 *  判断此次请求的数据是否处理完全
 
 @param dataRequest dataRequest
 @return YES：处理完成；NO：尚未处理完成
 */
- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest {
    long long startOffset = dataRequest.requestedOffset;
    
    if (dataRequest.currentOffset != 0) {
        startOffset = dataRequest.currentOffset;
    }
    if ((self.task.offset + self.task.downloadOffset) < startOffset) {
        //NSLog(@"NO DATA FOR REQUEST");
        return NO;
    }
    if (startOffset < self.task.offset) {
        return NO;
    }
    NSData *filedata = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:_audioPath] options:NSDataReadingMappedIfSafe error:nil];
    if (filedata.length == 0) {
        return NO;
    }
    // This is the total data we have from startOffset to whatever has been downloaded so far
    NSUInteger unreadBytes = self.task.downloadOffset - ((NSInteger)startOffset - self.task.offset);
    
    // Respond with whatever is available if we can't satisfy the request fully yet
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
    [dataRequest respondWithData:[filedata subdataWithRange:NSMakeRange((NSUInteger)startOffset- self.task.offset, (NSUInteger)numberOfBytesToRespondWith)]];
    long long endOffset = startOffset + dataRequest.requestedLength;
    BOOL didRespondFully = (self.task.offset + self.task.downloadOffset) >= endOffset;
    return didRespondFully;
}

- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest
                             data:(NSData *)data
                      audioLength:(NSUInteger)audioLength {
    long long startOffset = dataRequest.requestedOffset;
    
    if (dataRequest.currentOffset != 0) {
        startOffset = dataRequest.currentOffset;
    }
    
    NSData *fileData = data;
    if (fileData.length == 0) {
        return NO;
    }
    //    NSLog(@"StartOffset = %ld", startOffset);
    //    NSLog(@"fileData.length = %ld",fileData.length);
    
    [dataRequest respondWithData:fileData];
    long long endOffset = audioLength;
    //    NSLog(@"endOffset = %ld",endOffset);
    BOOL didRespondFully = startOffset + fileData.length >= endOffset;
    return didRespondFully;
}

- (void)dealWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    _currentLoadingRequest = loadingRequest;
    NSURL *interceptedURL = [loadingRequest.request URL];
    NSRange range = NSMakeRange((NSUInteger)loadingRequest.dataRequest.currentOffset, (NSUInteger)loadingRequest.dataRequest.requestedLength);
    
    if (self.task.downloadOffset > 0) {
        [self processPendingRequests];
    }
    
    NSURL *actualUrl = [ZAudioPlayerDataLoader getNormalSchemeWithAudioURL:interceptedURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:actualUrl
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:30.0];
    [request addValue:[NSString stringWithFormat:@"bytes=%lld-%lld",(long long)range.location, (long long)(range.location + range.length - 1)] forHTTPHeaderField:@"Range"];
    [request addValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    
    NSLog(@"request.rang(%lu, %lu)",(unsigned long)range.location, (unsigned long)range.length);
    //    NSLog(@"reequest.allHeader = %@",[request allHTTPHeaderFields]);
    __weak typeof (self)weakSelf = self;
    ZAudioPlayerDownloadSessionManager *manager = [ZAudioPlayerDownloadSessionManager manager];
    
    [self.dataTask cancel];
    self.dataTask = [manager dataWithRequstURL:request
                                didReceiveData:^(NSURLResponse *response, NSData * _Nonnull data)
                     {
                         NSMutableArray *requestsCompleted = [NSMutableArray array];  //请求完成的数组
                         if (!weakSelf.pendingRequests.count) {
                             return;
                         }
                         //每次下载一块数据都是一次请求，把这些请求放到数组，遍历数组
                         [weakSelf.pendingRequests enumerateObjectsUsingBlock:^(AVAssetResourceLoadingRequest *loadingRequest, NSUInteger idx, BOOL * _Nonnull stop) {
                             if (![loadingRequest isEqual:weakSelf.currentLoadingRequest]) {
                                 return ;
                             }
                             NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                             NSString *contentTypeStr = httpResponse.MIMEType;
                             NSString *mimeType = contentTypeStr;
                             CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
                             loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
                             loadingRequest.contentInformationRequest.contentType = CFBridgingRelease(contentType);
                             loadingRequest.contentInformationRequest.contentLength = [httpResponse contentLength];
                             
                             BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest
                                                                                    data:data
                                                                             audioLength:(range.location + range.length)];
                             if (didRespondCompletely) {
                                 [requestsCompleted addObject:loadingRequest];  //如果完整，把此次请求放进 请求完成的数组
                                 [loadingRequest finishLoading];
                             }
                             weakSelf.retryCount = 0;
                         }];
                         
                         if (!requestsCompleted.count) {
                             return;
                         }
                         [weakSelf.pendingRequests removeObjectsInArray:requestsCompleted];   //在所有请求的数组中移除已经完成的
                     }
                              downloadProgress:^(NSProgress * _Nonnull downloadProgress)
                     {
                     }
                                   destination:^NSURL * _Nonnull(NSURLRequest * _Nonnull requestURL)
                     {
                         NSURL *actualUrl = [ZAudioPlayerDataLoader getNormalSchemeWithAudioURL:[requestURL URL]];
                         NSString *movePath = [ZAudioPlayer getAudioCachePathWithURLString:[actualUrl absoluteString]];
                         return [NSURL fileURLWithPath:movePath];
                     }
                             completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error)
                     {
                         if (error) {
                             //             NSLog(@"error = %@",error);
                             if (error.code == -1001) {
                                 if (weakSelf.retryCount >= 2) {
                                     [weakSelf.currentLoadingRequest finishLoadingWithError:error];
                                 } else {
                                     [weakSelf retryLoadingRequest:weakSelf.currentLoadingRequest];
                                 }
                             } else if (error.code == -1009 |
                                        error.code == -1005) {
                                 [weakSelf.dataTask cancel];
                                 [weakSelf.currentLoadingRequest finishLoadingWithError:error];
                             } else if (error.code == -1003) {
                                 [weakSelf.currentLoadingRequest finishLoadingWithError:error];
                             }
                             if ([weakSelf.delegate respondsToSelector:@selector(audioLoaderDidFailLoadingWithTask:error:)]) {
                                 [weakSelf.delegate audioLoaderDidFailLoadingWithTask:nil error:error];
                             }
                         }
                     }];
}

- (void)retryLoadingRequest:(AVAssetResourceLoadingRequest *)loadingReqeust {
    _retryCount++;
    NSLog(@"音频请求超时，第%ld次重试",_retryCount);
    [self dealWithLoadingRequest:loadingReqeust];
}

- (void)dataLoaderContinueTask {
    if (self.currentLoadingRequest) {
        [self retryLoadingRequest:self.currentLoadingRequest];
    }
}

- (void)cancelDataTask {
    [self.dataTask cancel];
}

+ (NSString *)encodingWithMd5:(NSString *)inputString {
    const char *string = [inputString UTF8String];
    int length = (int)strlen(string);
    unsigned char bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(string, length, bytes);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH];
    for (int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x",bytes[i]];
    }
    return result;
}

+ (NSURL *)getCustomSchemeWithAudioURL:(NSURL *)url {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    if ([components.scheme isEqualToString:@"http"]) {
        components.scheme = @"streaming";
    } else if ([components.scheme isEqualToString:@"https"]) {
        components.scheme = @"streamings";
    }
    return [components URL];
}

+ (NSURL *)getNormalSchemeWithAudioURL:(NSURL *)url {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    if ([components.scheme isEqualToString:@"streaming"]) {
        components.scheme = @"http";
    } else if ([components.scheme isEqualToString:@"streamings"]) {
        components.scheme = @"https";
    }
    return [components URL];
}

@end
