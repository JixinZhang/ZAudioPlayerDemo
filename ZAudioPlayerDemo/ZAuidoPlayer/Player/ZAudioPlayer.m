//
//  ZAudioPlayer.m
//  ZAudioPlayerDemo
//
//  Created by AlexZhang on 20/03/2018.
//  Copyright © 2018 Jixin. All rights reserved.
//

#import "ZAudioPlayer.h"
#import <MediaPlayer/MediaPlayer.h>
#import "ZAudioPlayerDataLoader.h"

NSString *const ZAudioPlayerChangeAudio = @"ZAudioPlayerChangeAudio";
NSString *const ZAudioPlayerUpdateTotalSecond = @"ZAudioPlayerUpdateTotalSecond";
NSString *const ZAudioPlayerPlayAudio = @"ZAudioPlayerPlayAudio";
NSString *const ZAudioPlayerPauseAudio = @"ZAudioPlayerPauseAudio";
NSString *const ZAudioPlayerAudioDownloaded = @"ZAudioPlayerAudioDownloaded";

@interface ZAudioPlayer() <AVAudioPlayerDelegate, ZAudioPlayerLoaderDelegate> {
    id _timeObserver;
    BOOL _getTime;
    BOOL _alertShown;
}

@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVURLAsset *avURLAsset;
@property (nonatomic, strong) AVAsset *avAsset;

@property (nonatomic, strong) ZAudioPlayerDataLoader *audioDataLoader;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@property (nonatomic, strong) UIActivityIndicatorView *activityView;
@property (nonatomic, strong) NSMutableArray *animationImages;

@end

@implementation ZAudioPlayer

+ (instancetype)sharedInstance {
    static ZAudioPlayer *audioPlayer = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        audioPlayer = [[ZAudioPlayer alloc] init];
    });
    return audioPlayer;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.audioItemList = [NSMutableArray array];
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
        [session setActive:YES error:nil];
    }
    return self;
}

#pragma mark - getter

#pragma mark - setter

- (void)setAudioItemList:(NSMutableArray *)audioItemList {
    _audioItemList = audioItemList;
    [self getIndexOfAudioModel];
}

- (void)setAvplayerTotalSecond:(CGFloat)avplayerTotalSecond {
    _avplayerTotalSecond = avplayerTotalSecond;
    if (self.updateSliderValueBlock) {
        self.updateSliderValueBlock(_avplayerTotalSecond);
    }
}

- (void)setAudioPlayerTotalSecond:(CGFloat)audioPlayerTotalSecond {
    _audioPlayerTotalSecond = audioPlayerTotalSecond;
    if (self.updateSliderValueBlock) {
        self.updateSliderValueBlock(_audioPlayerTotalSecond);
    }
}

#pragma mark - AVAudioPlayer

- (void)createAudioPlayerWithMediaData: (NSData *)mediaData {
    if (self.avPlayer) {
        [self.avPlayer pause];
        [self removePlayerItemObserver];
        self.avPlayer = nil;
    }
    NSError *error = nil;
    self.audioPlayer = [[AVAudioPlayer alloc] initWithData:mediaData error:&error];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.audioPlayer.duration];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"mm:ss"];
    self.audioplayerAllPlayTime = [formatter stringFromDate:date];
    self.audioPlayerTotalSecond = self.audioPlayer.duration;
    [[NSNotificationCenter defaultCenter] postNotificationName:ZAudioPlayerUpdateTotalSecond object:nil];
    self.audioPlayer.delegate = self;
    self.audioPlayer.currentTime = 0;
    [self.audioPlayer prepareToPlay];
    [self.audioPlayer play];
    self.hasBeginPlay = YES;
    self.avPlayerFinishSeek = YES;
    self.playing = YES;
    self.state = ZAudioPlayerStatePlaying;
    self.loadedProgress = 1.0;
    [self updateNowControlCenterAllInfo];
}

- (NSString *)getAudioPlayerCurrentPlayTime {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.audioPlayer.currentTime];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"mm:ss"];
    NSString *nowTime = [formatter stringFromDate:date];
    return nowTime;
}

