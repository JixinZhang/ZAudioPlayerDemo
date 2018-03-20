//
//  ZAudioPlayerDownloadSessionManager.h
//  ZAudioPlayerDemo
//
//  Created by AlexZhang on 20/03/2018.
//  Copyright © 2018 Jixin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSHTTPURLResponse(ZAPDownload)

- (long long) contentLength;

@end

#pragma mark --
#pragma mark NSURLSessionTask(ZAPDownload)

@interface NSURLSessionTask(ZAPDownload)

- (void) wscnCancel;

@end


#pragma mark --
#pragma mark ZAPDownloadSessionManager

@interface ZAudioPlayerDownloadSessionManager : NSObject

+ (instancetype _Nullable )manager;

- (NSURLSessionDataTask *_Nullable) dataWithRequstURL:(NSURLRequest *_Nullable) requestURL
                                       didReceiveData:(void (^_Nullable)(NSURLResponse * _Nullable response,NSData * _Nullable data))receiveBlock
                            downloadProgress:(void (^_Nullable)(NSProgress * _Nullable downloadProgress)) downloadProgressBlock
                                          destination:(NSURL * _Nullable (^_Nonnull)(NSURLRequest * _Nullable requestURL))destination
                                    completionHandler:(void (^_Nullable)(NSURLResponse * _Nullable response, id _Nullable responseObject,  NSError * _Nullable error))completionHandler;


- (NSURLSessionDownloadTask *_Nullable) downloadWithRequestURL:(NSURLRequest *_Nullable) requestURL
                                                 progress:(void (^_Nullable)(NSProgress * _Nullable downloadProgress)) downloadProgressBlock
                                              destination:(NSURL * _Nullable (^_Nullable)(NSURL * _Nonnull targetPath, NSURLResponse * _Nullable response))destination
                                        completionHandler:(void (^_Nullable)(NSURLResponse * _Nullable response, NSURL * _Nonnull filePath, NSError * _Nullable error))completionHandler;

@end
