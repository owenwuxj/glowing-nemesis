//
//  ViewController.h
//  OpenEarsEvaluation
//
//  Created by Vincent on 2/26/15.
//  Copyright (c) 2015 SoulGlad. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>

@class PocketsphinxController;

#import <OpenEars/OpenEarsEventsObserver.h> // We need to import this here in order to use the delegate.

@interface ViewController : UIViewController <OpenEarsEventsObserverDelegate, NSXMLParserDelegate> {
    
    /*
     // --------------------------------------------------------------------------------------------------------
     // These three are important OpenEars classes that ViewController demonstrates the use of. There is a fourth important class (LanguageModelGenerator) demonstrated
     // inside the ViewController implementation in the method viewDidLoad.
     // --------------------------------------------------------------------------------------------------------
     */
    OpenEarsEventsObserver *openEarsEventsObserver; // A class whose delegate methods which will allow us to stay informed of changes in the Flite and Pocketsphinx statuses.
    PocketsphinxController *pocketsphinxController; // The controller for Pocketsphinx (voice recognition).
    
    // --------------------------------------------------------------------------------------------------------
    // Helper Flags
    BOOL usingStartLanguageModel;
    int restartAttemptsDueToPermissionRequests;
    BOOL startupFailedDueToLackOfPermissions;
    
    // --------------------------------------------------------------------------------------------------------
    // Strings which aren't required for OpenEars but which will help us show off the dynamic language features in this sample app.
    NSString *pathToFirstDynamicallyGeneratedLanguageModel;
    NSString *pathToFirstDynamicallyGeneratedDictionary;
    
    NSString *pathToSecondDynamicallyGeneratedLanguageModel;
    NSString *pathToSecondDynamicallyGeneratedDictionary;
    
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
@property (nonatomic, strong) OpenEarsEventsObserver *openEarsEventsObserver;
@property (nonatomic, strong) PocketsphinxController *pocketsphinxController;

// Things which help us show off the dynamic language features.
// --------------------------------------------------------------------------------------------------------
@property (nonatomic, strong) NSString * pathToGrammarToStartAppWith; // We'll set our new .languagemodel file to be the one to get switched to when the words "CHANGE MODEL" are recognized.
@property (nonatomic, strong) NSString * pathToDictionaryToStartAppWith; // We'll set our new dictionary to be the one to get switched to when the words "CHANGE MODEL" are recognized.
@property (nonatomic, copy) NSString *pathToFirstDynamicallyGeneratedLanguageModel;
@property (nonatomic, copy) NSString *pathToFirstDynamicallyGeneratedDictionary;
@property (nonatomic, copy) NSString *pathToSecondDynamicallyGeneratedLanguageModel;
@property (nonatomic, copy) NSString *pathToSecondDynamicallyGeneratedDictionary;

@property (nonatomic, assign) BOOL usingStartLanguageModel;
@property (nonatomic, assign) int restartAttemptsDueToPermissionRequests;
@property (nonatomic, assign) BOOL startupFailedDueToLackOfPermissions;

@end