- (NSTimeInterval )getAudioPlayCurrentPlaySecond {
    if (self.audioPlayer.currentTime <= 0) {
        return 0;
    }else {
        return self.audioPlayer.currentTime;
    }
}

- (NSString *)getAudioPlayerTotalPlayTime {
    return self.audioplayerAllPlayTime;
}

#pragma mark - AVPlayer

- (void)createAVPlayerWithUrl: (NSString *)url {
    if (self.audioPlayer) {
        [self.audioPlayer pause];
        self.audioPlayer = nil;
    }
    _getTime = NO;
    [self.avPlayer pause];
    [self removePlayerItemObserver];
    self.avplayerCurrentPlayTime = @"00:00";
    self.avplayerAllPlayTime = @"00:00";
    self.avplayerCurrentSecond = 0.0f;
    self.avplayerTotalSecond = 0.0f;
    
    NSString *cacheFilePath = [[self class] getAudioCachePathWithURLString:url];
    long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:cacheFilePath error:nil] fileSize];
    if (fileSize > 1024.0 * 1024) {
        //如果本地存储的音频文件大于1MB，则准备播放本地音频；否则，发起网络请求，播放在线音频
        self.avAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file:/\/\/%@",cacheFilePath]] options:nil];
        self.playerItem = [AVPlayerItem playerItemWithAsset:self.avAsset];
        self.loadedProgress = 1.0;
    } else {
        NSString *tempCacheFilePath = [self getAudioTempPathWithURLString:url];
        self.audioDataLoader = [[ZAudioPlayerDataLoader alloc] initWithCacheFilePath:tempCacheFilePath];
        self.audioDataLoader.delegate = self;
        NSURL *playUrl = [ZAudioPlayerDataLoader getCustomSchemeWithAudioURL:[NSURL URLWithString:url]];
        self.avURLAsset = [AVURLAsset URLAssetWithURL:playUrl options:nil];
        [self.avURLAsset.resourceLoader setDelegate:self.audioDataLoader queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        self.playerItem = [AVPlayerItem playerItemWithAsset:self.avURLAsset];
        self.loadedProgress = 0.0;
        self.state = ZAudioPlayerStateBuffering;
    }
    [self setAVPlayerItemAndPlay];
}

- (void)setAVPlayerItemAndPlay {
    if (!self.avPlayer) {
        self.avPlayer = [AVPlayer playerWithPlayerItem:self.playerItem];
    }else {
        [self.avPlayer replaceCurrentItemWithPlayerItem:self.playerItem];
        [self.avPlayer removeTimeObserver:_timeObserver];
    }
    if([[UIDevice currentDevice] systemVersion].intValue >= 10) {
        self.avPlayer.automaticallyWaitsToMinimizeStalling = NO;
    }
    [self monitoringPlayback:self.playerItem];
    [self.avPlayer play];
    _playing = YES;
    [self addPlayerItemObserver];
    [self updateNowControlCenterMusicInformation];
}

- (NSString *)getAvPlayerTotalPlayTime {
    return self.avplayerAllPlayTime;
}

- (NSString *)getAvPlayerCurrentPlayTime {
    return self.avplayerCurrentPlayTime;
}

- (void) addPlayerItemObserver{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avPlayerDidFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avPlayerStalled:) name:AVPlayerItemPlaybackStalledNotification object:self.playerItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
    
    
    [self.playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [self.playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [self.playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
}

- (void) removePlayerItemObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
    
    [self.playerItem removeObserver:self forKeyPath:@"status"];
    [self.playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
}

//监听回调
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:@"status"]) {
        if ([playerItem status] == AVPlayerStatusReadyToPlay) {
            [self play];
        } else if ([playerItem status] == AVPlayerStatusFailed || [playerItem status] == AVPlayerStatusUnknown) {
            [self pausePlay];
        }
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) { //监听播放器在缓冲数据的状态
        if (playerItem.isPlaybackBufferEmpty) {
            [self bufferingSomeSecond];
        }
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {  //监听播放器的下载进度
        [self calculateDownloadProgress:playerItem];
    }
}

