//
//  ZAudioPlayerRequestTask.h
//  ZAudioPlayerDemo
//
//  Created by AlexZhang on 20/03/2018.
//  Copyright © 2018 Jixin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZAudioPlayerRequestTask : NSObject

@property (nonatomic, assign) NSUInteger offset;
@property (nonatomic, assign) NSUInteger audioLength;
@property (nonatomic, assign) NSUInteger downloadOffset;
@property (nonatomic, copy) NSString *mimeType;

@end
