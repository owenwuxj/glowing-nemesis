//
//  EFTPWordNormalizer.m
//  EfektaStudyPlan
//
//  Created by OwenWu on 28/11/14.
//  Copyright (c) 2014 EF Englishtown. All rights reserved.
//

#import "TPWordNormalizer.h"

static TPWordNormalizer *sharedInstance;

@implementation TPWordNormalizer

+(instancetype)manager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        sharedInstance =[[TPWordNormalizer alloc] init];
    });
    
    return sharedInstance;
}


/*
 Step 1(a): If "'" doesn't appear in the middle(of the word), then delete it
 */
- (NSString *)dealWord:(NSString*)aWord withSingleNotation:(NSString *)aNotation{
    NSMutableString *outputString;
    NSArray *shouldBeArrays = [aWord componentsSeparatedByString:aNotation];
    
    // Only handle one single notation in the word
    if ([shouldBeArrays count] == 2) {
        if ([[shouldBeArrays lastObject] length] != 0 && [[shouldBeArrays firstObject] length] != 0) {
            // appear in the middle, do nothing
            outputString = [NSMutableString stringWithString:aWord];
        } else if ([[shouldBeArrays firstObject] length] == 0) {
            // appear in the beginning
            outputString = (NSMutableString *)[shouldBeArrays lastObject];
        } else { //[[shouldBeArrays lastObject] length] == 0
            // appear in the end
            outputString = (NSMutableString *)[shouldBeArrays firstObject];
        }
    } else if ([shouldBeArrays count] == 3) {// handle 'word'
        // so get the middle
        outputString = (NSMutableString *)shouldBeArrays[1];
    } else {
        // 1 means no notation in the word AND >= 4 means crazy!
        // So, 1 or 4 or more are all cutted to use the last obj
        outputString = (NSMutableString *)[shouldBeArrays lastObject];
    }
    
    return outputString;
}

