/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "RFBConnectionManager.h"
#import "RFBConnection.h"
#import "ProfileManager.h"
#import "Profile.h"
#import <signal.h>
#import "rfbproto.h"

#import "GrayScaleFrameBuffer.h"
#import "LowColorFrameBuffer.h"
#import "HighColorFrameBuffer.h"
#import "TrueColorFrameBuffer.h"

#define RFBColorModel		@"RFBColorModel"
#define RFBGammaCorrection	@"RFBGammaCorrection"
#define RFBLastHost		@"RFBLastHost"

#define RFBHostInfo		@"HostPreferences"
#define RFBLastDisplay		@"Display"
#define RFBLastProfile		@"Profile"

static RFBConnectionManager*	sharedManager = nil;

/* --------------------------------------------------------------------------------- */
static void	signal_handler(int signr)
{
static struct {
    int		number;
    BOOL	isFatal;		// if YES: terminate on signal
    char	*message;
} signals[] = {
    {SIGHUP, 	NO, 	"Hangup"},
    {SIGINT, 	YES, 	"Interrupt"},
    {SIGQUIT, 	NO, 	"Quit"},
    {SIGILL, 	YES, 	"Illegal instruction"},
    {SIGTRAP, 	YES, 	"Trace trap"}, /* jason changed to YES for fatal */
    {SIGIOT, 	YES, 	"IOT instruction"},
#ifdef SIGEMT
    {SIGEMT, 	YES, 	"EMT instruction"},
#endif
    {SIGFPE, 	YES, 	"Floating point exception"},
    {SIGKILL, 	NO, 	"Kill"},
    {SIGBUS, 	YES, 	"Bus error"},
    {SIGSEGV, 	YES, 	"Segmentation violation"},
#ifdef SIGSYS
    {SIGSYS, 	YES, 	"Bad argument to system call"},
#endif
    {SIGPIPE, 	NO, 	"Write on a pipe with no one to read it"},
    {SIGALRM, 	NO, 	"Alarm clock"},
    {SIGTERM, 	NO, 	"Software termination"},
    {SIGURG, 	NO, 	"Urgent condition present on socket"},
    {SIGSTOP, 	NO, 	"Stop"},
    {SIGTSTP, 	NO, 	"Stop signal generated from keyboard"},
    {SIGCONT, 	NO, 	"Continue after stop"},
    {SIGCHLD, 	NO, 	"Child status changed"},
    {SIGTTIN, 	NO, 	"Background read attempted from control terminal"},
    {SIGTTOU, 	NO, 	"Background write attempted to control terminal"},
    {SIGIO, 	NO, 	"I/O is possible on a descriptor"},
    {SIGXCPU, 	NO, 	"CPU time limit is exceeded"},
    {SIGXFSZ, 	NO, 	"File size limit exceeded"},
    {SIGVTALRM, NO, 	"Virtual timer alarm"},
    {SIGPROF, 	NO, 	"Profiling timer alarm"},
    {SIGWINCH, 	NO, 	"Window size change"},
    {SIGUSR1, 	NO, 	"User defined signal 1"},
    {SIGUSR2, 	NO, 	"User defined signal 2"},
};
char	*signame = NULL;
int		i;
BOOL	isFatal = NO;

    for(i=0;i<sizeof(signals)/sizeof(signals[0]);i++){
        if(signals[i].number == signr){
            signame = signals[i].message;
            isFatal = signals[i].isFatal;
            break;
        }
    }
    if(signame == NULL)
        printf("%s: *** signal %d occured.\n", __FILE__, signr);
    else
		printf("%s: *** signal %d occured: %s.\n", __FILE__, signr, signame);
    if(isFatal){
        if(signr == SIGINT){	// exit normally, we want a profile
            printf("terminating normally\n");
            exit(1);
        }else
            exit(1);
    }
}

/* --------------------------------------------------------------------------------- */
static void install_signals(void)
{
int		i;

    for(i=0;i<32;i++){
        signal(i, signal_handler);
    }
}

@implementation RFBConnectionManager

