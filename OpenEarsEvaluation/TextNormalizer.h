//
//  TextNormalizer.h
//  
//
//  Created by Alaa Eddine Cherbib on 6/2/15.
//  Copyright (c) 2015 EF. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TextNormalizer : NSObject
{
    NSDictionary * digitReplacements;
    NSDictionary * timeReplacements;
    NSString * pattern;
    int countOfWord;
    int countOfIllegal;
    int countOfPunctuation;
    int countOfWildCard;
    int countOfNumber;
    int countOfWhiteSpace;
    int countOfPhoneNumber;
    int countOfUnitary;
    int countOfTime;
    int countOfOrdinal;
    int countOfKm;
    int countOfCurrency;
    int countOfPronounce;
    int countOfReplacementText;
    int legalMatches;
    int timeGroupIndex;
    int illegalGroupIndex;
    int unitaryCharactersGroupIndex;
    int phoneNumberGroupIndex;
    int currencyGroupIndex;
    int numberGroupIndex;
    int numberPositionGroupIndex;
    int wordGroupIndex;
    int punctuationGroupIndex;
    int wildCardGroupIndex;
    int whiteSpaceGroupIndex;
    int replaceTextGroupIndex;
    int pronounceGroupIndex;
}

+(id)sharedNormalizer;
-(NSString*)normalizedStringWithInput:(NSString*)input;



@end