- (NSArray *)spellOutOneOrTwoDigitsNumberArray:(NSArray *)inputArray isOrdinal:(BOOL)ordinal {
    NSMutableArray *output = [NSMutableArray array];
    
    for (NSString *wordNumber in inputArray) {
        NSNumber *numberValue = [NSNumber numberWithInt:[wordNumber intValue]]; //needs to be NSNumber!
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        [numberFormatter setNumberStyle:NSNumberFormatterSpellOutStyle];
        NSString *numberWord = [numberFormatter stringFromNumber:numberValue];
        NSArray *twoSyllables = [numberWord componentsSeparatedByString:@"-"];
        NSString *firstWord = [twoSyllables firstObject];
        
        if (ordinal) {
            if ([twoSyllables count] == 1) {
                NSString *replacedFirstWord;
                if ([firstWord isEqualToString:@"one"]) {
                    replacedFirstWord = @"first";
                } else if ([firstWord isEqualToString:@"two"]) {
                    replacedFirstWord = @"second";
                } else if ([firstWord isEqualToString:@"three"]) {
                    replacedFirstWord = @"third";
                } else if ([firstWord isEqualToString:@"four"]) {
                    replacedFirstWord = @"fourth";
                } else if ([firstWord isEqualToString:@"five"]) {
                    replacedFirstWord = @"fifth";
                } else if ([firstWord isEqualToString:@"six"]) {
                    replacedFirstWord = @"sixth";
                } else if ([firstWord isEqualToString:@"seven"]) {
                    replacedFirstWord = @"seventh";
                } else if ([firstWord isEqualToString:@"eight"]) {
                    replacedFirstWord = @"eighth";
                } else if ([firstWord isEqualToString:@"nine"]) {
                    replacedFirstWord = @"ninetieth";
                } else if ([firstWord isEqualToString:@"ten"]) {
                    replacedFirstWord = @"tenth";
                } else if ([firstWord isEqualToString:@"eleven"]) {
                    replacedFirstWord = @"eleventh";
                } else if ([firstWord isEqualToString:@"twelve"]) {
                    replacedFirstWord = @"twelfth";
                } else if ([firstWord isEqualToString:@"thirteen"]) {
                    replacedFirstWord = @"thirteenth";
                } else if ([firstWord isEqualToString:@"fourteen"]) {
                    replacedFirstWord = @"fourteenth";
                } else if ([firstWord isEqualToString:@"fifteen"]) {
                    replacedFirstWord = @"fifteenth";
                } else if ([firstWord isEqualToString:@"sixteen"]) {
                    replacedFirstWord = @"sixteenth";
                } else if ([firstWord isEqualToString:@"seventeen"]) {
                    replacedFirstWord = @"seventeenth";
                } else if ([firstWord isEqualToString:@"eighteen"]) {
                    replacedFirstWord = @"eighteenth";
                } else if ([firstWord isEqualToString:@"nineteen"]) {
                    replacedFirstWord = @"nineteenth";
                } else if ([firstWord isEqualToString:@"twenty"]) {
                    replacedFirstWord = @"twentieth";
                } else if ([firstWord isEqualToString:@"thirty"]) {
                    replacedFirstWord = @"thirtieth";
                } else if ([firstWord isEqualToString:@"forty"]) {
                    replacedFirstWord = @"fortieth";
                } else if ([firstWord isEqualToString:@"fifty"]) {
                    replacedFirstWord = @"fiftieth";
                } else if ([firstWord isEqualToString:@"sixty"]) {
                    replacedFirstWord = @"sixtieth";
                } else if ([firstWord isEqualToString:@"seventy"]) {
                    replacedFirstWord = @"seventieth";
                } else if ([firstWord isEqualToString:@"eighty"]) {
                    replacedFirstWord = @"eightieth";
                } else if ([firstWord isEqualToString:@"ninety"]){
                    replacedFirstWord = @"ninetieth";
                }
                [output addObject:replacedFirstWord];
            } else {
                [output addObject:firstWord];
                NSString *secWord = [twoSyllables lastObject];
                
                NSString *replacedWord;
                if ([secWord isEqualToString:@"one"]) {
                    replacedWord = @"first";
                } else if ([secWord isEqualToString:@"two"]) {
                    replacedWord = @"second";
                } else if ([secWord isEqualToString:@"three"]) {
                    replacedWord = @"third";
                } else if ([secWord isEqualToString:@"four"]) {
                    replacedWord = @"fourth";
                } else if ([secWord isEqualToString:@"five"]) {
                    replacedWord = @"fifth";
                } else if ([secWord isEqualToString:@"six"]) {
                    replacedWord = @"sixth";
                } else if ([secWord isEqualToString:@"seven"]) {
                    replacedWord = @"seventh";
                } else if ([secWord isEqualToString:@"eight"]) {
                    replacedWord = @"eighth";
                } else if ([secWord isEqualToString:@"nine"]) {
                    replacedWord = @"ninetieth";
                }
                [output addObject:replacedWord];
            }
        } else {
            [output addObject:firstWord];
            
            if ([twoSyllables count] != 1) {
                [output addObject:[twoSyllables lastObject]];
            }
        }
    }
    
    return output;
}

- (NSArray *)generateArrayByColon:(NSString *)aWord{
    NSMutableArray *generatedArray = [NSMutableArray arrayWithArray:[aWord componentsSeparatedByString:@":"]];
    
    // Only handle one colon in the word
    if ([generatedArray count] == 2) {
        // TODO: MOBILE-4425
        return [self spellOutOneOrTwoDigitsNumberArray:generatedArray isOrdinal:NO];
    }
    
    return nil;
}

