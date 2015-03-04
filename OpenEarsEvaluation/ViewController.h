//
//  ViewController.h
//  OpenEarsEvaluation
//
//  Created by Vincent on 2/26/15.
//  Copyright (c) 2015 SoulGlad. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>

@class OEPocketsphinxController;

#import <OpenEars/OEEventsObserver.h> // We need to import this here in order to use the delegate.

@interface ViewController : UIViewController <OEEventsObserverDelegate, NSXMLParserDelegate> {
    
    // --------------------------------------------------------------------------------------------------------
    // Our NSTimer that will help us read and display the input and output levels without locking the UI
    NSTimer *uiUpdateTimer; // For Updating some UI
    
    NSMutableString *globalSentence;
    
    
    // --------------------------------------------------------------------------------------------------------
    // Some ivars, not specifically related to OpenEars.
    NSMutableArray *lmArray;
    NSMutableArray *dictArray;
    
}

// --------------------------------------------------------------------------------------------------------
// These three are the important OpenEars objects that this class demonstrates the use of.
// --------------------------------------------------------------------------------------------------------
@property (nonatomic, strong) OEEventsObserver *openEarsEventsObserver;
@property (nonatomic, strong) OEPocketsphinxController *pocketsphinxController;

// Things which help us show off the dynamic language features.
// --------------------------------------------------------------------------------------------------------
@property (nonatomic, strong) NSString * pathToGrammarToStartAppWith; // We'll set our new .languagemodel file to be the one to get switched to when the words "CHANGE MODEL" are recognized.
@property (nonatomic, strong) NSString * pathToDictionaryToStartAppWith; // We'll set our new dictionary to be the one to get switched to when the words "CHANGE MODEL" are recognized.

@property (nonatomic, assign) BOOL usingStartLanguageModel;
@property (nonatomic, assign) int restartAttemptsDueToPermissionRequests;
@property (nonatomic, assign) BOOL startupFailedDueToLackOfPermissions;

@end
