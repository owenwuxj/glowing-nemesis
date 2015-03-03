//
//  ViewController.m
//  OpenEarsEvaluation
//
//  Created by Vincent on 2/26/15.
//  Copyright (c) 2015 SoulGlad. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking.h>
#import <ZipArchive.h>
#import <AFNetworking/UIKit+AFNetworking.h>
#import <OpenEars/PocketsphinxController.h> // Please note that unlike in previous versions of OpenEars, we now link the headers through the framework.
#import <OpenEars/LanguageModelGenerator.h>
#import <OpenEars/OpenEarsLogging.h>
#import <OpenEars/AcousticModel.h>

#import "TPWordNormalizer.h"
#import "XMLDictionary.h"


#define kFileDownloaded @"ZipFileDownloaded"
#define kFileUnzipped @"FileUnzipped"

@interface ViewController () <ZipArchiveDelegate>
{
    // output array to write to countList
    NSMutableArray *resultArray;
    
    // input sentence from TP XML to feed into PocketSphinx
    NSMutableString *aSentence;
    
    // for comparison testing
    NSString *fileNameString;
}

@property (nonatomic, strong) NSMutableDictionary *preGrammarDict;
@property (nonatomic, strong) NSString *wavFilePath;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;

@property (nonatomic, strong) dispatch_semaphore_t sema;
@property (nonatomic, strong) dispatch_queue_t queue;

@property (weak, nonatomic) IBOutlet UILabel *countingLabel;
@property (nonatomic, assign) NSUInteger countNum;


@end

@implementation ViewController

#define kPassPercentage 59.0

#define kGetNbest // Uncomment this if you want to try out nbest

#pragma mark -
#pragma mark Lazy Allocation

// Lazily allocated PocketsphinxController.
- (PocketsphinxController *)pocketsphinxController {
    if (_pocketsphinxController == nil) {
        _pocketsphinxController = [[PocketsphinxController alloc] init];
        //pocketsphinxController.verbosePocketSphinx = TRUE; // Uncomment me for verbose debug output
        //pocketsphinxController.outputAudio = TRUE;
        _pocketsphinxController.returnNullHypotheses = YES;
#ifdef kGetNbest
        _pocketsphinxController.returnNbest = TRUE;
        _pocketsphinxController.nBestNumber = 1;
#endif
    }
    return _pocketsphinxController;
}

// Lazily allocated OpenEarsEventsObserver.
- (OpenEarsEventsObserver *)openEarsEventsObserver {
    if (_openEarsEventsObserver == nil) {
        _openEarsEventsObserver = [[OpenEarsEventsObserver alloc] init];
    }
    return _openEarsEventsObserver;
}



#pragma mark -
#pragma mark View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.restartAttemptsDueToPermissionRequests = 0;
    self.startupFailedDueToLackOfPermissions = FALSE;
    
    [OpenEarsLogging startOpenEarsLogging]; // Uncomment me for OpenEarsLogging
    
    [self.openEarsEventsObserver setDelegate:self]; // Make this class the delegate of OpenEarsObserver so we can get all of the messages about what OpenEars is doing.

    
    self.sema = dispatch_semaphore_create(0);
    self.queue = dispatch_queue_create("com.example.subsystem.taskAsr", NULL);
    
    self.countNum = 0;
    
    BOOL isFileDownloaded = [[NSUserDefaults standardUserDefaults] boolForKey:kFileDownloaded];
    BOOL isFileUnzipped = [[NSUserDefaults standardUserDefaults] boolForKey:kFileUnzipped];
    
    if (!isFileDownloaded) {
        
        self.statusLabel.text = @"Ready for Downloading";
        self.statusLabel.textColor = [UIColor redColor];
        
        [self downloadFile];
        
    } else if (!isFileUnzipped) {
        // TODO
    } else {

        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        NSString *directory = documentsDirectoryURL.path;
        
        dispatch_async(dispatch_queue_create("com.example.subsystem.taskFile", NULL), ^{
            [self openEachFileAt:directory];
        });
    }
    
}
- (IBAction)onStartButtonTapped:(id)sender {
        [self downloadFile];
}


- (IBAction)onResetButtonTapped:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFileDownloaded];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFileUnzipped];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSString *directory = documentsDirectoryURL.path;
    NSError *error = nil;
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error]) {
        BOOL success = [fm removeItemAtPath:[NSString stringWithFormat:@"%@%@", directory, file] error:&error];
        if (!success || error) {
            // it failed.
        }
    }
}


