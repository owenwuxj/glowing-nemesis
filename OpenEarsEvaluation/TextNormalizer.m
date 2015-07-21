//
//  TextNormalizer.m
//
//
//  Created by Alaa Eddine Cherbib on 6/2/15.
//  Copyright (c) 2015 EF. All rights reserved.
//

#import "TextNormalizer.h"

@implementation TextNormalizer

static TextNormalizer * shared;

+ (id) sharedNormalizer{
    static TextNormalizer *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!_instance) {
            _instance = [[TextNormalizer alloc] init];
        }
    });
    return _instance;
}

- (instancetype)init
{
    if ((self = [super init])) {
        
        [self initReplacementsDictionaries];
    }
    return self;
}


-(void) initReplacementsDictionaries
{
    
    pattern = @"(((\\d{1,2}\\.\\d{2} *(pm|p.m|a.m|am)+)|(\\d{1,2}:\\d{2} *(pm|p.m|a.m|am)?)))|(\\\"+|\\b'+|'+\\b|'+$|^'+|\\(.*\\)|;+|:+)|(\\u002B|\\u0025)|((\\d+)([ -]\\d+)+)|((\\u0024)?(((\\d{1,3}((,?\\d{3})|\\d{0,3}){0,3}))(\\.\\d+)?)(st|rd|nd|th)*)|([a-zA-Z]+'*[a-zA-Z]*)|([,!.?:;-]+)|(_+)|(\\s+)|(\\[.+=[a-z' ]+\\])|(<.+=(([a-z]{1}[a-z0-9]?|\\u002B|\\.|_\\^|_!|_&|_,|_\\.|_\\?|_s) ?)+>)";
    timeGroupIndex = 1;
    illegalGroupIndex = 7;
    unitaryCharactersGroupIndex = 8;
    phoneNumberGroupIndex = 9;
    currencyGroupIndex = 13;
    numberGroupIndex = 14;
    numberPositionGroupIndex = 20;
    wordGroupIndex = 21;
    punctuationGroupIndex = 22;
    wildCardGroupIndex = 23;
    whiteSpaceGroupIndex = 24;
    replaceTextGroupIndex = 25;
    pronounceGroupIndex = 26;
    
    
    countOfWord = 0;
    countOfIllegal = 0;
    countOfPunctuation = 0;
    countOfWildCard = 0;
    countOfNumber = 0;
    countOfWhiteSpace = 0;
    countOfPhoneNumber = 0;
    countOfUnitary = 0;
    countOfTime = 0;
    countOfOrdinal = 0;
    countOfKm = 0;
    countOfCurrency = 0;
    countOfPronounce = 0;
    countOfReplacementText = 0;
    legalMatches = -1;
    
    digitReplacements = @{
                          @"0": @"zero",
                          @"1": @"one",
                          @"2": @"two",
                          @"3": @"three",
                          @"4": @"four",
                          @"5": @"five",
                          @"6": @"six",
                          @"7": @"seven",
                          @"8": @"eight",
                          @"9": @"nine",
                          @"10": @"ten",
                          @"11": @"eleven",
                          @"12": @"twelve",
                          @"13": @"thirteen",
                          @"14": @"fourteen",
                          @"15": @"fifteen",
                          @"16": @"sixteen",
                          @"17": @"seventeen",
                          @"18": @"eighteen",
                          @"19": @"nineteen",
                          @"20": @"twenty",
                          @"30": @"thirty",
                          @"40": @"forty",
                          @"50": @"fifty",
                          @"60": @"sixty",
                          @"70": @"seventy",
                          @"80": @"eighty",
                          @"90": @"ninety",
                          @"100": @"one hundred",
                          
                          
                          @"zeroth": @"zeroth",
                          @"onest": @"first",
                          @"twond": @"second",
                          @"threerd": @"third",
                          @"fourth": @"fourth",
                          @"fiveth": @"fifth",
                          @"sixth": @"sixth",
                          @"seventh": @"seventh",
                          @"eightth": @"eigth",
                          @"nineth": @"ninth",
                          @"tenth": @"tenth",
                          @"eleventh": @"eleventh",
                          @"twelveth": @"twelfth",
                          @"thirteenth": @"thirteenth",
                          @"fourteenth": @"fourteenth",
                          @"fifteenth": @"fifteenth",
                          @"sixteenth": @"sixteenth",
                          @"seventeenth": @"seventeenth",
                          @"eighteenth": @"eighteenth",
                          @"nineteenth": @"nineteenth",
                          @"twentyth": @"twentieth",
                          @"thirtyth": @"thirtieth",
                          @"fortyth": @"fortieth",
                          @"fiftyth": @"fiftieth",
                          @"sixtyth": @"sixtieth",
                          @"seventyth": @"seventieth",
                          @"eightyth": @"eightieth",
                          @"ninetyth": @"ninetieth",
                          @"hundredth": @"hundreth",
                          @"thousandth": @"thousandth"};
    
    timeReplacements = @{
                         @"bc": @"B.C",
                         @"ad": @"A.D",
                         @"pm": @"P.M",
                         @"am": @"A.M"};
    
    
    
    
}

