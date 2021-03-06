//
//  DmxOutput.m
//  Toerst
//
//  Created by Recoil Performance Group on 21/02/13.
//  Copyright (c) 2013 HalfdanJ. All rights reserved.
//

#import "DmxOutput.h"
#import <ofxCocoaPlugins/Cameras.h>

#define NUM_CHANNELS 19

@implementation DmxOutput

@synthesize isConnected = _isConnected;

-(void)initPlugin{
    NSLog(@"Setup dmx pro");
    
    dmxPro = new DmxPro();
    dmxPro->connect("tty.usbserial-EN096602", 512);
    
    self.isConnected = dmxPro->isConnected();
    
    for(int i=0;i<NUM_CHANNELS;i++){
        [[self addPropF:[NSString stringWithFormat:@"channel%02i",i+1]] setMaxValue:255];
        [[self addPropF:[NSString stringWithFormat:@"channel%02ipatch",i+1]] setMaxValue:513];
    }
    
    [Prop(@"channel17") bind:@"value" toObject:Prop(@"channel16") withKeyPath:@"value" options:nil];
    [Prop(@"channel18") bind:@"value" toObject:Prop(@"channel16") withKeyPath:@"value" options:nil];
    [Prop(@"channel19") bind:@"value" toObject:Prop(@"channel16") withKeyPath:@"value" options:nil];
    
    
    [[self addPropF:@"frontLamp"] setMaxValue:127];
    
    [[self addPropF:@"lfoSpeed"] setMaxValue:60];
    [[self addPropF:@"lfoMin"] setMaxValue:127];
    [[self addPropF:@"lfoMax"] setMaxValue:127];
    
    [[self addPropF:@"lfoTime"] setMaxValue:1];
    [[self addPropF:@"lfoBlink"] setMaxValue:1];
    [self addPropB:@"lfoNorm"];
    
    [[self addPropF:@"shutter"] setMaxValue:255];
    [self addPropB:@"led1"];
    [self addPropB:@"led2"];

    [self addPropB:@"setCameraSettings"];
    
    
    SetPropF(@"lfoTime",0);
    
    oscSender = new ofxOscSender;
    oscSender->setup("255.255.255.255", 1313);

    oscSenderProj = new ofxOscSender;

    oscSenderProj->setup("10.0.1.177", 10000);
    //    oscSenderProj->setup("localhost", 10000);
    
    
    
}


-(void)update:(NSDictionary *)drawingInformation{
    if(PropF(@"lfoSpeed")){
        CachePropF(lfoTime);
        float inc = (PropF(@"lfoSpeed")/60.0) * 1.0/ofGetFrameRate();;
        if(inc > 0 && inc < 1)
            lfoTime +=  inc;
        
        
        
        if(lfoTime > 1)
            lfoTime-= 1;

        SetPropF(@"lfoTime", lfoTime);
        
        
        float sinVal = (cos(lfoTime*TWO_PI)+1)/2;
        
        if(PropB(@"lfoNorm")) {
            sinVal = (fabs(sinVal*2-1));
        }
        SetPropF(@"frontLamp", ofMap(sinVal, 0,1,PropF(@"lfoMin"), PropF(@"lfoMax")));
        
       // [GetPlugin(Midi) sendValue:PropI(@"frontLamp") forNote:0 onChannel:1];
        
    }
    if( PropF(@"lfoBlink")){
        SetPropF(@"frontLamp", ofMap(PropF(@"lfoBlink"), 0,1,PropF(@"lfoMin"), PropF(@"lfoMax")));

    }
}