- (void)openEachFileAt:(NSString *)path {
    
    NSString *file;
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
    while (file = [enumerator nextObject]) {
        // check if it's a directory
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", path, file]
                                             isDirectory:&isDirectory];
        if (!isDirectory) {
            
            
            if ([[file substringFromIndex:[file length] - 7] isEqualToString:@"context"]) {
                
                NSLog(@"### Starting: %@ ###", file);
                
                dispatch_async(self.queue, ^{
                    [self evaluateFiles:file];
                });
                dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
                
                NSLog(@"### Finished: %@ ###", file);
                
                
            }

            
            
        }
        else {
            [self openEachFileAt:file];
        }
    }
}

- (void)evaluateFiles:(NSString *)file {
    
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        NSString *directory = documentsDirectoryURL.path;
        
        fileNameString = [NSString stringWithFormat:@"%@/%@",directory,file];
        self.wavFilePath = [NSString stringWithFormat:@"%@/%@.wav",directory,[file substringToIndex:[file length]-8]];
        
        NSData *xmlData = [[NSData alloc] initWithContentsOfFile:fileNameString];
        
        aSentence = nil;
        self.preGrammarDict = [NSMutableDictionary dictionary];
        
        // XML formatted Strings are strange
        NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:xmlData];//[contextXml dataUsingEncoding:NSUTF8StringEncoding]];
        xmlParser.delegate = self;
        
        if ([xmlParser parse] == NO ) {
            NSLog(@"Failed to start xml parser");
        } else {
            //        NSLog(@"%@",xmlData);
        }
}

- (void)downloadFile {
    
    self.statusLabel.text = @"Downloading";
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSURL *URL = [NSURL URLWithString:@"http://10.128.43.56:8888/audio-sample.zip"];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];;
        
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kFileDownloaded];
        NSLog(@"File downloaded to: %@", filePath);
        if (&error) {
            self.statusLabel.text = @"Downloading completed, Ready for Unzipping";
            self.statusLabel.textColor = [UIColor greenColor];
        } else {
            self.statusLabel.text = @"Network error, Press start button to download again";
            self.statusLabel.textColor = [UIColor redColor];
        }

        
        [self unzipFile:filePath];
    }];
    [downloadTask resume];
    [self.progressView setProgressWithDownloadProgressOfTask:downloadTask animated:YES];
}

- (void)unzipFile:(NSURL *)filePath {
    NSString *zipPath = filePath.path;
    ZipArchive *zipArchive = [[ZipArchive alloc] init];
    [zipArchive UnzipOpenFile:zipPath];
    NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    BOOL success = [zipArchive UnzipFileTo:documentsDirectoryURL.path overWrite:YES ];
    [zipArchive UnzipCloseFile];
    zipArchive.delegate = self;
    zipArchive.progressBlock = ^(int percentage, int filesProcessed, unsigned long numFiles) {
        self.progressView.progress = percentage / 100.0f;
    };
    if (!success){

        self.statusLabel.text = @"Unzipping Failed";
        self.statusLabel.textColor = [UIColor redColor];
        
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kFileUnzipped];
        self.statusLabel.text = @"Unzipping Finished";
        self.statusLabel.textColor = [UIColor greenColor];
        
        [self downloadFile];
    }
    
}

#pragma mark -
#pragma mark OpenEarsEventsObserver delegate methods

// An optional delegate method of OpenEarsEventsObserver which delivers the text of speech that Pocketsphinx heard and analyzed, along with its accuracy score and utterance ID.
- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID {
    
//    NSLog(@"### pocketsphinxDidReceiveHypothesis: The received hypothesis is %@ with a score of %@ and an ID of %@", hypothesis, recognitionScore, utteranceID); // Log it.

    if (!hypothesis) {
        [self performSelectorOnMainThread:@selector(generateTPResultXMLikeStringFromResultString:) withObject:nil waitUntilDone:YES];
        return;
    }
}

