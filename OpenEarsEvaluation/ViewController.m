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
#import <OpenEars/OEPocketsphinxController.h> // Please note that unlike in previous versions of OpenEars, we now link the headers through the framework.
#import <OpenEars/OELanguageModelGenerator.h>
#import <OpenEars/OELogging.h>
#import <OpenEars/OEAcousticModel.h>

#import "TPWordNormalizer.h"
#import "XMLDictionary.h"
#import "TextNormalizer.h"

#define kFileDownloaded @"ZipFileDownloaded"
#define kFileUnzipped @"FileUnzipped"

#define kPassRateThresholdInSentence 0.59
#define kPassPercentageInAllHypotheses 0.50

@interface ViewController () <ZipArchiveDelegate>
{
    // output array to write to countList
    NSMutableArray *resultArray;
    
    // input sentence from TP XML to feed into PocketSphinx
    NSMutableString *aSentence;
    
    // for comparison testing
    NSString *fileNameString;
    
    NSMutableArray * currentWords;
    NSMutableDictionary * currentSentences;
    bool isSpeechDetected;
}

@property (nonatomic, strong) NSMutableDictionary *preGrammarDict;
@property (nonatomic, strong) NSString *wavFilePath;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;

@property (nonatomic, strong) dispatch_semaphore_t sema;
@property (nonatomic, strong) dispatch_queue_t queue;

@property (weak, nonatomic) IBOutlet UILabel *countingLabel;
@property (nonatomic, assign) NSUInteger countNum;

@property (nonatomic, copy) NSString * pathToLanguageModelToStartAppWith;
@end

@implementation ViewController

@synthesize restartAttemptsDueToPermissionRequests,startupFailedDueToLackOfPermissions;
@synthesize pathToGrammarToStartAppWith, pathToDictionaryToStartAppWith, pathToLanguageModelToStartAppWith;

#define kPassPercentage 50.0

#define kGetNbest // Uncomment this if you want to try out nbest

#pragma mark -
#pragma mark Lazy Allocation

// Lazily allocated PocketsphinxController.
- (OEPocketsphinxController *)pocketsphinxController {
    if (_pocketsphinxController == nil) {
        _pocketsphinxController = [OEPocketsphinxController sharedInstance];
        [_pocketsphinxController setActive:YES error:nil];
        //pocketsphinxController.verbosePocketSphinx = TRUE; // Uncomment me for verbose debug output
        //pocketsphinxController.outputAudio = TRUE;
        _pocketsphinxController.returnNullHypotheses = YES;
#ifdef kGetNbest
        _pocketsphinxController.returnNbest = TRUE;
        _pocketsphinxController.nBestNumber = 100;
#endif
    }
    return _pocketsphinxController;
}

// Lazily allocated OpenEarsEventsObserver.
- (OEEventsObserver *)openEarsEventsObserver {
    if (_openEarsEventsObserver == nil) {
        _openEarsEventsObserver = [[OEEventsObserver alloc] init];
    }
    return _openEarsEventsObserver;
}



#pragma mark -
#pragma mark View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.restartAttemptsDueToPermissionRequests = 0;
    self.startupFailedDueToLackOfPermissions = FALSE;
    
    [OELogging startOpenEarsLogging]; // Uncomment me for OpenEarsLogging
    
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
    
    NSString *resultXmlFileName = [NSString stringWithFormat:@"%@.result",[fileNameString substringToIndex:[fileNameString length]-8]];
    NSData *xmlData = [NSData dataWithContentsOfFile:resultXmlFileName];
    NSString *xmlString = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];
    
    if ([xmlString containsString:@"<TPResult version=\"1.0\" error=\""]) {
        dispatch_semaphore_signal(self.sema);
        return;
    }
    
    NSData *contextXmlData = [[NSData alloc] initWithContentsOfFile:fileNameString];
    
    aSentence = nil;
    self.preGrammarDict = [NSMutableDictionary dictionary];
    
    // XML formatted Strings are strange
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:contextXmlData];//[contextXml dataUsingEncoding:NSUTF8StringEncoding]];
    xmlParser.delegate = self;
    
    if ([xmlParser parse] == NO ) {
        NSLog(@"Failed to start xml parser");
    } else {
//        NSLog(@"%@",xmlString);
    }
}

