//
//  Box2dScene.m
//  Box2DCocos2DExamples
//
//  Created by Yannick LORIOT on 12/06/11.
//  Copyright 2011 Yannick Loriot. All rights reserved.
//  http://yannickloriot.com
//

#import "Box2dScene.h"
#import <mach/mach_time.h>

#import "CCTouchJoint.h"
#import "Box2DExamples.h"
#import "Box2DSceneManager.h"

#define RANDOM_SEED() srandom((unsigned)(mach_absolute_time() & 0xFFFFFFFF))

@interface Box2dScene ()
@property (nonatomic, retain) NSMutableArray *touchJointList;

/** Update methods to refresh the box2d world. */
- (void)update:(ccTime)dt;
/** Init the box2d world. */
- (void)initWorld;

// Menu Callbacks
- (void)previousCallback:(id)sender;
- (void)restartCallback:(id)sender;
- (void)nextCallback:(id)sender;

@end

@implementation Box2dScene
@synthesize touchJointList;
@synthesize sceneTitleLabel, world, m_debugDraw;

- (void) dealloc
{
	// Delete the world
	delete world;
	world = NULL;
	
	delete m_debugDraw;
    
    // Delete the touch joint list
    [touchJointList release];
    
    [sceneTitleLabel release], sceneTitleLabel = nil;
    
	[super dealloc];
}

- (id)init
{
	if ((self = [super init]))
    {
        // Init the seed
        RANDOM_SEED();
        
        // Get the sceensize
        CGSize screensize = [[CCDirector sharedDirector] winSize];
        
        // Init the touch joint list
        touchJointList = [[NSMutableArray alloc] init];
        
        // Init the box2d world
		[self initWorld];
        
        // Enable accelerometer
		self.isAccelerometerEnabled = YES;
        
		// Enable touches
		self.isTouchEnabled = YES;

        // Add the title
        self.sceneTitleLabel = [CCLabelTTF labelWithString:@"Title" fontName:@"Arial" fontSize:12];
        [sceneTitleLabel setPosition:ccp (screensize.width / 2, screensize.height - sceneTitleLabel.contentSize.height / 2)];
        [self addChild:sceneTitleLabel z:1];
        
        // Add the menu
		CCMenuItemImage *item1 = 
        [CCMenuItemImage itemFromNormalImage:@"b1.png" selectedImage:@"b2.png" target:self selector:@selector(previousCallback:)];
		CCMenuItemImage *item2 =
        [CCMenuItemImage itemFromNormalImage:@"r1.png" selectedImage:@"r2.png" target:self selector:@selector(restartCallback:)];
		CCMenuItemImage *item3 =
        [CCMenuItemImage itemFromNormalImage:@"f1.png" selectedImage:@"f2.png" target:self selector:@selector(nextCallback:)];
        
		CCMenu *menu = [CCMenu menuWithItems:item1, item2, item3, nil];
        [menu setPosition:CGPointZero];
		[item1 setPosition:ccp(screensize.width / 2 - 100, 30)];
		[item2 setPosition:ccp(screensize.width / 2, 30)];
		[item3 setPosition:ccp(screensize.width / 2 + 100, 30)];
        
		[self addChild: menu z:1];
        
        [self schedule:@selector(update:)];
    }
    return self;
}

+ (CCScene *)sceneWithTitle:(NSString *)title
{
	// 'scene' is an autorelease object
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object
	Box2dScene *layer = [self node];
	[layer.sceneTitleLabel setString:title];
    
	// Add layer as a child to scene
	[scene addChild: layer];
	
	// Return the scene
	return scene;
}

- (void)draw
{
	// Default GL states: GL_TEXTURE_2D, GL_VERTEX_ARRAY, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
	// Needed states:  GL_VERTEX_ARRAY, 
	// Unneeded states: GL_TEXTURE_2D, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
	glDisable(GL_TEXTURE_2D);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	
	glPushMatrix();
	glScalef( CC_CONTENT_SCALE_FACTOR(), CC_CONTENT_SCALE_FACTOR(), 1.0f);
    
	world->DrawDebugData();
    
	glPopMatrix();
	
	// restore default GL states
	glEnable(GL_TEXTURE_2D);
	glEnableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
}

- (void)accelerometer:(UIAccelerometer *)_accelerometer didAccelerate:(UIAcceleration *)_acceleration
{	
    b2Vec2 gravity(_acceleration.y * -WORLDGRAVITY, _acceleration.x * WORLDGRAVITY);
    world->SetGravity(gravity);
}

#pragma mark -
#pragma mark Box2dScene Public Methods

#pragma mark Box2dScene Private Methods

- (void)update:(ccTime)dt
{    
	// It is recommended that a fixed time step is used with Box2D for stability
	// of the simulation, however, we are using a variable time step here.
	// You need to make an informed choice, the following URL is useful
	// http://gafferongames.com/game-physics/fix-your-timestep/
	
	int32 velocityIterations = 6;
	int32 positionIterations = 2;
	
	// Instruct the world to perform a single step of simulation. It is
	// generally best to keep the time step and iterations fixed
	world->Step(dt, velocityIterations, positionIterations);
    world->ClearForces();
}