// Jason added the +initialize method
+ (void)initialize {
    id ud = [NSUserDefaults standardUserDefaults];
	id dict = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects: @"128", @"10000", [NSNumber numberWithFloat: 26.0], [NSNumber numberWithFloat: 0.0], nil] forKeys: [NSArray arrayWithObjects: @"PS_MAXRECTS", @"PS_THRESHOLD", @"FullscreenAutoscrollIncrement", @"FullscreenScrollbars", nil]];
	[ud registerDefaults: dict];
}

- (id)init
{    
    sigblock(sigmask(SIGPIPE));
    connections = [[NSMutableArray alloc] init];
    sharedManager = self;
    return [super init];
}

- (void)savePrefs
{
    id ud = [NSUserDefaults standardUserDefaults];

    [ud setInteger:[[colorModelMatrix selectedCell] tag] + 1 forKey:RFBColorModel];
    [ud setObject:[gamma stringValue] forKey:RFBGammaCorrection];
    [ud setObject:[psMaxRects stringValue] forKey:@"PS_MAXRECTS"];
    [ud setObject:[psThreshold stringValue] forKey:@"PS_THRESHOLD"];
	// jason added the rest
    [ud setFloat: floor([autoscrollIncrement floatValue] + 0.5) forKey:@"FullscreenAutoscrollIncrement"];
    [ud setBool:[fullscreenScrollbars floatValue] forKey:@"FullscreenScrollbars"];
}

- (void)updateProfileList:(id)notification
{
	// Jason changed the following line because the original was a reference
    NSString* current = [[[profilePopup titleOfSelectedItem] copy] autorelease];
//    NSString* current = [profilePopup titleOfSelectedItem];
    
    [profilePopup removeAllItems];
    [profilePopup addItemsWithTitles:[profileManager profileNames]];
    [profilePopup selectItemWithTitle:current];
}

- (void)updateLoginPanel
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* hi = [ud objectForKey:RFBHostInfo];
    NSDictionary* h = [hi objectForKey:[hostName stringValue]];

    if(h != nil) {
        [display setStringValue:[h objectForKey:RFBLastDisplay]];
        [profilePopup selectItemWithTitle:[h objectForKey:RFBLastProfile]];
    }
}

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* hi = [ud objectForKey:RFBHostInfo];
    NSDictionary* h = [hi objectForKey:aHost];
    NSDictionary* names = [h objectForKey:@"NameTranslations"];
    NSString* news;
	
    if((news = [names objectForKey:aName]) == nil) {
        news = aName;
    }
    return news;
}

- (void)setDisplayNameTranslation:(NSString*)translation forName:(NSString*)aName forHost:(NSString*)aHost
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary* hi, *h, *names;

    hi = [[[ud objectForKey:RFBHostInfo] mutableCopy] autorelease];
    if(hi == nil) {
        hi = [NSMutableDictionary dictionary];
    }
    h = [[[hi objectForKey:aHost] mutableCopy] autorelease];
    if(h == nil) {
        h = [NSMutableDictionary dictionary];
    }
    names = [[[h objectForKey:@"NameTranslations"] mutableCopy] autorelease];
    if(names == nil) {
        names = [NSMutableDictionary dictionary];
    }
    [names setObject:translation forKey:aName];
    [h setObject:names forKey:@"NameTranslations"];
    [hi setObject:h forKey:aHost];
    [ud setObject:hi forKey:RFBHostInfo];
}