// 监听播放进度
- (void)monitoringPlayback:(AVPlayerItem *)playerItem {
    __weak typeof(self) weakSelf = self;
    _timeObserver = [self.avPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        CGFloat currentSecond = playerItem.currentTime.value/playerItem.currentTime.timescale;// 计算当前在第几秒
        NSString *timeString = [weakSelf convertTime:currentSecond];
        CGFloat totalSeconds = CMTimeGetSeconds(playerItem.duration);// playerItem.duration.value/playerItem.duration.timescale;
        if (totalSeconds > 0 && !_getTime) {
            weakSelf.avplayerTotalSecond = totalSeconds;
            [[NSNotificationCenter defaultCenter] postNotificationName:ZAudioPlayerUpdateTotalSecond object:nil];
            _getTime = YES;
        }
        weakSelf.avplayerCurrentSecond = currentSecond;
        weakSelf.avplayerAllPlayTime = [weakSelf convertTime:totalSeconds];
        weakSelf.avplayerCurrentPlayTime = [NSString stringWithFormat:@"%@",timeString];
        weakSelf.hasBeginPlay = YES;
        
        if (weakSelf.avPlayer.rate == 0) {
            return ;
        }
        if (currentSecond > 0 && weakSelf.state != ZAudioPlayerStatePlaying) {
            weakSelf.state = ZAudioPlayerStatePlaying;
            [weakSelf updateNowControlCenterMusicInformation];
            [weakSelf updateControlCenterMusicCurrentTime];
        }
    }];
}

- (void)bufferingSomeSecond {
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
    static BOOL isBuffering = NO;
    if (isBuffering) {
        return;
    }
    
    isBuffering = YES;
    self.state = ZAudioPlayerStateBuffering;
    // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
    [self.avPlayer pause];
    NSLog(@"======== buffering ======== ");
    __weak typeof (self)weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof (self)strongSelf = weakSelf;
        if (strongSelf) {
            if (strongSelf.manualStop) {
                isBuffering = NO;
                return ;
            }
            [strongSelf.avPlayer play];
            NSLog(@"======== start to play ======== ");
            isBuffering = NO;
            if (strongSelf.playerItem.isPlaybackBufferEmpty) {
                [strongSelf.audioDataLoader dataLoaderContinueTask];
                [strongSelf bufferingSomeSecond];
            }
        }
    });
}

- (void)calculateDownloadProgress:(AVPlayerItem *)playerItem {
    NSArray *loadedTimeRanges = [playerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    NSTimeInterval startSeconds = CMTimeGetSeconds(timeRange.start);
    NSTimeInterval durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval timeInterval = startSeconds + durationSeconds;// 计算缓冲总进度
    CMTime duration = playerItem.duration;
    CGFloat totalDuration = CMTimeGetSeconds(duration);
    self.loadedProgress = timeInterval / totalDuration;
    NSLog(@"\n ========\t loadProgress = %.3f \t",self.loadedProgress);
}

// 转换时间格式
- (NSString *)convertTime:(CGFloat)second{
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:second];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    if (second/3600 >= 1) {
        [formatter setDateFormat:@"HH:mm:ss"];
    } else {
        [formatter setDateFormat:@"mm:ss"];
    }
    NSString *showtimeNew = [formatter stringFromDate:d];
    return showtimeNew;
}

#pragma mark - change Audio Methods

