//
//  ZAudioPlayerDownloadSessionManager.m
//  ZAudioPlayerDemo
//
//  Created by AlexZhang on 20/03/2018.
//  Copyright © 2018 Jixin. All rights reserved.
//

#import "ZAudioPlayerDownloadSessionManager.h"
#import <CommonCrypto/CommonDigest.h>
#import "AFNetworking.h"
#import <objc/runtime.h>

typedef void (^ZAPSessionDataTaskDidReceiveDataBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data);

#pragma mark --
#pragma mark NSHTTPURLResponse(ZAPDownload)

@implementation NSHTTPURLResponse(ZAPDownload)

- (long long) contentLength {
    NSDictionary *dic = [self allHeaderFields];
    NSString *content = [dic valueForKey:@"Content-Range"];
    NSArray *array = [content componentsSeparatedByString:@"/"];
    NSString *length = array.lastObject;
    long long audioLength;
    if ([length integerValue] == 0) {
        audioLength = (NSUInteger)self.expectedContentLength;
    } else {
        audioLength = [length integerValue];
    }
    return audioLength;
}

@end


#pragma mark --
#pragma mark NSURLRequest(ZAPDownload)

@interface NSURLRequest(ZAPDownload)

@end

@implementation NSURLRequest(ZAPDownload)

- (NSString *)cachedFileNameForKey:(NSString *)key {
    const char *str = [key UTF8String];
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], [[key pathExtension] isEqualToString:@""] ? @"" : [NSString stringWithFormat:@".%@", [key pathExtension]]];
    
    return filename;
}

- (NSURL *) cacheResumeURL {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *libCacheDir = [paths objectAtIndex:0];
    NSString *documentDirCache = [libCacheDir stringByAppendingPathComponent:@"wscnc"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentDirCache]) {
        NSError *fileError;
        [[NSFileManager defaultManager] createDirectoryAtPath:documentDirCache withIntermediateDirectories:YES attributes:nil error:&fileError];
    }
    documentDirCache = [documentDirCache stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",[self cachedFileNameForKey:self.URL.absoluteString]]];
    
    NSURL *documentsDirectoryURL = [NSURL fileURLWithPath:documentDirCache];
    return documentsDirectoryURL;
}

@end

#pragma mark --
#pragma mark NSURLSessionTask(ZAPDownload)

@interface NSURLSessionTask (ZAPDownloadData)
@property ( nonatomic, copy) ZAPSessionDataTaskDidReceiveDataBlock dataTaskDidReceiveData;

@end

@implementation NSURLSessionTask (ZAPDownloadData)
@dynamic dataTaskDidReceiveData;

- (void) setDataTaskDidReceiveData:(ZAPSessionDataTaskDidReceiveDataBlock)dataTaskDidReceiveData {
    objc_setAssociatedObject(self, @selector(dataTaskDidReceiveData), dataTaskDidReceiveData, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (ZAPSessionDataTaskDidReceiveDataBlock) dataTaskDidReceiveData {
    return objc_getAssociatedObject(self, _cmd);
}

@end

@implementation NSURLSessionTask (ZAPDownload)

- (void) wscnCancel {
    __weak __typeof__(self) weakSelf = self;
    if ([self isKindOfClass:[NSURLSessionDownloadTask class]]) {
        [(NSURLSessionDownloadTask*)self cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            if ([resumeData length] > 0) {
                [resumeData writeToURL:[weakSelf.originalRequest cacheResumeURL] atomically:YES];
            }
        }];
    } else {
        [self cancel];
    }
}
@end

#pragma mark --
#pragma mark ZAPDownloadSessionManager


@interface ZAudioPlayerDownloadSessionManager()
@property (nonatomic, strong) AFURLSessionManager *sessionManager;
@end

@implementation ZAudioPlayerDownloadSessionManager

+ (instancetype)manager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (AFURLSessionManager *) sessionManager {
    if (!_sessionManager) {
        _sessionManager = [[AFURLSessionManager alloc] init];
        _sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        [_sessionManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential *__autoreleasing  _Nullable * _Nullable credential)
         {
             return NSURLSessionAuthChallengePerformDefaultHandling;
         }];
        
        [_sessionManager setDataTaskDidReceiveDataBlock:^(NSURLSession * _Nonnull session, NSURLSessionDataTask * _Nonnull dataTask, NSData * _Nonnull data)
         {
             !dataTask.dataTaskDidReceiveData?:dataTask.dataTaskDidReceiveData(session, dataTask, data);
         }];
    }
    return _sessionManager;
}



- (NSURLSessionDataTask *) dataWithRequstURL:(NSURLRequest *) requestURL
                              didReceiveData:(void (^)(NSURLResponse *response,NSData *data))receiveBlock
                            downloadProgress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                                 destination:(NSURL * (^)(NSURLRequest *requestURL))destination
                           completionHandler:(void (^)(NSURLResponse *response, id _Nullable responseObject,  NSError * _Nullable error))completionHandler
{
    NSAssert(requestURL != nil, @"requestURL is nil!");
    NSURL *destinationURL = nil;
    if (destination) destinationURL = destination(requestURL);
    
    __block NSURLSessionDataTask *dataTask = [self.sessionManager   dataTaskWithRequest:requestURL
                                                                         uploadProgress:nil
                                                                       downloadProgress:downloadProgressBlock
                                                                      completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error)
                                              
                                              {
                                                  
                                                  dispatch_async(dispatch_get_global_queue(0, 0), ^{
                                                      if (responseObject && [responseObject length] > 0 && [responseObject length]  == [(NSHTTPURLResponse *)response contentLength]) {
                                                          [(NSData *)responseObject writeToURL:destinationURL atomically:YES];
                                                      }
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          !completionHandler?:completionHandler(response, responseObject, error);
                                                          dataTask = nil;
                                                      });
                                                  });
                                              }];
    
    [dataTask setDataTaskDidReceiveData:^(NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data) {
        !receiveBlock?:receiveBlock(dataTask.response, data);
    }];
    
    [dataTask resume];
    return dataTask;
}


- (NSURLSessionDownloadTask *) downloadWithRequestURL:(NSURLRequest *) requestURL
                                             progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                                          destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                    completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler
{
    NSAssert(requestURL != nil, @"requestURL is nil!");
    __block NSURLSessionDownloadTask *downloadTask = nil;
    NSData *data = [NSData dataWithContentsOfURL:[requestURL cacheResumeURL]];
    if (0 == [data length]) {
        downloadTask = [self.sessionManager downloadTaskWithRequest:requestURL
                                                           progress:downloadProgressBlock
                                                        destination:destination
                                                  completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error)
                        {
                            !completionHandler?:completionHandler(response, filePath, error);
                            downloadTask = nil;
                        }];
    } else {
        downloadTask = [self.sessionManager downloadTaskWithResumeData:data
                                                              progress:downloadProgressBlock
                                                           destination:destination
                                                     completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error)
                        {
                            !completionHandler?:completionHandler(response, filePath, error);
                            downloadTask = nil;
                        }];;
    }
    
    [downloadTask resume];
    return downloadTask;
}

@end