#ifdef kGetNbest
- (void) pocketsphinxDidReceiveNBestHypothesisArray:(NSArray *)hypothesisArray { // Pocketsphinx has an n-best hypothesis dictionary.
    
//    NSLog(@"### pocketsphinxDidReceiveNBestHypothesisArray");
    
    NSString *oneHypothesis = [[hypothesisArray firstObject] objectForKey:@"Hypothesis"];
    if ([oneHypothesis isEqualToString:@""]) {
        NSLog(@"hypothesisArray is Empty");
    }else {//if ([testValue length] > 1)
//        NSLog(@"hypothesisArray is %@",oneHypothesis);
    }
    
    [self performSelectorOnMainThread:@selector(generateTPResultXMLikeStringFromResultString:) withObject:oneHypothesis waitUntilDone:YES];
    
    self.countNum++;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.countingLabel.text = [NSString stringWithFormat:@"Successful Count: %ld", self.countNum];
    });
    
    dispatch_semaphore_signal(self.sema);
    
}
#endif

#pragma mark - NSXMLParseDelegate is for parsing TPContext XML ONLY!

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict{
    
    // Parsing context/input xml files
    NSString *sentenceId = nil;
    if ([elementName isEqualToString:@"Sentence"]) {
        sentenceId = [attributeDict objectForKey:@"id"];
        aSentence = [NSMutableString string];
        if (sentenceId) {
            /*
             preGrammarDict = ["I CHECK MY NEWS",@"1";
                                           "YES",@"2";
                             ...];
             */
            [self.preGrammarDict setValue:aSentence forKey:sentenceId];
        }
    }else if ([elementName isEqualToString:@"Word"]){
        //
        // Each number could be transformed into one word
        //
        NSString *temp = [attributeDict objectForKey:@"display_trans"];
        NSArray *cleanWordArray = [[TPWordNormalizer manager] returnArrayByProcessWordString:temp];
//        NSLog(@"222 %@", [cleanWordArray firstObject]);
        
        // '1376' will be 'one three seven six'
        for (NSString *oneNumber in cleanWordArray) {
            [aSentence appendString:[oneNumber uppercaseString]];
            [aSentence appendString:@" "];
        }
    }
}

- (void)parserDidEndDocument:(NSXMLParser *)parser{
    // get rid the last space of each sentence
    for (NSString *aKey in [self.preGrammarDict allKeys]) {
        NSString *temp = [self.preGrammarDict objectForKey:aKey];
        [self.preGrammarDict setObject:[temp substringToIndex:[temp length]-1] forKey:aKey];
    }
    
//    NSLog(@"parserDidEndDocument?%@",self.preGrammarDict);
    
    NSDictionary *grammarDict;
    NSArray *theArray = [self.preGrammarDict allValues];
    if ([theArray count] == 1) {
        NSString *theSent = [theArray firstObject];
        grammarDict = @{OneOfTheseCanBeSaidOnce:[self makeThePossibleArrayFromWordsArray:[theSent componentsSeparatedByString:@" "]]};
        // The optional statement can be either "HELLO COMPUTER" or "GREETINGS ROBOT" or it can be omitted.
    } else {
        grammarDict = @{OneOfTheseWillBeSaidOnce:theArray};
        // an utterance will have exactly one of the following required statements: "DO THE FOLLOWING" or "INSTRUCTION"...
    }
    
    LanguageModelGenerator *languageModelGenerator = [[LanguageModelGenerator alloc] init];
    NSError *error = [languageModelGenerator generateGrammarFromDictionary:grammarDict withFilesNamed:@"grammarLangGenDict" forAcousticModelAtPath:[AcousticModel pathToModel:@"AcousticModelEnglish"]];
    NSDictionary *grammarLangGenDict = nil;
    if ([error code] != noErr) {
        NSLog(@"error: %@",[error description]);
    } else {
        
//        NSLog(@"parserDidEndDocument, on Thread: %@", [NSThread currentThread]);
        
        grammarLangGenDict = [error userInfo];
        
        NSString *lmPath = [grammarLangGenDict objectForKey:@"LMPath"];
        NSString *dictionaryPath = [grammarLangGenDict objectForKey:@"DictionaryPath"];
        

        self.pathToGrammarToStartAppWith = lmPath; // We'll set our new .languagemodel file to be the one to get switched to when the words "CHANGE MODEL" are recognized.
        self.pathToDictionaryToStartAppWith = dictionaryPath; // We'll set our new dictionary to be the one to get switched to when the words "CHANGE MODEL" are recognized.
    }
    
    [self startListening];
}

