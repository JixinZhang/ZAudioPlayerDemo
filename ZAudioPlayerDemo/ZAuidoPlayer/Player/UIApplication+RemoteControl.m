//
//  UIApplication+RemoteControl.m
//  ZAudioPlayerDemo
//
//  Created by AlexZhang on 20/03/2018.
//  Copyright © 2018 Jixin. All rights reserved.
//

#import "UIApplication+RemoteControl.h"
#import "ZAudioPlayer.h"

@implementation UIApplication (RemoteControl)


- (void) remoteControlReceivedWithEvent: (UIEvent *) receivedEvent {
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) { // 得到事件类型
            case UIEventSubtypeRemoteControlTogglePlayPause: // 耳机控制播放／暂停
                if ([[ZAudioPlayer sharedInstance] isPlaying]) {
                    [[ZAudioPlayer sharedInstance] pausePlay];
                    [ZAudioPlayer sharedInstance].manualStop = YES;
                } else {
                    [[ZAudioPlayer sharedInstance] play];
                    [ZAudioPlayer sharedInstance].manualStop = NO;
                }
                break;
                
            case UIEventSubtypeRemoteControlPause: // 暂停
                [[ZAudioPlayer sharedInstance] pausePlay];
                [ZAudioPlayer sharedInstance].manualStop = YES;
                break;
                
            case UIEventSubtypeRemoteControlPreviousTrack:  // 上一首
                [[ZAudioPlayer sharedInstance] changeAudioWithType:ZAudioPlayerChangeTypePrev];
                break;
                
            case UIEventSubtypeRemoteControlNextTrack: // 下一首
                [[ZAudioPlayer sharedInstance] changeAudioWithType:ZAudioPlayerChangeTypeNext];
                break;
                
            case UIEventSubtypeRemoteControlPlay: //播放
                [[ZAudioPlayer sharedInstance] play];
                [ZAudioPlayer sharedInstance].manualStop = NO;
                break;
                
            default:
                break;
        }
    }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

@end