- (void)changeAudioWithType:(ZAudioPlayerChangeType)type {
    //    if (!self.audioItemList.count) {
    //        return;
    //    }
    //    [self pausePlay];
    //    self.state = ZAudioPlayerStateStop;
    //    if (type == ZAudioPlayerChangeTypeNext) {
    //        _index += 1;
    //        if (_index >= self.audioItemList.count) {
    //            _index = 0;
    //        }
    //    } else {
    //        _index -= 1;
    //        if (_index < 0) {
    //            _index = self.audioItemList.count - 1;
    //        }
    //
    //    }
    //    _audioModel = [self.audioItemList objectAtIndex:_index];
    //    NSString *cacheMediaPath = [self getCacheMediaWithUri:_audioModel.uri];
    //    if (cacheMediaPath) {
    //        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //            NSData *mediaData = [NSData dataWithContentsOfFile:cacheMediaPath];
    //            [self createAudioPlayerWithMediaData:mediaData];
    //        });
    //        _playing = YES;
    //        self.loadedProgress = 1.0;
    //
    //    } else {
    //        [self createAVPlayerWithUrl:_audioModel.uri];
    //    }
    //    [self getIndexOfAudioModel];
    //    [[NSNotificationCenter defaultCenter] postNotificationName:ZAudioPlayerChangeAudio object:@{@"uri" : _audioModel.uri}];
    //    [self updateNowControlCenterMusicInformation];
}

- (void)changeAudioWithIndex:(NSInteger)index {
    //    [self pausePlay];
    //    self.state = ZAudioPlayerStateStop;
    //    if (index >=0 &&
    //        index < self.audioItemList.count) {
    //        _index = index;
    //        _audioModel = [self.audioItemList objectAtIndex:_index];
    //        NSString *cacheMediaPath = [self getCacheMediaWithUri:_audioModel.uri];
    //        if (cacheMediaPath) {
    //            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //                NSData *mediaData = [NSData dataWithContentsOfFile:cacheMediaPath];
    //                [self createAudioPlayerWithMediaData:mediaData];
    //            });
    //            _playing = YES;
    //            self.loadedProgress = 1.0;
    //
    //        } else {
    //            [self createAVPlayerWithUrl:_audioModel.uri];
    //        }
    //        [self getIndexOfAudioModel];
    //        [[NSNotificationCenter defaultCenter] postNotificationName:ZAudioPlayerChangeAudio object:@{@"uri" : _audioModel.uri}];
    //        [self updateNowControlCenterMusicInformation];
    //    }
}

#pragma mark - HoverButton

- (void)setState:(ZAudioPlayerState)state {
    _state = state;
    if (state == ZAudioPlayerStatePlaying) {
        _playing = YES;
    }
}


#pragma mark - slider Method for seekToTime

- (void)addSliderMethodWithSliderValue: (CGFloat )sliderValue {
    if (self.audioPlayer) {
        sliderValue = MAX(0, sliderValue);
        sliderValue = MIN(sliderValue, self.audioPlayerTotalSecond);
        self.audioPlayer.currentTime = sliderValue;
        [self play];
        [self updateControlCenterMusicCurrentTime];
    }
    if (self.avPlayer) {
        if (self.playerItem.status != AVPlayerItemStatusReadyToPlay) {
            return;
        }
        sliderValue = MAX(0, sliderValue);
        sliderValue = MIN(sliderValue, self.avplayerTotalSecond);
        self.avplayerCurrentSecond = sliderValue;
        self.avPlayerFinishSeek = NO;
        CMTime time = CMTimeMake((double)sliderValue, (int)1);
        [self.avPlayer pause];
        __weak typeof(self) weakSelf = self;
        [self.avPlayer seekToTime:time completionHandler:^(BOOL finished) {
            weakSelf.avPlayerFinishSeek = YES;
            [weakSelf play];
//            CGFloat playProgress = (self.avplayerCurrentSecond / self.avplayerTotalSecond);
            
            [weakSelf updateControlCenterMusicCurrentTime];
        }];
    }
}

#pragma mark - NowControlCenterMusicInformation

/**
 *  更新NowControlCenterMusicInformation相关信息
 */
- (void)updateNowControlCenterAllInfo {
    __weak typeof(self) weakSelf = self;
    dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC));
    dispatch_after(time, dispatch_get_main_queue(), ^{
        __strong typeof (self)strongSelf = weakSelf;
        if (strongSelf) {
            //执行操作
            [strongSelf updateNowControlCenterMusicInformation];
            [strongSelf updateControlCenterMusicCurrentTime];
        }
    });
}

