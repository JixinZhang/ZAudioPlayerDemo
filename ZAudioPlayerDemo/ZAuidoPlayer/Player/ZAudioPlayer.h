//
//  ZAudioPlayer.h
//  ZAudioPlayerDemo
//
//  Created by AlexZhang on 20/03/2018.
//  Copyright © 2018 Jixin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ZAudioPlayerModel.h"

extern NSString *const ZAudioPlayerChangeAudio;
extern NSString *const ZAudioPlayerUpdateTotalSecond;
extern NSString *const ZAudioPlayerPlayAudio;
extern NSString *const ZAudioPlayerPauseAudio;
extern NSString *const ZAudioPlayerAudioDownloaded;

typedef NS_ENUM (NSInteger, ZAudioPlayerChangeType) {
    ZAudioPlayerChangeTypeNext = 0,   //上一首
    ZAudioPlayerChangeTypePrev        //下一首
};

/**
 *  播放器当前的状态
 
 - ZAudioPlayerStateBuffering: 正在缓冲音频
 */
typedef NS_ENUM(NSInteger, ZAudioPlayerState) {
    ZAudioPlayerStateBuffering = 0,  //缓冲
    ZAudioPlayerStatePlaying,        //播放
    ZAudioPlayerStatePause,          //暂停
    ZAudioPlayerStateStop            //停止
};

@interface ZAudioPlayer : NSObject

@property (nonatomic, strong) AVPlayer *avPlayer;

@property (nonatomic, assign) ZAudioPlayerState state;               //播放器当前状态
@property (nonatomic, assign, getter=isPlaying) BOOL playing;       //当前是否正在播放

@property (nonatomic, copy) NSString *audioplayerAllPlayTime;       //本地音频的单曲时间(时间格式，分：秒)
@property (nonatomic, copy) NSString *avplayerAllPlayTime;          //在线音频的单曲时间(时间格式，分：秒)

@property (nonatomic, copy) NSString *audioplayerCurrentPlayTime;   //本地音频的当前进度(时间格式，分：秒)
@property (nonatomic, copy) NSString *avplayerCurrentPlayTime;      //在线音频的当前进度(时间格式，分：秒)

@property (nonatomic, assign) CGFloat audioPlayerTotalSecond;       //本地音频的单曲长度(秒)
@property (nonatomic, assign) CGFloat avplayerTotalSecond;          //在线音频的单曲长度(秒)

@property (nonatomic, assign) CGFloat audioplayerCurrentSecond;     //本地音频的当前进度(秒)
@property (nonatomic, assign) CGFloat avplayerCurrentSecond;        //在线音频的当前进度(秒)

@property (nonatomic, assign) CGFloat loadedProgress;               //缓冲进度,From 0 to 1
@property (nonatomic, assign) BOOL manualStop;                      //手动点击停止时为YES

@property (nonatomic, assign) BOOL hasBeginPlay;
@property (nonatomic, copy) NSString *title;

@property (nonatomic, copy) void (^updateSliderValueBlock)(CGFloat sliderValue);
@property (nonatomic, copy) void (^audioplayerFinishPlayBlock)(void);
@property (nonatomic, copy) void (^avplayerFinishPlayBlock)(void);
@property (nonatomic, copy) void (^playerPausePlayBlock)(void);
@property (nonatomic, assign) BOOL avPlayerFinishSeek;

@property (nonatomic, strong) NSMutableArray *audioItemList;        //播放列表
@property (nonatomic, assign) NSInteger index;                      //播放列表的index


@property (nonatomic, strong) ZAudioPlayerModel *audioModel;  //当前播放音频的Model


+ (instancetype)sharedInstance;

/**
 *  创建播放本地音频的AVAudioPlayer
 
 @param mediaData 本地缓存的音频数据
 */
- (void)createAudioPlayerWithMediaData: (NSData *)mediaData;

/**
 *  获取本地音频的当前进度
 
 @return 返回的时间格式，分：秒
 */
- (NSString *)getAudioPlayerCurrentPlayTime;

/**
 *  获取本地音频的单曲长度(秒)
 
 @return 返回的格式，秒
 */
- (NSTimeInterval )getAudioPlayCurrentPlaySecond;

/**
 *  获取本地音频的单曲时间(时间格式，分：秒)
 
 @return 返回的格式，分：秒
 */
- (NSString *)getAudioPlayerTotalPlayTime;

/**
 *  获取在线音频的单曲时间(时间格式，分：秒)
 
 @return 返回的格式，分：秒
 */
- (NSString *)getAvPlayerTotalPlayTime;

/**
 *  获取在线音频的当前进度(时间格式，分：秒)
 
 @return 返回的格式，分：秒
 */
- (NSString *)getAvPlayerCurrentPlayTime;

/**
 *  创建播放在线音频的AVPlayer
 
 @param url 在线音频的URL
 */
- (void)createAVPlayerWithUrl: (NSString *)url;

/**
 *  播放操作
 */
- (void)play;

/**
 *  暂停操作
 */
- (void)pausePlay;

/**
 *  判断是否初始化了播放器，AVPlayer或者AVAudioPlayer存在则返回YES，都不存在则返回NO
 
 @return YES or NO
 */
- (BOOL)existPlayer;

/**
 *  滑动滑块更新播放进度
 
 @param sliderValue 滑块更新的值
 */
- (void)addSliderMethodWithSliderValue: (CGFloat )sliderValue;


/**
 *  上／下一首
 
 @param type previous & next
 */
- (void)changeAudioWithType:(ZAudioPlayerChangeType)type;

/**
 *  切换到指定的位置
 
 @param index index
 */
- (void)changeAudioWithIndex:(NSInteger)index;
/**
 *  获取当前播放音频的index
 
 @return 返回index
 */
- (NSInteger)getIndexOfAudioModel;

/**
 *  判断是否是audioPlayer
 
 @return YES：audioPlayer；NO：avplayer
 */
- (BOOL)isAudioPlayer;

/**
 *  根据当前音频的url获取该音频是否保存在本地
 
 @param uri 音频的url
 @return 返回该音频存在本地的路径
 */
- (NSString *)getCacheMediaWithUri:(NSString *)uri;

/**
 *  给当前播放列表添加音频
 
 @param array 添加的音频数组
 */
- (void)addAudioModelToAudoItemListWithArray:(NSArray *)array;

/**
 *  获取音频缓存的的绝对路径
 
 @param urlString 音频的url，用于生成音频缓存文件的名称
 @return 返回音频缓存的绝对路径
 */
+ (NSString *)getAudioCachePathWithURLString:(NSString *)urlString;

@end
