//
//  ViewController.m
//  RemoteTest
//
//  Created by Keith Burgoyne on 2021-02-22.
//

#import "ViewController.h"
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>


@interface ViewController ()

@property (nonatomic) AVPlayerItem *item;
@property (nonatomic) AVPlayer *player;
@property (nonatomic) NSTimer *seekTimer;
@end

@implementation ViewController

static NSTimeInterval seekTimerPeriod = 1.0;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self activateAudioSession];

    NSURL *url = [NSURL URLWithString:@"https://s3.amazonaws.com/kargopolov/kukushka.mp3"];
    self.item = [AVPlayerItem playerItemWithURL:url];
    self.player = [AVPlayer playerWithPlayerItem:self.item];
    [self.player play];

    __weak __typeof(self) weakSelf = self;
      MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];

      NSArray *commands = @[commandCenter.playCommand, commandCenter.pauseCommand, commandCenter.nextTrackCommand, commandCenter.previousTrackCommand, commandCenter.bookmarkCommand, commandCenter.changePlaybackPositionCommand, commandCenter.changePlaybackRateCommand, commandCenter.dislikeCommand, commandCenter.enableLanguageOptionCommand, commandCenter.likeCommand, commandCenter.ratingCommand, commandCenter.seekBackwardCommand, commandCenter.seekForwardCommand, commandCenter.skipBackwardCommand, commandCenter.skipForwardCommand, commandCenter.stopCommand, commandCenter.togglePlayPauseCommand];

      for (MPRemoteCommand *command in commands) {
          [command removeTarget:nil];
          [command setEnabled:NO];
      }

      [commandCenter.changePlaybackPositionCommand addTarget:self action:@selector(setCurrentAudioTimeFromRemote:)];
      [commandCenter.playCommand addTarget:self action:@selector(playMediaFromRemote)];
      [commandCenter.pauseCommand addTarget:self action:@selector(pauseMediaFromRemote)];
      [commandCenter.nextTrackCommand addTarget:self action:@selector(goToNextMediaFromRemote)];
      [commandCenter.previousTrackCommand addTarget:self action:@selector(goToPreviousMediaFromRemote)];

      [commandCenter.seekBackwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
          return [weakSelf seekFromRemote:(MPSeekCommandEvent *)event forward:NO];
      }];

      [commandCenter.seekForwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
          return [weakSelf seekFromRemote:(MPSeekCommandEvent *)event forward:YES];
      }];

      commandCenter.previousTrackCommand.enabled = YES;
      commandCenter.nextTrackCommand.enabled = YES;
      commandCenter.pauseCommand.enabled = YES;
      commandCenter.playCommand.enabled = YES;
      commandCenter.changePlaybackPositionCommand.enabled = YES;
      commandCenter.seekBackwardCommand.enabled = YES;
      commandCenter.seekForwardCommand.enabled = YES;

    [self updateNowPlaying];

    [self.player addObserver:self
                  forKeyPath:@"currentItem.playbackLikelyToKeepUp"
                     options:NSKeyValueObservingOptionNew
                     context:nil];
}

- (void)dealloc {
    [self.player removeObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp"];
}

- (MPRemoteCommandHandlerStatus)playMediaFromRemote {
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)pauseMediaFromRemote {
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)goToNextMediaFromRemote {
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)goToPreviousMediaFromRemote {
    return MPRemoteCommandHandlerStatusSuccess;
}


- (MPRemoteCommandHandlerStatus)setCurrentAudioTimeFromRemote:(MPChangePlaybackPositionCommandEvent *)event {
    return MPRemoteCommandHandlerStatusSuccess;
}

- (void)updateNowPlaying {
    NSDictionary *nowPlayingInfo;

    nowPlayingInfo = @{
        MPMediaItemPropertyArtist: @"test",
        MPMediaItemPropertyAlbumTitle: @"Test Album",
        MPMediaItemPropertyTitle: @"Test Media",
        MPMediaItemPropertyPlaybackDuration: @(CMTimeGetSeconds(self.player.currentItem.duration)),
        MPNowPlayingInfoPropertyElapsedPlaybackTime: @(CMTimeGetSeconds(self.player.currentItem.currentTime)),
        MPNowPlayingInfoPropertyPlaybackRate: @(1.0),
        MPNowPlayingInfoPropertyChapterCount: @(1),
    };

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlayingInfo;
}

- (MPRemoteCommandHandlerStatus)seekFromRemote:(MPSeekCommandEvent *)event forward:(BOOL)forward {
    [self.seekTimer invalidate];
    self.seekTimer = nil;
    if (event.type == MPSeekCommandEventTypeBeginSeeking) {
        if (forward) {
            NSLog(@"Begin Forward Seeking.");
            self.seekTimer = [NSTimer scheduledTimerWithTimeInterval:seekTimerPeriod
                                                              target:self
                                                            selector:@selector(handleRemoteFastForwardTimer)
                                                            userInfo:nil
                                                             repeats:YES];
            [self.seekTimer fire];

        } else {
            NSLog(@"Begin Backward Seeking.");
            self.seekTimer = [NSTimer scheduledTimerWithTimeInterval:seekTimerPeriod
                                                              target:self
                                                            selector:@selector(handleRemoteFastBackwardTimer)
                                                            userInfo:nil
                                                             repeats:YES];
            [self.seekTimer fire];
        }
    } else {
        NSLog(@"End Seeking.");
    }

    return MPRemoteCommandHandlerStatusSuccess;
}

- (void)handleRemoteFastForwardTimer {
    NSLog(@"Seeking forward ...");

    [self.player pause];

    CMTimeScale timeScale = self.player.currentItem.asset.duration.timescale;
    // The completion handler runs in the main queue, not the calling queue
    // queue for the seek action.

    [self.player seekToTime:CMTimeMakeWithSeconds(CMTimeGetSeconds(self.player.currentTime) + 15, timeScale)
               completionHandler:^(BOOL finished) {
        if (finished) {
            self.player.rate = 1.0;
        }
    }];

    [self updateNowPlaying];
}

- (void)handleRemoteFastBackwardTimer {
    NSLog(@"Seeking backward ...");

    [self.player pause];

    CMTimeScale timeScale = self.player.currentItem.asset.duration.timescale;
    // The completion handler runs in the main queue, not the calling queue
    // queue for the seek action.

    if (CMTimeGetSeconds(self.player.currentTime) - 15 > 0 ) {
        [self.player seekToTime:CMTimeMakeWithSeconds(CMTimeGetSeconds(self.player.currentTime) - 15, timeScale)
                   completionHandler:^(BOOL finished) {
            if (finished) {
                self.player.rate = 1.0;
            }
        }];
    }

    [self updateNowPlaying];
}


- (void)activateAudioSession {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];

    // Set the audio category of this app to playback.
    NSError *setCategoryError = nil;
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
    if (setCategoryError) {
    }

    // Activate the audio session
    NSError *setActiveError = nil;
    [audioSession setActive:YES error:&setActiveError];
}

- (void)deactivateAudioSession {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];

    // Don't show an error message if we can't deactivate audio.
    [audioSession setActive:NO error:nil];

    // Remove the interruption handler.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:AVAudioSessionInterruptionNotification
                                               object:audioSession];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"currentItem.playbackLikelyToKeepUp"]) {
        [self updateNowPlaying];
    }
}

@end
