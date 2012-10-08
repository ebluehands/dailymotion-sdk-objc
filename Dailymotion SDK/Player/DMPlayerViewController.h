//
//  DailymotionPlayerViewController.h
//  iOS
//
//  Created by Olivier Poitrey on 26/09/11.
//  Copyright 2011 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DMPlayerViewController;

/**
 * The DMPlayerDelegate protocol defines optional methods for a delegate of DMPlayerViewController.
 */
@protocol DMPlayerDelegate <NSObject>

@optional

/**
 * Called when player emit an event.
 *
 * @param player The player which emited the event
 * @param eventName The name of the emited event
 */
- (void)dailymotionPlayer:(DMPlayerViewController *)player didReceiveEvent:(NSString *)eventName;

@end

/**
 * The DMPlayerViewController class implements a wrapper around the Dailymtion HTML5 player so it can be
 * easily controlled.
 */
@interface DMPlayerViewController : UIViewController <UIWebViewDelegate>

/**
 * The base URL for the player. Default is http://www.dailymotion.com.
 */
@property (nonatomic, copy) NSString *webBaseURLString;

/**
 * The player delegate to send player events to.
 */
@property (nonatomic, weak) id<DMPlayerDelegate>delegate;

/**
 * Determines whether the media resource plays automatically when available (read-only).
 */
@property (nonatomic, readonly) BOOL autoplay;
/**
 * The current playback position in seconds. Set this value to seek in the video.
 */
@property (nonatomic, assign) float currentTime;
/**
 * The part of the media resource that have been downloaded in seconds (read-only).
 */
@property (nonatomic, readonly) float bufferedTime;
/**
 * The length of the media resource in seconds (read-only).
 */
@property (nonatomic, readonly) float duration;
/**
 * Indicates whether the element is seeking (read-only).
 */
@property (nonatomic, readonly) BOOL seeking;
/**
 * Indicates whether the media is paused (read-only).
 */
@property (nonatomic, readonly) BOOL paused;
/**
 * Indicates whether the media played to the end (read-only).
 */
@property (nonatomic, readonly) BOOL ended;
/**
 * Determines whether the audio content should be muted. Set this value to mute/unmute the sound.
 */
@property (nonatomic, assign) BOOL muted;
/**
 * The volume of the video between 0 and 1.
 */
@property (nonatomic, assign) float volume;
/**
 * Indicates whether the video is displayed fullscreen.
 */
@property (nonatomic, assign) BOOL fullscreen;
/**
 * The last error that occurend for this player.
 */
@property (nonatomic, readonly) NSError *error;


- (id)initWithParams:(NSDictionary *)params;
- (id)initWithVideo:(NSString *)aVideo;
- (id)initWithVideo:(NSString *)aVideo params:(NSDictionary *)someParams;

- (void)play;
- (void)togglePlay;
- (void)pause;
- (void)load:(NSString *)video;

/**
 * Call player API method. See `Player API Reference <http://www.dailymotion.com/doc/api/player.html#api-reference>` for more info.
 *
 * @param method The method name to call
 * @param arg The argument to pass to the method (if necessary)
 */
- (void)api:(NSString *)method arg:(NSString *)arg;

/**
 * Call player API method. See `Player API Reference <http://www.dailymotion.com/doc/api/player.html#api-reference>` for more info.
 *
 * @param method The method name to call
 */
- (void)api:(NSString *)method;

@end
