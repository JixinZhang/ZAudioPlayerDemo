//
//  NSObject+DictionaryToModel.h
//  RuntimeDemo
//
//  Created by WSCN on 24/07/2017.
//  Copyright © 2017 wallstreetcn.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (DictionaryToModel)

+ (instancetype)modelWithDict:(NSDictionary *)dict;

+ (instancetype)modelWithDict2:(NSDictionary *)dict;

+ (NSDictionary *)modelCustomPropertyMapper;

+ (NSDictionary *)arrayContainModelClass;

@end