- (NSArray *)makeThePossibleArrayFromWordsArray:(NSArray *)wordsInSentArray {
    /*
     Create all the optioins from wordsInSentArray
     */
    int numOfWords = [wordsInSentArray count];
    
    NSMutableArray *sentsArray = [NSMutableArray array];
    for (int idx=0; idx<numOfWords; idx++) {
        // Reset the input array
        NSMutableArray *mWordsArray = [NSMutableArray arrayWithArray:wordsInSentArray];
        
        // Remove word(s) from the beginning
        for (int i = 0; i < idx; i++) {
            [mWordsArray removeObjectAtIndex:0];
        }
        
        // Make the new array
        NSMutableString *wordsString = [NSMutableString string];
        
        for (int i = 0; i < [mWordsArray count]; i++) {
            [wordsString appendFormat:@"%@ ",[mWordsArray objectAtIndex:i]];
        }
        
        [sentsArray addObject:[wordsString substringToIndex:[wordsString length]-1]];
    }
    
    return [NSArray arrayWithArray:sentsArray];
}


#pragma mark -
#pragma mark Private Methods

-(void) compareOpenEarsOutputString:(NSString *)aResult andQitaiXMLString:(NSString *)resultXmlString {// And write to disk
    
    NSDictionary * xmlDictionaryFromOE = [[XMLDictionaryParser sharedInstance] dictionaryWithData:[aResult dataUsingEncoding:NSUTF8StringEncoding]];
    NSDictionary * xmlDictionaryFromQT = [[XMLDictionaryParser sharedInstance] dictionaryWithString:resultXmlString];
    
    NSString *libDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *priAppDir = [libDir stringByAppendingPathComponent: @"Private Documents"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:priAppDir]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:priAppDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"FAILED TO CREATE %@",priAppDir);
        }
    }

    NSLog(@"%@ ------COMPARE RESULT------ %@",xmlDictionaryFromOE[@"Sentence"][@"_score"], xmlDictionaryFromQT[@"Sentence"][@"_score"]);
    
    NSString *qtSentScoreString = xmlDictionaryFromQT[@"Sentence"][@"_score"];// ignore unrecognized scores from qt
//    if ([qtSentScoreString floatValue] < 70.0) {
//        qtSentScore = @"(null)";
//    }
    
    NSString *oeSentScore;// ignore unrecognized scores from qt
    if ([xmlDictionaryFromOE[@"Sentence"][@"_score"] floatValue] > 70.0) {
        oeSentScore = @"71.00";
    }

    NSString *resultNodeString = [NSString stringWithFormat:@"%@---OE | QT---%@",oeSentScore, qtSentScoreString];
    
    if (!resultArray) {
        resultArray = [NSMutableArray arrayWithObject:resultNodeString];
    } else {
        [resultArray addObject:resultNodeString];
    }
    
    if (resultArray) {
        [resultArray writeToFile:[priAppDir stringByAppendingPathComponent:@"countList"]  atomically:YES];
    }
}

/*
 Recognition Final Result String Process Method: "resultStringArray" is the (first) part of the CORRECT sentence, which is an array containing words seperated by spaces.
 */