//-(NSString *)processString:(NSString *)singleWordFromTP{
-(NSArray *)returnArrayByProcessWordString:(NSString *)inputString {
    /*
     All cases:  a. If the single notation doesn't appear in the middle(of the WORD), delete it/them. Or, b. If : appears, generate 2 words.
     Then, c. If the first letter is a number
     1. Get rid of "am/pm" and "A.D/B.C", and accetp variations like "Half past Five"=="Five Thirty" (SPECIAL CASE!)
     2. If TH RD ST RD appear in the end, get rid of them and replace the number with "zeroth" "third" "first"
     3. If there are only two continuous numbers in the string, replace them with one word
     4. If there are more than two continuous numbers, replace each number with one word (MOSTLY TIME, SO SPECIAL CASE!)
     */
    
    
    /*
     Step 1(a): If "'"/"." doesn't appear in the middle(of the word), then delete it/them
     */
    NSString *outputString0 = [self dealWord:inputString withSingleNotation:@"'"];
    NSString *outputString = [self dealWord:outputString0 withSingleNotation:@"."];
    NSMutableArray *processedTxtArray = [NSMutableArray arrayWithObject:outputString];
    
    /*
     Step 2(b): If ":" appear in the middle(of the word)
     */
    // (SPECIAL CASE!)
    NSArray *timeStringArray = [self generateArrayByColon:outputString];
    if (timeStringArray) {
        return timeStringArray;
    }
    
    /*
     Step 3(c): If the first letter is number:
     dealing with the suffix firstly of all
     */
    NSString *cleanWordString;
    if (48 <= [outputString characterAtIndex:0] && [outputString characterAtIndex:0] <= 57) {//0 ~ 9
        
        // case 1: get rid of "am/pm" and "A.D/B.C", and accetp variations like "Half past Five"=="Five Thirty"
        //        if ([outputString rangeOfString:@"AM"].location != NSNotFound
        //            || [outputString rangeOfString:@"PM"].location != NSNotFound) {
        //            // delete the last 2 letters
        //            NSString *lastWithAPM = outputString;
        //            lastWithout = [lastWithAPM substringToIndex:[lastWithAPM length]-2];
        //        }
        
        //
        if ([[outputString uppercaseString] rangeOfString:@"A.D."].location != NSNotFound)
            //            || [[outputString uppercaseString] rangeOfString:@"B.C."].location != NSNotFound)
        {
            // replace the last with AD
            NSString *lastWithADBC = outputString;
            cleanWordString = [lastWithADBC substringToIndex:[lastWithADBC length] - 4];
            NSMutableArray *processedArrayAD = [NSMutableArray arrayWithObjects:cleanWordString, @"AD", nil];
            return processedArrayAD;
        }
        
        
        // case 2: If TH RD ST RD appear in the end, get rid of them and replace the number with "zeroth" "third" "first"
        if ([[outputString uppercaseString] rangeOfString:@"TH"].location != NSNotFound
            || [[outputString uppercaseString] rangeOfString:@"ST"].location != NSNotFound
            || [[outputString uppercaseString] rangeOfString:@"ND"].location != NSNotFound
            || [[outputString uppercaseString] rangeOfString:@"RD"].location != NSNotFound ) {
            // delete the last 2
            NSString *lastWithADBC = outputString;
            cleanWordString = [lastWithADBC substringToIndex:[lastWithADBC length] - 2];
            NSArray *processedArrayTH = [self spellOutOneOrTwoDigitsNumberArray:[NSMutableArray arrayWithObject:cleanWordString]
                                                                      isOrdinal:YES];
            return processedArrayTH;
        }
        
        NSUInteger output2Length = [outputString length];
        
        // case 3: If there are only two continuous numbers in the string, replace them with one word
        if (output2Length <= 2) {
            // Not Ordinal
            return [self spellOutOneOrTwoDigitsNumberArray:[NSArray arrayWithObject:outputString] isOrdinal:NO];
            
        }
        
        // case 4: If there are more than two continuous numbers, replace each number with one word
        NSMutableArray *outputArray3 = [NSMutableArray arrayWithCapacity:output2Length];
        
        // Done Case!
        if (output2Length > 2) {// replace 1 by one
            for (int idx = 0; idx < [outputString length]; idx++) {
                //convert to words
                NSString *temp = [NSString stringWithFormat:@"%c", [outputString characterAtIndex:idx]];
                NSNumber *numberValue = [NSNumber numberWithInt:[temp intValue]]; //needs to be NSNumber!
                NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                numberFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
                [numberFormatter setNumberStyle:NSNumberFormatterSpellOutStyle];
                [outputArray3 addObject:[[numberFormatter stringFromNumber:numberValue] uppercaseString]];
            }
            return outputArray3;
        }
        
    }
    
    return processedTxtArray;
}

@end