- (void)awakeFromNib
{
    int i;
    NSString* s;
    id ud = [NSUserDefaults standardUserDefaults];

    install_signals();
    [profileManager wakeup];
    i = [ud integerForKey:RFBColorModel];
    if(i == 0) {
        NSWindowDepth d = [[NSScreen mainScreen] depth];
        if(NSNumberOfColorComponents(NSColorSpaceFromDepth(d)) == 1) {
            i = 1;
        } else {
            int bps = NSBitsPerSampleFromDepth(d);

            if(bps < 4)		i = 2;
            else if(bps < 8)	i = 3;
            else		i = 4;
        }
    }
    [colorModelMatrix selectCellWithTag:i - 1];
    if((s = [ud objectForKey:RFBGammaCorrection]) == nil) {
        s = [gamma stringValue];
    }
    [gamma setFloatingPointFormat:NO left:1 right:2];
    [gamma setFloatValue:[s floatValue]];
	// jason added the following because, well, it was missing
	[psThreshold setStringValue: [ud stringForKey: @"PS_THRESHOLD"]];
	[psMaxRects setStringValue: [ud stringForKey: @"PS_MAXRECTS"]];
    [autoscrollIncrement setFloatValue: [ud floatForKey:@"FullscreenAutoscrollIncrement"]];
    [fullscreenScrollbars setFloatValue: [ud boolForKey:@"FullscreenScrollbars"]];
	// end jason
    [self updateProfileList:nil];
    if((s = [ud objectForKey:RFBLastHost]) != nil) {
        [hostName setStringValue:s];
    }
    [self updateLoginPanel];
    [loginPanel makeKeyAndOrderFront:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProfileList:) name:ProfileAddDeleteNotification object:nil];
}

- (void)dealloc
{
    [connections release];
    [super dealloc];
}

- (void)removeConnection:(id)aConnection
{
    [aConnection retain];
    [connections removeObject:aConnection];
    [aConnection autorelease];
}

- (void)connect:(id)sender
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* d;
    NSMutableDictionary* hi, *h;
    RFBConnection* theConnection;
    Profile* profile;

    [ud setObject:[hostName stringValue] forKey:RFBLastHost];
    hi = [[[ud objectForKey:RFBHostInfo] mutableCopy] autorelease];
    if(hi == nil) {
        hi = [NSMutableDictionary dictionary];
    }
    h = [[[hi objectForKey:[hostName stringValue]] mutableCopy] autorelease];
    if(h == nil) {
        h = [NSMutableDictionary dictionary];
    }
    [hi setObject:h forKey:[hostName stringValue]];
    [h setObject:[display stringValue] forKey:RFBLastDisplay];
    [h setObject:[profilePopup titleOfSelectedItem] forKey:RFBLastProfile];
    [ud setObject:hi forKey:RFBHostInfo];
    
    d = [NSDictionary dictionaryWithObjectsAndKeys:
        [hostName stringValue],			RFB_HOST,
        [passWord stringValue],			RFB_PASSWORD,
        [display stringValue],			RFB_DISPLAY,
        [shared intValue] ? @"1" : @"0" ,	RFB_SHARED,
        NULL, NULL];
    if(![rememberPwd intValue]) {
        [passWord setStringValue:@""];
    }
    profile = [profileManager profileNamed:[profilePopup titleOfSelectedItem]];
	// Jason changed for fullscreen mode
    theConnection = [[[RFBConnection alloc] initWithDictionary:d profile:profile owner:self] autorelease];
//    theConnection = [[[RFBConnection alloc] initWithDictionary:d andProfile:profile] autorelease];
    if(theConnection) {
        [theConnection setManager:self];
        [connections addObject:theConnection];
        [loginPanel orderOut:self];
    }
}

- (void)preferencesChanged:(id)sender
{
    [self savePrefs];
}

- (id)defaultFrameBufferClass
{
    switch([[colorModelMatrix selectedCell] tag]) {
        case 0: return [GrayScaleFrameBuffer class];
        case 1: return [LowColorFrameBuffer class];
        case 2: return [HighColorFrameBuffer class];
        case 3: return [TrueColorFrameBuffer class];
        default: return [TrueColorFrameBuffer class];
    }
}

+ (void)getLocalPixelFormat:(rfbPixelFormat*)pf
{
    id fbc = [sharedManager defaultFrameBufferClass];

    [fbc getPixelFormat:pf];
}

+ (float)gammaCorrection
{
    return [sharedManager->gamma floatValue];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [self savePrefs];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    [self updateLoginPanel];
}

// Jason added the following for full-screen windows
- (void)makeAllConnectionsWindowed {
	NSEnumerator *connectionEnumerator = [connections objectEnumerator];
	RFBConnection *thisConnection;

	while (thisConnection = [connectionEnumerator nextObject]) {
		if ([thisConnection connectionIsFullscreen])
			[thisConnection makeConnectionWindowed: self];
	}
}

@end