/**
 *  更新NowControlCenterMusicInformation
 */
- (void)updateNowControlCenterMusicInformation {
    if (!self.audioModel.title) {
        return;
    }
    
}

/**
 *  更新NowControlCenterMusic当前播放时间
 */
- (void)updateControlCenterMusicCurrentTime {
    double currentTime = [self isAudioPlayer] ? self.audioPlayer.currentTime : CMTimeGetSeconds(self.playerItem.currentTime);
    NSDictionary *info=[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo];
    NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithDictionary:info];
    [dict setObject:@(currentTime) forKeyedSubscript:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [dict setObject:@(self.isPlaying) forKeyedSubscript:MPNowPlayingInfoPropertyPlaybackRate];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:dict];
}

#pragma mark - avPlayerDidFinished

- (void) avPlayerDidFinished:(id)notification{
    if (self.avplayerFinishPlayBlock) {
        self.avplayerFinishPlayBlock();
    }
    if (fabs(self.avplayerCurrentSecond - self.avplayerTotalSecond) < 5) {
        [self changeAudioWithType:ZAudioPlayerChangeTypeNext];
    } else {
        //        AFNetworkReachabilityManager *manager = [AFNetworkReachabilityManager sharedManager];
        //        if (manager.reachable) {
        //            [self.avPlayer play];
        //        } else {
        //            [self.avPlayer pause];
        //        }
    }
}

- (void) avPlayerStalled:(NSNotification *)notification {
    NSLog(@"avplayer stalled");
}

//耳机拔出，播放暂停
- (void)audioSessionRouteChange:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    AVAudioSessionRouteChangeReason reason = [info[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        //获取上一线路描述信息并获取上一线路的输出设备类型
        AVAudioSessionRouteDescription *previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey];
        AVAudioSessionPortDescription *previousOutput = previousRoute.outputs.firstObject;
        NSString *portType = previousOutput.portType;
        
        if ([portType isEqualToString:AVAudioSessionPortHeadphones]) {
            //在这里暂停播放
            [self pausePlay];
        }
    }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (self.audioplayerFinishPlayBlock) {
        self.audioplayerFinishPlayBlock();
    }
    [self changeAudioWithType:ZAudioPlayerChangeTypeNext];
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    [self pausePlay];
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    if (self.manualStop) {
        //如果用户点击了暂停，则不受理任何中断
        return;
    }
    //    //v5.0.8中断结束后不继续播放
    //    [self play];
}

#pragma mark - Handle Interruption
/**
 *  avplayer被中断，处理中断事件
 
 @param notification avplayer被中断时系统发出的通知
 */
- (void)handleInterruption:(NSNotification *)notification {
    if (self.manualStop) {
        //如果用户点击了暂停，则不受理任何中断
        return;
    }
    AVAudioSessionInterruptionType type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        [self pausePlay];
    } else {
        //    //v5.0.8中断结束后不继续播放
        //    [self play];
    }
}

#pragma mark - VoiceDelegate

- (BOOL)existPlayer {
    if (!self.avPlayer && !self.audioPlayer) {
        return NO;
    }else{
        return YES;
    }
}

- (void)play {
    //每次播放都需要将service的值改为self，这样其他视频播放时音频才会停止
    _playing = YES;
    [self updateControlCenterMusicCurrentTime];
    [self resume];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZAudioPlayerPlayAudio object:nil];
}

- (void)pausePlay {
    _playing = NO;
    self.state = ZAudioPlayerStatePause;
    [self updateControlCenterMusicCurrentTime];
    [self pause];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZAudioPlayerPauseAudio object:nil];
}

- (void) pause {
    self.avPlayer?[self.avPlayer pause]:[self.audioPlayer pause];
}