-(void)generateTPResultXMLikeStringFromResultString:(NSString *)resultString{
    NSString *correctSentID = nil;
    NSMutableArray *origArrayLeftover;
    
    // Tricky way to determine the sentence id key: "I CHECK MY NEWS"
    for (NSString *sentIdKey in [self.preGrammarDict allKeys]) {
        origArrayLeftover = [NSMutableArray arrayWithArray:[[self.preGrammarDict objectForKey:sentIdKey] componentsSeparatedByString:@" "]];
        NSNumber *countWhole = [NSNumber numberWithInt:[origArrayLeftover count]];
        
        [origArrayLeftover removeObjectsInArray:[resultString componentsSeparatedByString:@" "]];
        NSNumber *countLeft = [NSNumber numberWithInt:[origArrayLeftover count]];
        
        if ([countLeft floatValue]/[countWhole floatValue] <= (1.0-kPassPercentage/100.0)) {
            correctSentID = sentIdKey;
            break;// use the first hit anyway, 'coz faster speed:)
        }
    }
    
    NSMutableString *theResult = [[NSMutableString alloc] init];
    if (!correctSentID) {
        // error handling
        //        <TPResult version="1.0" error="8"></TPResult>
        int errCode = 8;
        [theResult appendFormat:@"<TPResult version=\"1.0\" error=\"%d\"></TPResult>",errCode];
    } else {
        [theResult appendFormat:@"<TPResult version=\"1.0\"><Sentence id=\"%@\" score=\"71\">",correctSentID];
        
        // For loop to generate the <Word></Word>
        NSMutableArray *origArray = [NSMutableArray arrayWithArray:[[self.preGrammarDict objectForKey:correctSentID] componentsSeparatedByString:@" "]];
        int numOfWords = [origArray count];// if "6543" -> "six five four three"(should be one word!)
        
//        NSArray *temp = [self makeThePossibleArrayFromWordsArray:origArray];
        // TODO: should show word by word ?
        int resultNumOfWords = [[resultString componentsSeparatedByString:@" "] count];
        int leftoverNumOfWords = [origArrayLeftover count];
        
        if (numOfWords == resultNumOfWords + leftoverNumOfWords) {
            // ------------------------------------------------------------
            // Get the beginning index of the result string in orig string!
            //
            // Step 1: Generate all the possible arrays
            NSMutableDictionary *tempDic = [NSMutableDictionary dictionary];
            for (int idx = 0; idx <= numOfWords-resultNumOfWords; idx++) {
                NSMutableString *tempString = [NSMutableString stringWithString:@""];
                for (int i = idx; i < idx+resultNumOfWords; i++) {
                    [tempString appendFormat:@"%@ ",[origArray objectAtIndex:i]];// Generate one possbile subset as a String
                }
                [tempDic setObject:[tempString substringToIndex:[tempString length]-1] forKey:[NSNumber numberWithInt:idx]];
            }
            
            // Step 2: Get the Index
            int startingIdx = 0;
            for (NSNumber *theIdx in [tempDic allKeys]) {
                if ([[tempDic objectForKey:theIdx] isEqualToString:resultString]) {
                    startingIdx = [theIdx intValue];
                }
            }
            // ------------------------------------------------------------
            
            
            // Highlight the words
            for (int i = 0; i<startingIdx; i++) {
                [theResult appendFormat:@"<Word id=\"%d\" trans=\"\" score=\"51\"></Word>",i];
            }
            for (int i = startingIdx; i<startingIdx+resultNumOfWords; i++) {
                [theResult appendFormat:@"<Word id=\"%d\" trans=\"\" score=\"71\"></Word>",i];
            }
            for (int i = startingIdx+resultNumOfWords; i<numOfWords; i++) {
                [theResult appendFormat:@"<Word id=\"%d\" trans=\"\" score=\"51\"></Word>",i];
            }
        } else {
            // error ?
        }
        
        [theResult appendString:@"</Sentence></TPResult>"];
    }
    
    //    if (wrapperDelegate && [wrapperDelegate respondsToSelector:@selector(engineWrapperEndsRecognitionWithResults:)]) {
    //        [wrapperDelegate engineWrapperEndsRecognitionWithResults:theResult];
    //    }
    

    // TODO: Compare theResult with *****.result from Qitai
    NSString *resultXmlFileName = [NSString stringWithFormat:@"%@.result",[fileNameString substringToIndex:[fileNameString length]-8]];
    NSData *xmlData = [NSData dataWithContentsOfFile:resultXmlFileName];
    NSString *xmlString = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];
    
    [self compareOpenEarsOutputString:theResult andQitaiXMLString:xmlString];
}

// The last class we're using here is LanguageModelGenerator but I don't think it's advantageous to lazily instantiate it. You can see how it's used below.

- (void) startListening {
    // But under normal circumstances you'll probably want to do continuous recognition as follows:
    self.pocketsphinxController.returnNullHypotheses = TRUE;
    //    self.pocketsphinxController.continuousModel.exitListeningLoop = NO;
    
//    NSLog(@"startListening");
    
    [self.pocketsphinxController runRecognitionOnWavFileAtPath:self.wavFilePath
                                      usingLanguageModelAtPath:self.pathToGrammarToStartAppWith
                                              dictionaryAtPath:self.pathToDictionaryToStartAppWith
                                           acousticModelAtPath:[AcousticModel pathToModel:@"AcousticModelEnglish"]
                                           languageModelIsJSGF:YES];
}

@end