-(NSString*)normalizedStringWithInput:(NSString*)input
{
    
    NSError *error = NULL;
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    
    NSMutableString * result = [NSMutableString new];
    NSArray *matches = [regex matchesInString:input options:0 range:NSMakeRange(0, input.length)];
    for (NSTextCheckingResult *match in matches) {
        
        NSString * wildCard = nil;
        NSString * number = nil;
        NSString * word = nil;
        NSString * punctuation = nil;
        NSString * whiteSpace = nil;
        NSString * phoneNumber = nil;
        NSString * unitaryCharacters = nil;
        NSString * replaceText = nil;
        NSString * pronounce = nil;
        bool dropAllPunctuation = YES;
        NSString * time = nil;
        
        if ([match rangeAtIndex:wildCardGroupIndex].location!= NSNotFound) {
            wildCard = [input substringWithRange:[match rangeAtIndex:wildCardGroupIndex]];
        }
        if ([match rangeAtIndex:numberGroupIndex].location!= NSNotFound) {
            number = [input substringWithRange:[match rangeAtIndex:numberGroupIndex]];
        }
        if ([match rangeAtIndex:wordGroupIndex].location!= NSNotFound) {
            word = [input substringWithRange:[match rangeAtIndex:wordGroupIndex]];
        }
        if ([match rangeAtIndex:punctuationGroupIndex].location!= NSNotFound) {
            punctuation = [input substringWithRange:[match rangeAtIndex:punctuationGroupIndex]];
        }
        if ([match rangeAtIndex:whiteSpaceGroupIndex].location!= NSNotFound) {
            whiteSpace = [input substringWithRange:[match rangeAtIndex:whiteSpaceGroupIndex]];
        }
        if ([match rangeAtIndex:phoneNumberGroupIndex].location!= NSNotFound) {
            phoneNumber = [input substringWithRange:[match rangeAtIndex:phoneNumberGroupIndex]];
        }
        if ([match rangeAtIndex:unitaryCharactersGroupIndex].location!= NSNotFound) {
            unitaryCharacters = [input substringWithRange:[match rangeAtIndex:unitaryCharactersGroupIndex]];
        }
        if ([match rangeAtIndex:timeGroupIndex].location!= NSNotFound) {
            time = [input substringWithRange:[match rangeAtIndex:timeGroupIndex]];
        }
        
        if ([match rangeAtIndex:replaceTextGroupIndex].location!= NSNotFound) {
            replaceText = [input substringWithRange:[match rangeAtIndex:replaceTextGroupIndex]];
        }
        
        if ([match rangeAtIndex:pronounceGroupIndex].location!= NSNotFound) {
            pronounce = [input substringWithRange:[match rangeAtIndex:pronounceGroupIndex]];
        }
        
        
        if (replaceText)
        {
            legalMatches++;
            if (legalMatches > 0)
            {
                [result appendString:@" "];
            }
            
            NSString * splitValue = replaceText;
            splitValue = [splitValue substringWithRange:NSMakeRange(1, replaceText.length - 1)];
            NSArray * splitArray = [splitValue componentsSeparatedByString:@"="];
            
            NSArray * parts;
            if(splitArray.count>=2)
                parts = [NSArray arrayWithObjects:[[splitValue componentsSeparatedByString:@"="] objectAtIndex:0], [[splitValue componentsSeparatedByString:@"="] objectAtIndex:1], nil];
            else if(splitArray.count>=1)
                parts = [NSArray arrayWithObjects:[[splitValue componentsSeparatedByString:@"="] objectAtIndex:0], nil];
            
            NSString * text = [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            [result appendString:@" "];
            [result appendString:text];
            countOfReplacementText++;
        }
        else if (pronounce)
        {
            legalMatches++;
            
            if (legalMatches > 0)
            {
                [result appendString:@" "];
            }
            
            NSString* splitValue = pronounce;
            splitValue = [splitValue substringWithRange:NSMakeRange(1, pronounce.length - 1)];
            NSArray * splitArray = [splitValue componentsSeparatedByString:@"="];
            NSArray * parts;
            if(splitArray.count>=2)
                parts = [NSArray arrayWithObjects:[[splitValue componentsSeparatedByString:@"="] objectAtIndex:0], [[splitValue componentsSeparatedByString:@"="] objectAtIndex:1], nil];
            else if(splitArray.count>=1)
                parts = [NSArray arrayWithObjects:[[splitValue componentsSeparatedByString:@"="] objectAtIndex:0], nil];
            
            NSString * display = [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [result appendString:@" "];
            [result appendString:display];
            countOfPronounce++;
        }else  if (word  || number  || phoneNumber  || unitaryCharacters  || time )
        {
            legalMatches++;
            if (legalMatches > 0)
            {
                [result appendString:@" "];
            }
            
            if (word )
            {
                countOfWord++;
                
                NSString * wordKey = [word lowercaseString];
                
                if ([digitReplacements.allKeys containsObject:wordKey])
                {
                    [result appendString:[digitReplacements objectForKey:wordKey]];
                }
                else
                {
                    [result appendString:word];
                }
            }
            else if (unitaryCharacters )
            {
                countOfUnitary++;
                
                if ([unitaryCharacters isEqualToString:@"%"])
                {
                    [result appendString:@"percent"];
                }
                else if([unitaryCharacters isEqualToString:@"+"])
                {
                    [result appendString:@"plus"];
                }
            }
            else if (time )
            {
                countOfTime++;
                
                NSString * lowerTimeValue =[time lowercaseString];
                
                NSString * meridian = nil;
                NSString * timePortion = nil;
                
                int indexOfP = (int)[lowerTimeValue rangeOfString:@"p"].location;
                int indexOfA = (int)[lowerTimeValue rangeOfString:@"a"].location;
                
                if ([lowerTimeValue rangeOfString:@"p"].location!=NSNotFound)
                {
                    meridian = [[lowerTimeValue substringFromIndex:indexOfP ]stringByReplacingOccurrencesOfString:@"." withString:@""];
                    timePortion = [[lowerTimeValue substringWithRange:NSMakeRange(0, indexOfP)] stringByReplacingOccurrencesOfString:@"." withString:@":"];
                }
                else if ([lowerTimeValue rangeOfString:@"a"].location!=NSNotFound)
                {
                    meridian = [[lowerTimeValue substringFromIndex:indexOfA ]stringByReplacingOccurrencesOfString:@"." withString:@""];
                    timePortion = [[lowerTimeValue substringWithRange:NSMakeRange(0, indexOfA)] stringByReplacingOccurrencesOfString:@"." withString:@":"];
                }
                else
                {
                    timePortion = [lowerTimeValue  stringByReplacingOccurrencesOfString:@"." withString:@":"];
                }
                
                if (meridian)
                {
                    if ([timeReplacements.allKeys containsObject:meridian])
                    {
                        meridian = [timeReplacements objectForKey:meridian];
                    }
                    
                    meridian = [meridian uppercaseString];
                }
                
                NSArray * timePortionParts = [timePortion componentsSeparatedByString:@":"];
                
                double hourPart = [timePortionParts[0] doubleValue];
                NSNumberFormatter * numberFormatter = [[NSNumberFormatter alloc] init];
                [numberFormatter setNumberStyle:NSNumberFormatterSpellOutStyle];
                [numberFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
                [result appendString:[numberFormatter stringFromNumber:[NSNumber numberWithDouble:hourPart]]];
                double minutePart = [timePortionParts[1] doubleValue];
                
                if (minutePart > 0)
                {
                    [result appendString:@" "];
                    
                    if (minutePart < 10)
                    {
                        [result appendString:@"O"];
                        [result appendString:@" "];
                    }
                    
                    [result appendString:[numberFormatter stringFromNumber:[NSNumber numberWithDouble:minutePart]]];
                }
                
                if (meridian)
                {
                    [result appendString:@" "];
                    [result appendString:meridian];
                }
            }
            else if (phoneNumber)
            {
                countOfPhoneNumber++;
                NSArray * numbers = [phoneNumber componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -"]];
                
                for (int i = 0; i < numbers.count - 1; i++)
                {
                    NSString* numberPart = numbers[i];
                    
                    for (int j = 0; j < numberPart.length; j++)
                    {
                        char digit = [numberPart characterAtIndex:j];
                        [result appendString:[digitReplacements objectForKey:[NSString stringWithFormat:@"%c",digit]]];
                        [result appendString:@" "];
                    }
                }
                
                NSString* lastNumber = numbers[numbers.count - 1];
                
                for (int j = 0; j < lastNumber.length - 1; j++)
                {
                    char digit = [lastNumber characterAtIndex:j];
                    [result appendString:[digitReplacements objectForKey:[NSString stringWithFormat:@"%c",digit]]];
                    [result appendString:@" "];
                }
                
                [result appendString:[digitReplacements objectForKey:[NSString stringWithFormat:@"%c",[lastNumber characterAtIndex:lastNumber.length - 1]]]];
            }
            else if (number)
            {
                countOfNumber++;
                NSString * numberPosition = nil;
                if([match rangeAtIndex:numberPositionGroupIndex].location != NSNotFound)
                {
                    numberPosition = [input substringWithRange:[match rangeAtIndex:numberPositionGroupIndex]];
                }
                NSString * currencySymbol = nil;
                if([match rangeAtIndex:currencyGroupIndex].location != NSNotFound)
                    currencySymbol = [input substringWithRange:[match rangeAtIndex:currencyGroupIndex]];
                
                if (currencySymbol)
                {
                    NSLog(@"currency");
                    countOfCurrency++;
                }
                
                NSString * numberValue = number;
                NSString * ordinalValue = nil;
                
                if (numberPosition)
                {
                    countOfOrdinal++;
                    ordinalValue = [numberPosition substringFromIndex:numberPosition.length - 2];
                }
                NSNumberFormatter * numberFormatter = [[NSNumberFormatter alloc] init];
                [numberFormatter setNumberStyle:NSNumberFormatterSpellOutStyle];
                [numberFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
                
                double amount = [[numberValue stringByReplacingOccurrencesOfString:@"," withString:@""] doubleValue];
                NSMutableArray *  numberWords = [NSMutableArray arrayWithArray:[[[numberFormatter stringFromNumber:[NSNumber numberWithDouble:amount]]stringByReplacingOccurrencesOfString:@"-" withString:@" "] componentsSeparatedByString:@" "]];
                
                NSString * numberText = nil;
                
                if (ordinalValue)
                {
                    ordinalValue = [NSString stringWithFormat:@"%@%@",numberWords[numberWords.count - 1], ordinalValue];
                    NSString * newLastNumberWord = [digitReplacements objectForKey:ordinalValue];
                    numberWords [numberWords.count - 1] = newLastNumberWord;
                }
                NSMutableString * strBuilder = [NSMutableString new];
                for (int w = 0; w< numberWords.count-1; w++) {
                    NSString * str = numberWords[w];
                    [strBuilder appendString:str];
                    [strBuilder appendString:@" "];
                    
                }
                [strBuilder appendString:numberWords[numberWords.count-1]];
                numberText = [NSString stringWithString:strBuilder];
                
                if (currencySymbol  && ordinalValue )
                {
                    [result appendString:@"dollar "];
                }
                
                [result appendString:numberText];
                
                if (currencySymbol && !ordinalValue)
                {
                    if([currencySymbol isEqualToString:@"$"] || true)
                    {
                        [result appendString:(amount == 1 ? @" dollar" : @" dollars")];
                    }
                }
            }
        }
        else if (punctuation)
        {
            countOfPunctuation++;
            if(!dropAllPunctuation)
            {
                [result appendString:punctuation];
            }
        }
        else if (wildCard)
        {
            legalMatches++;
            
            if (legalMatches > 0)
            {
                [result appendString:@" "];
            }
            
            countOfWildCard++;
            
            [result appendString:@"_"];
        }
        
        [result appendString:@" "];
    }
    
    NSString * output = [[NSString stringWithString:[result stringByReplacingOccurrencesOfString:@"-" withString:@" "]]stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    return [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
@end