- (void)downloadFile {
    
    self.statusLabel.text = @"Downloading";
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSURL *URL = [NSURL URLWithString:@"http://10.128.43.101:8000/ASR_RESULTS_QT-OE-HUMAN.zip"];
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
        
//        [self downloadFile];
    }
    
}



#pragma mark -
#pragma mark OpenEarsEventsObserver delegate methods

// An optional delegate method of OpenEarsEventsObserver which delivers the text of speech that Pocketsphinx heard and analyzed, along with its accuracy score and utterance ID.
- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID {
    
}

- (void) pocketsphinxDidStartListening {
    isSpeechDetected = NO;
}

- (void) pocketsphinxDidDetectSpeech {
    isSpeechDetected = YES;
}


-(void) pocketsphinxTestRecognitionCompleted {
    if(!isSpeechDetected)
    {
//        [self.sphinxController stopListening];
    }
}

- (void) pocketsphinxFailedNoMicPermissions {
    self.startupFailedDueToLackOfPermissions = TRUE;
}


- (void) micPermissionCheckCompleted:(BOOL)result {
    if(result == TRUE) {
        self.restartAttemptsDueToPermissionRequests++;
        if(self.restartAttemptsDueToPermissionRequests == 1 && self.startupFailedDueToLackOfPermissions == TRUE) {
            [self startListening]; // Only do this once.
            self.startupFailedDueToLackOfPermissions = FALSE;
        }
    }
}

#ifdef kGetNbest
- (void) pocketsphinxDidReceiveNBestHypothesisArray:(NSArray *)hypothesisArray { // Pocketsphinx has an n-best hypothesis dictionary.
    
    self.countNum++;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.countingLabel.text = [NSString stringWithFormat:@"Successful Count: %ld", self.countNum];
    });
    

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self compareWithHypothesisArray:hypothesisArray];
    });
    
//    dispatch_semaphore_signal(self.sema);
    
}
#endif

#pragma mark - NSXMLParseDelegate is for parsing TPContext XML ONLY!

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict{
    
    if([elementName isEqualToString:@"Sentence"] )
    {
        NSString * sentence = [[[[TextNormalizer sharedNormalizer] normalizedStringWithInput:[attributeDict objectForKey:@"display_trans"]] stringByReplacingOccurrencesOfString:@"  " withString:@" "] uppercaseString];
        [currentSentences setObject:sentence forKey:[NSNumber numberWithInt:[[attributeDict objectForKey:@"id"] intValue]]];
        [currentWords addObject:sentence];
    }
}