- (void)initWorld
{
    // Get the screen size
    CGSize screenSize = [CCDirector sharedDirector].winSize;
    
    // Define the gravity vector
    b2Vec2 gravity = b2Vec2(0.0f, -10.0f);
    
    // Do we want to let bodies sleep?
    // This will speed up the physics simulation
    bool doSleep = false;
    
    // Construct a world object, which will hold and simulate the rigid bodies
    world = new b2World(gravity, doSleep);
    world->SetContinuousPhysics(true);
    
    // Debug Draw functions
    m_debugDraw = new GLESDebugDraw(PTM_RATIO);
    
    uint32 flags = 0;
    flags += b2Draw::e_shapeBit;
    flags += b2Draw::e_jointBit;
    //flags += b2DebugDraw::e_aabbBit;
    //flags += b2DebugDraw::e_pairBit;
    flags += b2Draw::e_centerOfMassBit;
    flags += b2Draw::e_controllerBit;
    
    m_debugDraw->SetFlags(flags);
    
    world->SetDebugDraw(m_debugDraw);
    
    // Define the ground body
    b2BodyDef groundBodyDef;
    groundBodyDef.position.Set(0, 0); // bottom-left corner
    
    // Call the body factory which allocates memory for the ground body
    // from a pool and creates the ground box shape (also from a pool).
    // The body is also added to the world
    b2Body* groundBody = world->CreateBody(&groundBodyDef);
    holdJoint = groundBody;
    
    // Define the ground box shape.
    b2PolygonShape groundBox;		
    
    // Bottom    
    groundBox.SetAsBox(ptm(screenSize.width / 2), ptm(1.0f), b2Vec2(ptm(screenSize.width / 2), 0.0f), 0.0f);
    groundBody->CreateFixture(&groundBox, 0);
    
    // Top
    groundBox.SetAsBox(ptm(screenSize.width / 2), ptm(1.0f), b2Vec2(ptm(screenSize.width / 2), ptm(screenSize.height)), 0.0f);
    groundBody->CreateFixture(&groundBox, 0);
    
    // Left
    groundBox.SetAsBox(ptm(1.0f), ptm(screenSize.height / 2), b2Vec2(0, ptm(screenSize.height / 2)), 0.0f);
    groundBody->CreateFixture(&groundBox, 0);
    
    // Right
    groundBox.SetAsBox(ptm(1.0f), ptm(screenSize.height / 2), b2Vec2(ptm(screenSize.width), ptm(screenSize.height / 2)), 0.0f);
    groundBody->CreateFixture(&groundBox, 0);
}

#pragma mark Menu Callbacks Methods

- (void)previousCallback:(id)sender
{
    [[CCDirector sharedDirector] replaceScene:[[Box2DSceneManager sharedBox2DSceneManager] previousBox2DScene]];
}

- (void)restartCallback:(id)sender
{
	[[CCDirector sharedDirector] replaceScene:[[Box2DSceneManager sharedBox2DSceneManager] currentBox2DScene]];
}

- (void)nextCallback:(id)sender
{
    [[CCDirector sharedDirector] replaceScene:[[Box2DSceneManager sharedBox2DSceneManager] nextBox2DScene]];
}

#pragma mark -
#pragma mark CCTargetedTouch Delegate Methods

- (void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSSet *allTouches = [event allTouches];
    
	for(UITouch *touch in allTouches)
    {
		CGPoint location = [touch locationInView:touch.view];

		location = [[CCDirector sharedDirector] convertToGL:location];
		b2Vec2 worldLoc = b2Vec2(ptm(location.x), ptm(location.y));
        
		for (b2Body *b = world->GetBodyList(); b; b = b->GetNext())
        {
			if (b->GetType() == b2_dynamicBody)
            {
				for (b2Fixture *f = b->GetFixtureList(); f; f = f->GetNext())
                {
                    // Hit!
					if (f->TestPoint(worldLoc))
                    {
						// Create touch Joint only if the phase is began !
						if ([touch phase] == UITouchPhaseBegan)
                        {
                            /// Mouse joint definition
                            b2MouseJointDef md;
                            md.bodyA = holdJoint;
                            md.bodyB = b;
                            md.target = worldLoc;
                            md.maxForce = 16000.0f * b->GetMass();
                            
                            // Joint of bodys
                            b2MouseJoint *m_touchJoint;
                            m_touchJoint = (b2MouseJoint *)world->CreateJoint(&md);
                            
							CCTouchJoint *tj = [CCTouchJoint touch:touch withMouseJoint:m_touchJoint];
							[touchJointList addObject:tj];
							b->SetAwake(true);
                            
							break;
						}
					}
				}
			}
		}
	}
}

- (void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (CCTouchJoint *tj in touchJointList)
    {
        if([tj.touch phase] == UITouchPhaseMoved)
        {
			// Update if it is moved
			CGPoint location = [tj.touch locationInView:tj.touch.view];
			location = [[CCDirector sharedDirector] convertToGL:location];
            
			b2Vec2 worldLocation = b2Vec2(ptm(location.x), ptm(location.y));
			tj.mouseJoint->SetTarget(worldLocation);
		}
	}
}

- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSSet *allTouches = [event allTouches];
    
    NSMutableArray *discardedItems = [NSMutableArray array];
    
	for(UITouch *touch in allTouches)
    {
        for (CCTouchJoint *tj in touchJointList)
        {
            if (tj.touch == touch)
            {
                // Defensive programming - assertion
                NSAssert([tj isKindOfClass:[CCTouchJoint class]], @"node is not a touchJoint!");
                
                // If safe - loop through
                if ([tj.touch phase] == UITouchPhaseEnded)
                {
                    [discardedItems addObject:tj];
                    
                    [tj destroyTouchJoint];
                    [tj release];
                }
            }
        }
	}
    
    [touchJointList removeObjectsInArray:discardedItems];
}

- (void)ccTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [touchJointList removeAllObjects];
}

@end