-(void)awakeFromNib{
    
    /*NSRect viewFrame = self.view.frame;
    viewFrame.size.height = NUM_CHANNELS*40 + 160;
    [self.view setFrame:viewFrame];
    */
    
    
    int u=0;
    for(int i=NUM_CHANNELS-1;i>=0;i--){
        NSRect frame = NSMakeRect(12, (u-10)*40, 140, 22);
        
        if(u <= 9){
            frame = NSMakeRect(500, (u)*40, 140, 22);
        }
        
        {
            NSTextField * label= [[NSTextField alloc] initWithFrame:frame];
            [label setDrawsBackground:NO];
            [label setEditable:NO];
            [label setStringValue:[NSString stringWithFormat:@"%i",i+1]];
            [label setBezeled:NO];
            [self.view addSubview:label];
        }
        
        frame.origin.x += 20;
        {
            NSSlider * slider = [[NSSlider alloc] initWithFrame:frame];
            [slider bind:@"value" toObject:Prop(([NSString stringWithFormat:@"channel%02i", i+1])) withKeyPath:@"value" options:nil];
            [slider setMaxValue:255];
            
            [self.view addSubview:slider];
        }
        
        
        frame.origin.x += 150;
        frame.size.width = 40;
        
        {
            NSTextField * textField = [[NSTextField alloc] initWithFrame:frame];
            [textField bind:@"value" toObject:Prop(([NSString stringWithFormat:@"channel%02i", i+1])) withKeyPath:@"value" options:nil];
            
            NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
            [formatter setAllowsFloats:NO];
            [textField setFormatter:formatter];
            [self.view addSubview:textField];
            
        }

        
        
        
        frame.origin.x += 80;
        frame.size.width = 40;
        
        {
            NSTextField * label= [[NSTextField alloc] initWithFrame:frame];
            [label setDrawsBackground:NO];
            [label setEditable:NO];
            [label setStringValue:@"adr."];
            [label setBezeled:NO];
            [self.view addSubview:label];
        }
        
        frame.origin.x += 30;


        {
            NSTextField * textField = [[NSTextField alloc] initWithFrame:frame];
            [textField bind:@"value" toObject:Prop(([NSString stringWithFormat:@"channel%02ipatch", i+1])) withKeyPath:@"value" options:nil];
            
            NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
            [formatter setAllowsFloats:NO];
            [textField setFormatter:formatter];
            [self.view addSubview:textField];

        }
        
        frame.origin.x += 37;
        frame.size.width = 15;
        
        {
            NSStepper * stepper = [[NSStepper alloc] initWithFrame:frame];
            [stepper setMaxValue:511];
            [stepper setMinValue:1];
            [stepper setAutorepeat:YES];
            [stepper bind:@"value" toObject:Prop(([NSString stringWithFormat:@"channel%02ipatch", i+1])) withKeyPath:@"value" options:nil];
            [self.view addSubview:stepper];
        }
        
        

        u++;
    }
    
    
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if(object == Prop(@"led1")){
        ofxOscMessage msg;
        msg.setAddress("/relay/1");
        msg.addIntArg(PropB(@"led1"));
        
        
       // ofxOscBundle bundle;
       // bundle.addMessage(msg);
       // oscSenderProj->sendBundle(bundle);
         oscSenderProj->sendMessage(msg);
    }
    if(object == Prop(@"setCameraSettings") && PropB(@"setCameraSettings")){
        SetPropB(@"setCameraSettings", 0);
        Cameras * cameras = GetPlugin(Cameras);
        CameraInstance * camera = [cameras getCamera:0].cameraInstance;
        
        [camera setValue:[NSNumber numberWithInt:30000] forKey:@"exposure"];
        [camera setValue:[NSNumber numberWithInt:20] forKey:@"gain"];
    }
    if(object == Prop(@"led2")){
        ofxOscMessage msg;
        msg.setAddress("/relay/2");
        msg.addIntArg(PropB(@"led2"));
        
        oscSenderProj->sendMessage(msg);
    }
    
    if(object == Prop(@"shutter")){
        ofxOscMessage msg;
        msg.setAddress("/shutter/1");
        msg.addIntArg(PropI(@"shutter"));
        
        oscSenderProj->sendMessage(msg);
    }
    if(object == Prop(@"frontLamp")){
    //    dispatch_async(dispatch_get_main_queue(), ^{
            [GetPlugin(Midi) sendValue:PropI(@"frontLamp") forNote:0 onChannel:1];
     //   });
    }

    for(int i=0;i<NUM_CHANNELS;i++){
        NSString * propPatch= [NSString stringWithFormat:@"channel%02ipatch", i+1];
        if(object == Prop(propPatch)){
            
            if([[change valueForKey:@"old"] intValue] > 0 && [[change valueForKey:@"old"] intValue] <= 511){
                dmxPro->sendLevel([[change valueForKey:@"old"] intValue], 0);
            }

            if([[change valueForKey:@"new"] intValue] > 0 && [[change valueForKey:@"new"] intValue] <= 511){
                dmxPro->sendLevel([[change valueForKey:@"new"] intValue], PropI(([NSString stringWithFormat:@"channel%02i", i+1])));
            }
        }
        
        NSString * prop = [NSString stringWithFormat:@"channel%02i", i+1];
        if(object == Prop(prop)){
            ofxOscMessage msg;
            msg.setAddress("/channel/set");
            msg.addIntArg(i+1);
            msg.addIntArg(PropI(prop));
            
            ofxOscBundle bundle;
            bundle.addMessage(msg);
            oscSender->sendBundle(bundle);
            
            int ch = PropI(([NSString stringWithFormat:@"channel%02ipatch", i+1]));
            
            if(ch > 0 && ch <= 511){
                dmxPro->sendLevel(ch, [object intValue]);
            }

            
        }

    }
}
@end