- (void)parserDidStartDocument:(NSXMLParser *)parser {
    currentWords = [NSMutableArray new];
    currentSentences = [NSMutableDictionary new];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser{
    [self createLanguageModelWithWords:[NSArray arrayWithArray:currentWords]];
}

#pragma mark -
#pragma mark Private Methods

-(void)createLanguageModelWithWords:(NSArray*)words
{
    OELanguageModelGenerator *lmGenerator = [[OELanguageModelGenerator alloc] init];
    NSString *name = @"generatedLanguageModel";
    
//    NSDictionary *grammarDict =  @{OneOfTheseCanBeSaidOnce : words};
//    NSError *err = [lmGenerator generateGrammarFromDictionary:grammarDict withFilesNamed:name forAcousticModelAtPath:[OEAcousticModel pathToModel:@"AcousticModelEnglish"]];
    
    NSError *err = [lmGenerator generateLanguageModelFromArray:words withFilesNamed:name forAcousticModelAtPath:[OEAcousticModel pathToModel:@"AcousticModelEnglish"]];
    if(err == nil) {
        self.pathToLanguageModelToStartAppWith = [lmGenerator pathToSuccessfullyGeneratedLanguageModelWithRequestedName:name];
//        self.pathToGrammarToStartAppWith = [lmGenerator pathToSuccessfullyGeneratedGrammarWithRequestedName:name];
        self.pathToDictionaryToStartAppWith = [lmGenerator pathToSuccessfullyGeneratedDictionaryWithRequestedName:name];
        NSLog(@"\nlm %@ \ngrammar %@ \nDictionary\n%@", self.pathToLanguageModelToStartAppWith,
              [NSString stringWithContentsOfFile:self.pathToGrammarToStartAppWith encoding:NSUTF8StringEncoding error:nil],
              [NSString stringWithContentsOfFile:self.pathToDictionaryToStartAppWith encoding:NSUTF8StringEncoding error:nil]);
        
        [self startListening];
    } else {
        NSLog(@"Error Model: %@",[err localizedDescription]);
    }
}

-(void) compareOpenEarsOutputString:(NSString *)aResult andQitaiXmlFileName:(NSString *)fileName {// And write to disk
    // Read theResult as *****.result from Qitai
    NSString *resultXmlFileName = [NSString stringWithFormat:@"%@.result",fileName];
    NSData *xmlData = [NSData dataWithContentsOfFile:resultXmlFileName];
    NSString *resultXmlString = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];

    NSDictionary * xmlDictionaryFromOE = [[XMLDictionaryParser sharedInstance] dictionaryWithData:[aResult dataUsingEncoding:NSUTF8StringEncoding]];
    NSDictionary * xmlDictionaryFromQT = [[XMLDictionaryParser sharedInstance] dictionaryWithString:resultXmlString];


    /*
     For Geregory
     / Read theResult as *****.context from Qitai
     */
    NSString *contextXmlFileName = [NSString stringWithFormat:@"%@.context",fileName];
    NSData *contextXmlData = [NSData dataWithContentsOfFile:contextXmlFileName];
    NSString *contextXmlString = [[NSString alloc] initWithData:contextXmlData encoding:NSUTF8StringEncoding];
    NSDictionary * contextXmlDictionaryFromQT = [[XMLDictionaryParser sharedInstance] dictionaryWithString:contextXmlString];

    
    // Find the proper folder
    NSString *libDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *priAppDir = [libDir stringByAppendingPathComponent: @"Private Documents"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:priAppDir]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:priAppDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"FAILED TO CREATE %@",priAppDir);
        }
    }
    
    BOOL isQtPassed, isOEPassed;
    NSString *qtSentScoreString = xmlDictionaryFromQT[@"Sentence"][@"_score"];// ignore unrecognized scores from qt
    NSString *qtSentScore;
    if ([qtSentScoreString doubleValue] < 70.0000000) {
        qtSentScore = [NSString stringWithFormat:@"NO :%@", qtSentScoreString];
        isQtPassed = NO;
    } else {
        qtSentScore = [NSString stringWithFormat:@"YES:%@", qtSentScoreString];
        isQtPassed = YES;
    }
    
    NSString *oeSentScore;// ignore unrecognized scores from qt
    if ([xmlDictionaryFromOE[@"Sentence"][@"_score"] floatValue] > 70.0) {
        oeSentScore = @"PASSED ";
        isOEPassed = YES;
    } else {
        oeSentScore = @"NOTPASS";
        isOEPassed = NO;
    }


    /*
     For Geregory
     / Read theResult as *****.context from Qitai
     */
    NSString *resultSentID = xmlDictionaryFromQT[@"Sentence"][@"_id"];
    NSString *displayTrans;
    
    if ([contextXmlDictionaryFromQT[@"Sentences"][@"Sentence"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *theDict = contextXmlDictionaryFromQT[@"Sentences"][@"Sentence"];
        displayTrans = theDict[@"_display_trans"];;
    } else {
        for (NSDictionary *oneDict in contextXmlDictionaryFromQT[@"Sentences"][@"Sentence"]) {
            if ([oneDict[@"_id"] isEqualToString:resultSentID]) {
                displayTrans = oneDict[@"_display_trans"];
            }
        }
    }
//    NSLog(@"%@",displayTrans);

    NSString *resultNodeString;
    if (isOEPassed != isQtPassed) {
        resultNodeString = [NSString stringWithFormat:@"%@---OE | QT---%@ DIFF:%@ Pass  |||'%@'",oeSentScore, qtSentScore, isQtPassed?@"QT":@"OE", displayTrans];
    } else {
        resultNodeString = [NSString stringWithFormat:@"%@---OE | QT---%@ NODIFFERENCE: |||'%@'",oeSentScore, qtSentScore, displayTrans];
    }
    
    NSString *resultNodeStringNew = [NSString stringWithFormat:@"%@ |||file:%@", resultNodeString, [[fileName componentsSeparatedByString:@"Documents"] lastObject]];

    if (!resultArray) {
        resultArray = [NSMutableArray arrayWithObject:resultNodeStringNew];
    } else {
        [resultArray addObject:resultNodeStringNew];
    }
    
    if (resultArray) {
        [resultArray writeToFile:[priAppDir stringByAppendingPathComponent:@"countList"]  atomically:YES];
    }
    
    dispatch_semaphore_signal(self.sema);
}

-(void)compareWithHypothesisArray:(NSArray*) hypothesisArray
{
    NSString * result;
    int correctSentenceId = -1;
    for (NSNumber * key in currentSentences.allKeys) {
        int correctCounter = 0;
        
        BOOL isPassed = NO;
        
        for (NSDictionary * hypoDict in hypothesisArray) {
            NSString *inputStringValue = [[[currentSentences objectForKey:key] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
            NSString *outputStringValue= [[[hypoDict objectForKey:@"Hypothesis"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
            
            /*
              Comment out the old/live solution to use the Edit Distance instead
             */
//            double outputInputRatio = (double)[outputStringValue componentsSeparatedByString:@" "].count/[inputStringValue componentsSeparatedByString:@" "].count;
//            if([inputStringValue containsString:outputStringValue] && outputInputRatio>kPassRateThresholdInSentence && outputInputRatio<=1.0)
//                correctCounter++;
            
            if (outputStringValue == nil || outputStringValue.length == 0) continue;
            
            NSArray *refArray = [inputStringValue componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            float distanceValue = [self compareArrayA:refArray withArrayB:[outputStringValue componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
            NSLog(@"edit distance %f / %@", distanceValue, outputStringValue);
            
            
            if ((1.0 - distanceValue/refArray.count) > kPassRateThresholdInSentence) {
                correctCounter++;
                isPassed = YES;
            }
            
        }

        if (isPassed) {
            correctSentenceId = key.intValue;
            break;
        }

        /*
         Comment out the old/live solution to use the Edit Distance instead
         */
        // if 50% out of 150 best hypothesis, which is more than 75 correct hits
//        if (correctCounter >= (ceil(hypothesisArray.count * kPassPercentageInAllHypotheses))) {
//            correctSentenceId = key.intValue;
//            break;
//        }
    }
    
    if(correctSentenceId!=-1)
        result = [NSString  stringWithFormat:@"<TPResult version=\"1.0\"><Sentence id=\"%i\" score=\"71.00\"></Sentence></TPResult>", correctSentenceId];
    else
        result = @"<TPResult version=\"1.0\"><Sentence id=\"-1\" score=\"00.00\"></Sentence></TPResult>";
    
    [self compareOpenEarsOutputString:result andQitaiXmlFileName:[fileNameString substringToIndex:[fileNameString length]-8]];
}

- (void) startListening {
    [self.pocketsphinxController runRecognitionOnWavFileAtPath:self.wavFilePath
                                      usingLanguageModelAtPath:self.pathToLanguageModelToStartAppWith
                                              dictionaryAtPath:self.pathToDictionaryToStartAppWith
                                           acousticModelAtPath:[OEAcousticModel pathToModel:@"AcousticModelEnglish"]
                                           languageModelIsJSGF:FALSE];
}

-(float)compareArrayA:(NSArray *)arrayA withArrayB:(NSArray *)arrayB {
    
    // Step 1
    int k, i, j, cost, * d, distance;
    
    NSInteger n = [arrayA count];
    NSInteger m = [arrayB count];
    
    if( n++ != 0 && m++ != 0 ) {
        
        d = malloc( sizeof(int) * m * n );
        
        // Step 2
        for( k = 0; k < n; k++)
            d[k] = k;
        
        for( k = 0; k < m; k++)
            d[ k * n ] = k;
        
        // Step 3 and 4
        for( i = 1; i < n; i++ )
            for( j = 1; j < m; j++ ) {
                
                // Step 5
                if( [[arrayA objectAtIndex: i-1] isEqualToString:[arrayB objectAtIndex: j-1]] )
                    cost = 0;
                else
                    cost = 1;
                
                // Step 6
                d[ j * n + i ] = [self smallestOf: d [ (j - 1) * n + i ] + 1
                                            andOf: d[ j * n + i - 1 ] +  1
                                            andOf: d[ (j - 1) * n + i -1 ] + cost ];
            }
        
        distance = d[ n * m - 1 ];
        
        free( d );
        
        return distance;
    }
    return 0.0;
}

// return the minimum of a, b and c
- (int) smallestOf: (int) a andOf: (int) b andOf: (int) c
{
    int min = a;
    if ( b < min )
        min = b;
    
    if( c < min )
        min = c;
    
    return min;
}

@end
