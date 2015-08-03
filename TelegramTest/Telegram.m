//
//  Telegram.m
//  TelegramTest
//
//  Created by Dmitry Kondratyev on 10/28/13.
//  Copyright (c) 2013 keepcoder. All rights reserved.
//

#import "Telegram.h"
#import "DialogsManager.h"
#import "TGTimer.h"
#import "TGEnterPasswordPanel.h"
#import "NSString+FindURLs.h"
#import "ASCommon.h"
#define ONLINE_EXPIRE 120
#define OFFLINE_AFTER 5

@interface Telegram()

@property (nonatomic, strong) TGTimer *accountStatusTimer;
@property (nonatomic, strong) TGTimer *accountOfflineStatusTimer;
@property (nonatomic, strong) RPCRequest *onlineRequest;

@end

@implementation Telegram

+(void)setConnectionState:(ConnectingStatusType)state {
    [[Telegram rightViewController].navigationViewController.nagivationBarView setConnectionState:state];
}

+ (Telegram *)sharedInstance {
    return [self delegate].telegram;
}

+(TL_conversation *)conversation {
    return [Telegram rightViewController].messagesViewController.conversation;
}

+ (AppDelegate *)delegate {
    return ((AppDelegate *)[NSApplication sharedApplication].delegate);
}

Telegram *TelegramInstance() {
    return [Telegram sharedInstance];
}

+ (MainViewController *)mainViewController {
    return (MainViewController *)[self delegate].mainWindow.rootViewController;
}

+ (RightViewController *)rightViewController {
    return [[self mainViewController] rightViewController];
}

+ (LeftViewController *)leftViewController {
    return [[self mainViewController] leftViewController];
}

+ (SettingsWindowController *)settingsWindowController {
    return [[self mainViewController] settingsWindowController];
}

+(NSUserDefaults *)standartUserDefaults {
    
    static NSUserDefaults *instance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [NSUserDefaults standardUserDefaults]; //[[NSUserDefaults alloc] initWithSuiteName:@"group.ru.keepcoder.Telegram"]
    });
    
    return instance;
}

