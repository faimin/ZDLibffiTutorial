//
//  ZDLibffiController.m
//  ZDLibffiDemo
//
//  Created by Zero.D.Saber on 2019/12/12.
//  Copyright © 2019 Zero.D.Saber. All rights reserved.
//

#import "ZDLibffiController.h"
#import "NSObject+ZDAOP.h"

@interface ZDLibffiController ()

@end

@implementation ZDLibffiController

+ (void)load {
    [self zd_hookInstanceMethod:@selector(x:y:z:) option:ZDHookOption_After callback:^(NSInteger a, NSString *b, id c){
        NSLog(@"###########收到Hook信息 ==> 小狗%zd岁了, %@, %@", a, b, c);
    }];
}

- (void)dealloc {
    printf("%s, %d\n", __PRETTY_FUNCTION__, __LINE__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    id r = [self x:110 y:@"阿尔托莉雅·潘德拉贡" z:NSObject.new];
    NSLog(@"$$$$$$$$$$$$ %s => %@", __PRETTY_FUNCTION__, r);
}

- (id)x:(NSInteger)a y:(NSString *)b z:(id)c {
    NSString *ret = [NSString stringWithFormat:@"%zd + %@ + %@", a, b, c];
    NSLog(@"result = %@", ret);
    return ret;
}

@end
