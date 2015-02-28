//
//  NormalizerWordFinder.h
//  OpenEarsSampleApp
//
//  Created by OwenWu on 12/11/14.
//  Copyright (c) 2014 Politepix. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TPWordNormalizer : NSObject

+(instancetype)manager;

-(NSArray *)returnArrayByProcessWordString:(NSString *)inputString;

@end