- (void) resume {
    if (self.avPlayer) {
        [self.avPlayer play];
        if (self.audioDataLoader.retryCount) {
            self.state = ZAudioPlayerStateBuffering;
            [self.audioDataLoader dataLoaderContinueTask];
            self.audioDataLoader.retryCount = 0;
        }
    }else {
        [self.audioPlayer play];
        self.state = ZAudioPlayerStatePlaying;
    }
}

- (void) stop {
    self.avPlayer?[self.avPlayer pause]:[self.audioPlayer stop];
    if (self.playerPausePlayBlock) {
        self.playerPausePlayBlock();
    }
}

#pragma mark - ZAAudioLoaderDelegate

- (void)audioLoaderDidFinishLoadingWithTask:(ZAudioPlayerRequestTask *)task {
    
}

- (void)audioLoaderDidFailLoadingWithTask:(ZAudioPlayerRequestTask *)task error:(NSError *)error {
    if (error.code == -999) {
        
    } else if (error.code == -1001) {
        CGFloat result = self.avplayerCurrentSecond - self.loadedProgress * floor(self.avplayerTotalSecond);
        float rate = self.avPlayer.rate;
        if (rate == 0 && result >= -3) {
            if (self.audioDataLoader.retryCount < 2) {
                self.state = ZAudioPlayerStateBuffering;
            } else if (self.audioDataLoader.retryCount == 2) {
                [self pausePlay];
                [self showConfirmViewWithMessage:@"当前网络不给力"];
                self.audioDataLoader.retryCount = 3;
            }
        }
    } else if (error.code == -1009 ||
               error.code == -1005) {
    }
}



- (NSString *)getCacheMediaWithUri:(NSString *)uri {
    return nil;
}

- (NSInteger)getIndexOfAudioModel {
    __block BOOL isFind = NO;
    [self.audioItemList enumerateObjectsUsingBlock:^(ZAudioPlayerModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([model.uri isEqualToString:_audioModel.uri]) {
            self.index = idx;
            isFind = YES;
            *stop = YES;
        }
    }];
    
    if (self.audioModel.uri.length > 0 && !isFind) {
        [self.audioItemList addObject:self.audioModel];
        self.index = self.audioItemList.count - 1;
    }
    return self.index;
}

- (BOOL)isAudioPlayer {
    if (self.avPlayer && self.audioPlayer == nil) {
        return NO;
    } else if (self.avPlayer == nil && self.audioPlayer) {
        return YES;
    } else {
        NSString *cacheMediaPath = [self getCacheMediaWithUri:_audioModel.uri];
        if (cacheMediaPath) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (void)addAudioModelToAudoItemListWithArray:(NSArray *)array {
    
}

#pragma mark - mediaPlayer

- (void) mediaPlayer_stop{
    [self pausePlay];
}

- (void) mediaPlayer_start{
    
}

#pragma mark - temp path & Library/Payables/AudioCache

+ (NSString *)getAudioCachePathWithURLString:(NSString *)urlString {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libDir = [paths objectAtIndex:0];
    NSString *audioCache = [libDir stringByAppendingPathComponent:@"Payables/AudioCache"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:audioCache]) {
        NSError *fileError;
        [[NSFileManager defaultManager] createDirectoryAtPath:audioCache withIntermediateDirectories:YES attributes:nil error:&fileError];
        if (fileError) {
            NSLog(@"create file error = %@",fileError.localizedDescription);
        }
    }
    
    NSString *fileName = [ZAudioPlayerDataLoader encodingWithMd5:urlString];
    //    fileName = [fileName stringByAppendingString:@".mp3"];
    
    NSString *audioCachePath = [audioCache stringByAppendingPathComponent:fileName];
    return audioCachePath;
}

- (NSString *)getAudioTempPathWithURLString:(NSString *)urlString {
    NSString *tempPath = NSTemporaryDirectory();
    
    NSString *fileName = [ZAudioPlayerDataLoader encodingWithMd5:urlString];
    fileName = [fileName stringByAppendingString:@".mp3"];
    return [tempPath stringByAppendingPathComponent:fileName];
}

#pragma mark - show confirm view

- (void)showConfirmViewWithMessage:(NSString *)message {
    
}

@end