- (id)init {
    self = [super init];
    if(self) {
        [self initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    [Notification addObserver:self selector:@selector(protocolUpdated:) name:PROTOCOL_UPDATED];
}

- (void)dealloc {
    [Notification removeObserver:self];
}


- (void)protocolUpdated:(NSNotification *)notify {
    [self.accountStatusTimer invalidate];
    self.accountStatusTimer = nil;
    self.accountStatusTimer = [[TGTimer alloc] initWithTimeout:ONLINE_EXPIRE - 5 repeat:YES completion:^{
        _isOnline = NO;
        [self setAccountOnline];
    } queue:[ASQueue globalQueue].nativeQueue];
    [self.accountStatusTimer start];
}

static int max_chat_users = 200;
static int max_broadcast_users = 100;

void setMaxChatUsers(int c) {
    max_chat_users = c;
}

int maxChatUsers() {
    return max_chat_users;
}

void setMaxBroadcastUsers(int b) {
    max_broadcast_users = b;
}

int maxBroadcastUsers() {
    return max_broadcast_users;
}

- (BOOL)canBeOnline {
    return true;
}

- (void)setAccountOffline:(BOOL)force {
    if([SettingsArchiver checkMaskedSetting:OnlineForever])
        return;
    
    if(force) {
        [self.accountOfflineStatusTimer invalidate];
        self.accountOfflineStatusTimer = nil;
        
        [self.onlineRequest cancelRequest];
        self.onlineRequest = [RPCRequest sendRequest:[TLAPI_account_updateStatus createWithOffline:YES] successHandler:^(RPCRequest *request, id response) {
            _isOnline = NO;
            
            [[UsersManager sharedManager] setUserStatus:[TL_userStatusOffline createWithWas_online:[[MTNetwork instance] getTime]] forUid:[UsersManager currentUserId]];
            
            MTLog(@"account is offline");
            
        } errorHandler:nil];
    } else {
        if(!self.accountOfflineStatusTimer) {
            self.accountOfflineStatusTimer = [[TGTimer alloc] initWithTimeout:OFFLINE_AFTER repeat:NO completion:^{
                [self setAccountOffline:YES];
            } queue:[ASQueue globalQueue].nativeQueue];
            [self.accountOfflineStatusTimer start];
        }
    }
}

- (void)setIsOnline:(BOOL)isOnline {
    self->_isOnline = isOnline;
    [Notification perform:USER_ONLINE_CHANGED data:nil];
}

- (void)setAccountOnline {
    
    
    if(![self canBeOnline]) {
        [self setAccountOffline:YES];
        return;
    }
    
    [self.accountOfflineStatusTimer invalidate];
    self.accountOfflineStatusTimer = nil;
    
    if([[UsersManager currentUser] isOnline])
        return;
    
    
    if([[MTNetwork instance] isAuth]) {
        [[UsersManager sharedManager] setUserStatus:[TL_userStatusOnline createWithExpires:[[MTNetwork instance] getTime] + ONLINE_EXPIRE] forUid:UsersManager.currentUserId];
        
        [self.onlineRequest cancelRequest];
        self.onlineRequest = [RPCRequest sendRequest:[TLAPI_account_updateStatus createWithOffline:NO] successHandler:^(RPCRequest *request, id response) {
            self.isOnline = YES;
            
            [[UsersManager sharedManager] setUserStatus:[TL_userStatusOnline createWithExpires:[[MTNetwork instance] getTime] + ONLINE_EXPIRE] forUid:[UsersManager currentUserId]];
            
            MTLog(@"account is online");
        } errorHandler:nil];
    }
}

- (void)makeFirstController:(TMViewController *)controller {
    [self.firstController setViewController:controller];
}

-(void)notificationDialogUpdate:(NSNotification *)notify {
    TL_conversation *d = [notify.userInfo objectForKey:KEY_DIALOG];
    [self showMessagesFromDialog:d sender:self];
}

- (void)showMessagesFromDialog:(TL_conversation *)d sender:(id)sender {
    [[Telegram rightViewController] showByDialog:d sender:(id)sender];
}

- (void)showMessagesWidthUser:(TLUser *)user sender:(id)sender {
    if(user == nil)
        return ELog(@"User nil");
    TL_conversation *dn = [[DialogsManager sharedManager] findByUserId:user.n_id];
    if(!dn) {
        dn = [[DialogsManager sharedManager] createDialogForUser:user];
    }
    
    
    [self showMessagesFromDialog:dn sender:sender];
}

- (void)showUserInfoWithUserId:(int)userID conversation:(TL_conversation *)conversation sender:(id)sender {
    TLUser  *user = [[UsersManager sharedManager] find:userID];
    
    [self showUserInfoWithUser:user conversation:conversation sender:sender];
}

- (void)showNotSelectedDialog {

    [[Telegram rightViewController] showNotSelectedDialog];
}


- (void)showUserInfoWithUser:(TLUser *)user conversation:(TL_conversation *)conversation sender:(id)sender {
    if(user == nil)
        return ELog(@"User nil");
    
    [[Telegram rightViewController] showUserInfoPage:user conversation:conversation];
    [[[Telegram mainViewController].view window] makeFirstResponder:nil];
}

- (void)onAuthSuccess {
    [[MTNetwork instance] successAuthForDatacenter:[[MTNetwork instance] currentDatacenter]];
    [[Telegram delegate] initializeMainWindow];
    [[MTNetwork instance].updateService update];
}

- (void)onLogoutSuccess {
//    [[Telegram delegate] initializeMainWindow];
}

BOOL isTestServer() {
    BOOL result = [[NSProcessInfo processInfo].environment[@"test_server"] boolValue];
    return result;
}

NSString * appName() {
    return isTestServer() ? @"telegram-test-server" : [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
}

+ (void)drop {
    [[[Telegram rightViewController] messagesViewController] drop];
}

- (void)hideModalView:(BOOL)isHide animation:(BOOL)animated {
    [[Telegram rightViewController] hideModalView:isHide animation:animated];
}

- (void)navigationGoBack {
    [[Telegram rightViewController] navigationGoBack];
}

- (BOOL)isModalViewActive {
    return [[Telegram rightViewController] isModalViewActive];
}

static TGEnterPasswordPanel *panel;

+(void)showEnterPasswordPanel {
    
    [ASQueue dispatchOnMainQueue:^{
        
        [panel removeFromSuperview];
        panel = nil;
        
        panel = [[TGEnterPasswordPanel alloc] initWithFrame:[[[[self delegate] window] contentView] bounds]];

        if(panel.superview)
            return;
        
        [[[self delegate] window].contentView addSubview:panel];
        [panel prepare];
    }];
}

+(TGEnterPasswordPanel *)enterPasswordPanel {
    return panel;
}


+(BOOL)isSingleLayout {
    return [[Telegram mainViewController] isSingleLayout];
}


+(void)saveHashTags:(NSString *)message peer_id:(int)peer_id {
    
    NSArray *locations = [message locationsOfHashtags];
    
    if(locations.count > 0) {
        
        [[Storage yap] readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            
            NSString *key = @"htags";
            
            if(peer_id != 0)
                key = [NSString stringWithFormat:@"htags_%d",peer_id];
            
            __block NSMutableDictionary *list = [transaction objectForKey:key inCollection:@"hashtags"];
            
            
            
            if(!list)
                list = [[NSMutableDictionary alloc] init];
            
            [locations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                
                NSString *tag = [[message substringWithRange:[obj range]] substringFromIndex:1];
                
                
                NSDictionary *localTag = list[tag];
                
                int count = [localTag[@"count"] intValue];
                
                localTag = @{@"count":@(++count),@"tag":tag};
                
                list[tag] = localTag;
                
                
            }];
            
            [transaction setObject:list forKey:key inCollection:@"hashtags"];
            
        }];
    }
    
}


+(void)sendLogs {
    __block TLUser *user = [UsersManager findUserByName:@"vihor"];
    
    dispatch_block_t performBlock = ^ {
        
        [[Telegram rightViewController] showByDialog:user.dialog sender:self];
        
        NSArray *files = TGGetLogFilePaths();
        
        [files enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [[Telegram rightViewController].messagesViewController sendDocument:obj forConversation:user.dialog];
        }];
        
    };
    
    if(user) {
        performBlock();
    } else {
        
        [TMViewController showModalProgress];
        
        [RPCRequest sendRequest:[TLAPI_contacts_search createWithQ:@"vihor" limit:1] successHandler:^(RPCRequest *request, TL_contacts_contacts *response) {
            
            if(response.users.count == 1) {
                
                [[UsersManager sharedManager] add:response.users withCustomKey:@"n_id" update:YES];
                
                user = response.users[0];
                
                performBlock();
            }
            
            [TMViewController hideModalProgress];
            
        } errorHandler:^(RPCRequest *request, RpcError *error) {
            [TMViewController hideModalProgress];
        }];
    }
}

+(void)initializeDatabase {
    [self.leftViewController.conversationsViewController initialize];
}

@end
