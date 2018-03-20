//
//  ViewController.m
//  ZAudioPlayerDemo
//
//  Created by AlexZhang on 20/03/2018.
//  Copyright © 2018 Jixin. All rights reserved.
//

#import "ViewController.h"
#import "ZAudioPlayer.h"

@interface ViewController ()

@property (nonatomic, strong) ZAudioPlayer *audioPlayer;
@property (nonatomic, strong) UIButton *playButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.playButton];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Getter

- (ZAudioPlayer *)audioPlayer {
    return [ZAudioPlayer sharedInstance];
}

- (UIButton *)playButton {
    if (!_playButton) {
        _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _playButton.frame = CGRectMake(100, 300, 44, 44);
        [_playButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [_playButton setTitle:@"play" forState:UIControlStateNormal];
        [_playButton setTitle:@"pause" forState:UIControlStateSelected];
        [_playButton addTarget:self action:@selector(playButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playButton;
}

- (void)playButtonAction:(UIButton *)button {
    button.selected = !button.selected;
    if (button.selected) {
        if (![self.audioPlayer existPlayer]) {
            [self.audioPlayer createAVPlayerWithUrl:@"https://premium.wallstcn.com/460854bc-5449-4278-9296-de6e812d961d"];
        }
        [self.audioPlayer play];
    } else {
        [self.audioPlayer pausePlay];
    }
}

@end
