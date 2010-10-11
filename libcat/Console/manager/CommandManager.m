//
//  CommandManager.m
//  TestApp
//
//  Created by b b on 07/10/10.
//  Copyright 2010 factorcat. All rights reserved.
//

#import "CommandManager.h"
#import "NSMutableDictionaryExt.h"
#import "NSDictionaryExt.h"
#import "NSDictionaryBlock.h"
#import "NSStringExt.h"
#import "NSIndexPathExt.h"
#import "Logger.h"
#import "ConsoleManager.h"
#import "NSArrayExt.h"
#import "NSArrayBlock.h"
#import "Async.h"
#import "NSNumberExt.h"
#import "NSObjectExt.h"
#import "Inspect.h"
#import "UnitTest.h"


#define TOOLBAR_ITEMS_SECTION_INDEX -1


NSArray* array_prefix_index(NSArray* array) {
	return [array map_with_index:^id(id obj, int idx) { 
		return SWF(@"[%d] %@", idx, [obj inspect]); 
	}];
}


@implementation CommandManager
@synthesize commandsMap;

-(id) commandNotFound {
	return NSLocalizedString(@"Command Not Found", nil);
}

-(NSDictionary*) load_system_commands {
	return [NSDictionary dictionaryWithKeysAndObjects:
			@"echo", @"command_echo:arg:",
			@"pwd", @"command_pwd:arg:",
			@"cd", @"command_cd:arg:",
			@"ls", @"command_ls:arg:",
			@"touch", @"command_touch:arg:",
			@"back", @"command_back:arg:",
			@"rm", @"command_rm:arg:",
			@"completion", @"command_completion:arg:",
			nil];
}

-(id) command_echo:(id)currentObject arg:(id)arg {
	return arg;
}

-(id) command_pwd:(id)currentObject arg:(id)arg {
	CONSOLEMAN.currentTargetObject = [CONSOLEMAN get_topViewController];	
	return SWF(@"%@", [CONSOLEMAN.currentTargetObject class]);
}

-(NSString*) command_cd:(id)currentObject arg:(id)arg {
	NSArray* pair = [self findTargetObject:currentObject arg:arg];
	id response = [pair objectAtFirst];
	id changeObject = [pair objectAtSecond];
	if ([changeObject isNotNull]) {
		CONSOLEMAN.currentTargetObject = changeObject;
	} else {
		if ([arg isEmpty]) {
			changeObject = [CONSOLEMAN get_topViewController];
			CONSOLEMAN.currentTargetObject = changeObject;
			response = SWF(@"cd %@", [changeObject class]);
		}
	}
	return response;
}


-(NSString*) command_touch:(id)currentObject arg:(id)arg {
	NSArray* trio = [self findTargetObject:currentObject arg:arg];
	id actionBlockObj = [trio objectAtThird];
	if ([actionBlockObj isNotNull]) {
		ActionBlock actionBlock = (ActionBlock)actionBlockObj;
		NSString* methodStr = actionBlock();
		CONSOLEMAN.currentTargetObject = nil;
		return SWF(@"touch %@", methodStr);
	}
	return NSLocalizedString(@"Not Found", nil);
}


-(NSString*) command_rm:(id)currentObject arg:(id)arg {
	NSArray* pair = [self findTargetObject:currentObject arg:arg];
	id changeObject = [pair objectAtSecond];
	if ([changeObject isKindOfClass:[UIView class]]) {
		UIView* view = (UIView*)changeObject;
		CONSOLEMAN.currentTargetObject = view.superview;
		[view removeFromSuperview];
		return SWF(@"cd %@", [CONSOLEMAN.currentTargetObject class]);
	}
	return NSLocalizedString(@"Not Found", nil);
}

-(NSString*) command_back:(id)currentObject arg:(id)arg {
	if ([currentObject isKindOfClass:[UIViewController class]]) {
		UIViewController* controller = currentObject;
		if ([controller.parentViewController isKindOfClass:[UINavigationController class]]) {
			if (controller.navigationController.viewControllers.count > 1) {
				[controller.navigationController popViewControllerAnimated:true];
				return NSLocalizedString(@"back popViewControllerAnimated:", nil);
			}
		}
	}
	return NSLocalizedString(@"Not Found", nil);
}


-(NSString*) command_completion:(id)currentObject arg:(id)arg {
	NSArray* pair = [self get_targetStringAndBlocks:currentObject];
	NSDictionary* targetStrings = [pair objectAtFirst];
	NSMutableArray* ary = [NSMutableArray arrayWithArray:[currentObject methods]];
	[ary addObjectsFromArray:[targetStrings allKeys]];
	return [ary join:LF];
}


-(NSString*) command_ls:(id)currentObject arg:(id)arg {
	NSMutableArray* ary = [NSMutableArray array];
	NSArray* arrayLS = [self array_ls:currentObject arg:arg];
	for (NSArray* pair in arrayLS) {
		int lsType = [[pair objectAtFirst] intValue];
		id obj = [pair objectAtSecond];
		switch (lsType) {
			case LS_OBJECT: {
					if (nil == obj) {
					} else {
						NSString* classNameUpper = [SWF(@"%@", [obj class]) uppercaseString];
						[ary addObject:SWF(@"[%@]: %@", classNameUpper, [obj inspect])];
					}
				}
				break;
			case LS_VIEWCONTROLLERS:
				[ary addObject:SWF(@"VIEWCONTROLLERS: %@", [array_prefix_index(obj) inspect])];
				break;
			case LS_TABLEVIEW:
				[ary addObject:SWF(@"TABLEVIEW: %@", [obj inspect])];
				break;
			case LS_SECTIONS: {
					[ary addObject:@"SECTIONS: "];
					[(NSArray*)obj each_with_index:^(id sectionAry, int idx) {
						[ary addObject:SWF(@"\t%d %@", idx, [array_prefix_index(sectionAry) inspect])];
					}];
				}
				break;
			case LS_VIEW:
				[ary addObject:SWF(@"VIEW: %@", [obj inspect])];
				break;
			case LS_VIEW_SUBVIEWS:
				[ary addObject:SWF(@"VIEW.SUBVIEWS: %@", [array_prefix_index(obj) inspect])];
				break;
			case LS_TABBAR:
				[ary addObject:SWF(@"TABBAR: %@", [obj inspect])];				
				break;
			case LS_NAVIGATIONITEM:
				[ary addObject:SWF(@"NAVIGATIONITEM: %@", [obj inspect])];				
				break;				
			case LS_NAVIGATIONCONTROLLER_TOOLBAR:
				[ary addObject:SWF(@"NAVIGATIONCONTROLLER_TOOLBAR: %@", [obj inspect])];				
				break;								
			case LS_NAVIGATIONCONTROLLER_TOOLBAR_ITEMS:
				[ary addObject:SWF(@"NAVIGATIONCONTROLLER_TOOLBAR_ITEMS: %d %@", TOOLBAR_ITEMS_SECTION_INDEX, [array_prefix_index(obj) inspect])];				
				break;												
			case LS_TOOLBAR:
				[ary addObject:SWF(@"TOOLBAR: %@", [obj inspect])];				
				break;								
			case LS_TOOLBAR_ITEMS:
				[ary addObject:SWF(@"TOOLBAR_ITEMS: %d %@", TOOLBAR_ITEMS_SECTION_INDEX, [array_prefix_index(obj) inspect])];				
				break;																
			default:
				break;
		}
	}
	return [ary join:LF];
}


-(NSArray*) array_ls:(id)currentObject arg:(id)arg {
	if ([currentObject isKindOfClass:[UITabBarController class]]) {
		UITabBarController* tabBarController = currentObject;
		return [NSArray arrayWithObjects:
				PAIR(Enum(LS_OBJECT), currentObject),
				PAIR(Enum(LS_TABBAR), tabBarController.tabBar),
				PAIR(Enum(LS_VIEWCONTROLLERS), tabBarController.viewControllers),
				nil];
	} else if ([currentObject isKindOfClass:[UINavigationController class]]) {
		UINavigationController* navigationController = currentObject;
		NSMutableArray* ret = [NSMutableArray array];
		[ret addObject:PAIR(Enum(LS_OBJECT), currentObject)];
		[ret addObject:PAIR(Enum(LS_VIEWCONTROLLERS), navigationController.viewControllers)];
		if (! navigationController.toolbarHidden) {
			[ret addObject:PAIR(Enum(LS_TOOLBAR), navigationController.toolbar)];
			[ret addObject:PAIR(Enum(LS_TOOLBAR_ITEMS), navigationController.toolbar.items)];
		}
		return ret;
	} else if ([currentObject isKindOfClass:[UIViewController class]]) {
		NSMutableArray* ret = [NSMutableArray array];
		[ret addObject: PAIR(Enum(LS_OBJECT), currentObject) ];
		UIViewController* controller = currentObject;
		if (nil != controller.navigationItem) {
			[ret addObject: PAIR(Enum(LS_NAVIGATIONITEM), controller.navigationItem) ];
		}
		if ([controller.view isKindOfClass:[UITableView class]]) {
			UITableView* tableView = (UITableView*)controller.view;
			NSMutableArray* sections = [NSMutableArray array];
			for (int section = 0; section < [tableView numberOfSections]; section++) {
				NSMutableArray* ary = [NSMutableArray array];
				for (int row = 0; row < [tableView numberOfRowsInSection:section]; row++) {
					NSIndexPath* indexPath = [NSIndexPath indexPathWithSection:section Row:row];
					UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
					[ary addObject:cell];
				}
				[sections addObject:ary];
			}
			[ret addObjectsFromArray: [NSArray arrayWithObjects:
					PAIR(Enum(LS_TABLEVIEW), tableView),
					PAIR(Enum(LS_SECTIONS), sections),
									   nil]];
		} else {
			[ret addObjectsFromArray: [NSArray arrayWithObjects:
					PAIR(Enum(LS_VIEW), controller.view),
					PAIR(Enum(LS_VIEW_SUBVIEWS), [controller.view.subviews reverse]),
									   nil]];
		}
		if (! controller.navigationController.toolbarHidden &&  nil != controller.navigationController.toolbar) {
			[ret addObject: PAIR(Enum(LS_NAVIGATIONCONTROLLER_TOOLBAR), controller.navigationController.toolbar) ];
			[ret addObject: PAIR(Enum(LS_NAVIGATIONCONTROLLER_TOOLBAR_ITEMS), controller.navigationController.toolbar.items) ];
		}
		return ret;
	} else if ([currentObject isKindOfClass:[UITableView class]]) {
		UITableView* tableView = currentObject;
		NSMutableArray* sections = [NSMutableArray array];
		for (int section = 0; section < [tableView numberOfSections]; section++) {
			NSMutableArray* ary = [NSMutableArray array];
			for (int row = 0; row < [tableView numberOfRowsInSection:section]; row++) {
				NSIndexPath* indexPath = [NSIndexPath indexPathWithSection:section Row:row];
				UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
				[ary addObject:cell];
			}
			[sections addObject:ary];
		}
		return [NSArray arrayWithObjects:
				PAIR(Enum(LS_OBJECT), currentObject),
				PAIR(Enum(LS_SECTIONS), sections),
				nil];	
	} else if ([currentObject isKindOfClass:[UIView class]]) {
		UIView* view = currentObject;
		return [NSArray arrayWithObjects:
				PAIR(Enum(LS_OBJECT), currentObject),
				PAIR(Enum(LS_VIEW_SUBVIEWS), [view.subviews reverse]),
				nil];
	} else {
		return [NSArray arrayWithObjects:
				PAIR(Enum(LS_OBJECT), currentObject),
				nil];		
	}
}

-(NSArray*) findTargetObject:(id)currentObject arg:(id)arg {
	id changeObject = nil;
	id actionBlock = [NSNull null];
	if ([SLASH isEqualToString:arg]) {
		changeObject = [CONSOLEMAN get_rootViewController];
	} else if ([DOT isEqualToString:arg]) {
		changeObject = currentObject;
		actionBlock = [self get_targetObjectActionBlock:currentObject];		
	} else if ([DOT_DOT isEqualToString:arg]) {
		if (nil == currentObject) {
			return PAIR(EMPTY_STRING, nil);
		} else {
			if ([currentObject isKindOfClass:[UIViewController class]]) {
				UIViewController* controller = currentObject;
				changeObject = controller.parentViewController;
			} else if ([currentObject isKindOfClass:[UIView class]]) {
				UIView* view = currentObject;
				Class klass_UIViewControllerWrapperView = NSClassFromString(@"UIViewControllerWrapperView");
				if ([view.superview isKindOfClass:klass_UIViewControllerWrapperView]) {
					if ([CONSOLEMAN get_topViewController].view == view) {
						changeObject = [CONSOLEMAN get_topViewController];
					} else {
						changeObject = view.superview;							
					}
				} else {
					changeObject = view.superview;
				}
			}
		}
	} else if ([arg hasPrefix:@"0x"]) {
		size_t address = [arg to_size_t];
		id obj = (id)address;
		changeObject = obj;
		actionBlock = [self get_targetObjectActionBlock:obj];
	} else if ([arg isNumberHasSpace]) {
		BOOL found = false;
		int section = 0;
		int row = 0;
		if ([arg hasText:SPACE]) {
			NSArray* pair = [arg split:SPACE];
			section = [[pair objectAtFirst] to_int];
			row = [[pair objectAtSecond] to_int];
		} else {
			row = [arg to_int];
		}
		if (TOOLBAR_ITEMS_SECTION_INDEX == section) {
			if ([currentObject isKindOfClass:[UIViewController class]]) {
				UIViewController* controller = currentObject;
				if (! controller.navigationController.toolbarHidden &&  nil != controller.navigationController.toolbar) {
					NSArray* items = controller.navigationController.toolbar.items;
					if (items.count > row) {
						UIBarButtonItem* barButtonItem = [items objectAtIndex:row];
						changeObject = barButtonItem;
						found = true;
						ActionBlock block = ^id {
							[barButtonItem.target performSelector:barButtonItem.action];
							return NSStringFromSelector(barButtonItem.action);
						};
						actionBlock = Block_copy(block);
					}
				}
			}
		} else { // TOOLBAR_ITEMS_SECTION_INDEX != section
			if ([currentObject isKindOfClass:[UITabBarController class]]) {
				UITabBarController* tabBarController = currentObject;
				if (row < tabBarController.viewControllers.count) {
					UIViewController* controller = [tabBarController.viewControllers objectAtIndex:row];
					changeObject = controller;
					found = true;
					ActionBlock block = ^id {
						tabBarController.selectedIndex = row;
						return @"selectedIndex";
					};
					actionBlock = Block_copy(block);
				}			
			} else if ([currentObject isKindOfClass:[UINavigationController class]]) {
				UINavigationController* navigationController = currentObject;
				if (row < navigationController.viewControllers.count) {
					UIViewController* controller = [navigationController.viewControllers objectAtIndex:row];
					changeObject = controller;
					found = true;
				}
			} else if ([currentObject isKindOfClass:[UIViewController class]]) {
				UIViewController* controller = currentObject;
				if ([controller.view isKindOfClass:[UITableView class]]) {
					UITableView* tableView = (UITableView*)controller.view;
					if (section < [tableView numberOfSections] && row < [tableView numberOfRowsInSection:section]) {
						NSIndexPath* indexPath = [NSIndexPath indexPathWithSection:section Row:row];
						UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
						changeObject = cell;
						found = true;
						ActionBlock block = ^id {
							[tableView.delegate tableView:tableView didSelectRowAtIndexPath:indexPath];
							return @"tableView:didSelectRowAtIndexPath:";
						};
						actionBlock = Block_copy(block);
					}				
				} else {
					if (row < controller.view.subviews.count) {
						UIView* subview = [[controller.view.subviews reverse] objectAtIndex:row];
						changeObject = subview;
						found = true;
						
						if ([subview isKindOfClass:[UIControl class]]) {
							ActionBlock block = ^id {				
								[(UIControl*)subview sendActionsForControlEvents:UIControlEventTouchUpInside];
								return @"sendActionsForControlEvents:";
							};
							actionBlock = Block_copy(block);
						}					
					}
				}
			} else if ([currentObject isKindOfClass:[UITableView class]]) {
				UITableView* tableView = currentObject;
				if (section < [tableView numberOfSections] && row < [tableView numberOfRowsInSection:section]) {
					NSIndexPath* indexPath = [NSIndexPath indexPathWithSection:section Row:row];
					UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
					changeObject = cell;
					found = true;
					ActionBlock block = ^id {
						[tableView.delegate tableView:tableView didSelectRowAtIndexPath:indexPath];
						return @"tableView:didSelectRowAtIndexPath:";
					};
					actionBlock = Block_copy(block);				
				}
			} else if ([currentObject isKindOfClass:[UIView class]]) {
				UIView* view = currentObject;
				if (row < view.subviews.count) {
					UIView* subview = [[view.subviews reverse] objectAtIndex:row];				
					changeObject = subview;
					found = true;
					
					if ([subview isKindOfClass:[UIControl class]]) {
						ActionBlock block = ^id {				
							[(UIControl*)subview sendActionsForControlEvents:UIControlEventTouchUpInside];
							return @"sendActionsForControlEvents:";
						};
						actionBlock = Block_copy(block);
					}
				}
			}
		} // TOOLBAR_ITEMS_SECTION_INDEX != section
		if (! found) {
			return PAIR(NSLocalizedString(@"Not Found", nil), nil); 
		}
	} else if ([arg isNotEmpty]) {
		SEL selector = NSSelectorFromString(arg);
		if ([currentObject respondsToSelector:selector]) {
			id obj = [currentObject performSelector:selector];			
			if (nil != obj) {
				changeObject = obj;
			}
		} else { // search by title
			NSArray* pair = [self get_targetStringAndBlocks:currentObject];
			NSDictionary* targetStrings = [pair objectAtFirst];
			NSDictionary* targetBlocks = [pair objectAtSecond];
			id obj = [targetStrings	objectForKey:arg];
			if (nil != obj) {
				changeObject = obj;
				actionBlock = [targetBlocks objectForKey:arg];
			}
		}
	}
	if (nil == changeObject) {
		return TRIO(NSLocalizedString(@"Not Found", nil), [NSNull null], [NSNull null]); 
	} else {
		return TRIO(SWF(@"cd %@", [changeObject class]), changeObject, actionBlock);
	}	
}

-(id) get_targetObjectActionBlock:(id)targetObject {
	id actionBlock = nil;
	if ([targetObject isKindOfClass:[UITableViewCell class]]) {
		UITableViewCell* cell = targetObject;
		UITableView* tableView = (UITableView*)cell.superview;
		for (NSIndexPath* indexPath in [tableView indexPathsForVisibleRows]) {
			UITableViewCell* cellObj = [tableView cellForRowAtIndexPath:indexPath];
			if (cell == cellObj) {
				ActionBlock block = ^id {
					[tableView.delegate tableView:tableView didSelectRowAtIndexPath:indexPath];
					return @"tableView:didSelectRowAtIndexPath:";
				};
				actionBlock = Block_copy(block);
				break;
			}
		}
	} else if ([targetObject isKindOfClass:[UIControl class]]) {
		ActionBlock block = ^id {				
			[targetObject sendActionsForControlEvents:UIControlEventTouchUpInside];
			return @"sendActionsForControlEvents:";
		};
		actionBlock = Block_copy(block);
	} else if ([targetObject isKindOfClass:[UIBarButtonItem class]]) {
		UIBarButtonItem* barButtonItem = targetObject;
		ActionBlock block = ^id {				
			[barButtonItem.target performSelector:barButtonItem.action];
			return NSStringFromSelector(barButtonItem.action);
		};
		actionBlock = Block_copy(block);			
	}
	return actionBlock;
}

-(NSArray*) get_targetStringAndBlocks:(id)currentObject {
	NSMutableDictionary* targetStrings = [NSMutableDictionary dictionary];
	NSMutableDictionary* targetBlocks = [NSMutableDictionary dictionary];
	if ([currentObject isKindOfClass:[UIViewController class]]) {
		UIViewController* controller = currentObject;
		if ([controller.view isKindOfClass:[UITableView class]]) {
			UITableView* tableView = (UITableView*)controller.view;
			for (int section = 0; section < [tableView numberOfSections]; section++) {
				for (int row = 0; row < [tableView numberOfRowsInSection:section]; row++) {
					NSIndexPath* indexPath = [NSIndexPath indexPathWithSection:section Row:row];
					UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
					NSString* textLabelText = cell.textLabel.text;
					if (nil != textLabelText) {
						[targetStrings setObject:cell forKey:textLabelText];
						ActionBlock block = ^id {
							[tableView.delegate tableView:tableView didSelectRowAtIndexPath:indexPath];
							return @"tableView:didSelectRowAtIndexPath:";
						};
						[targetBlocks setObject:Block_copy(block) forKey:textLabelText];
					}
				}
			}
		} else {
			for (UIView* subview in controller.view.subviews) {
				if ([subview isKindOfClass:[UIControl class]] && [subview respondsToSelector:@selector(titleLabel)]) {
					NSString* titleLabelText = [[subview performSelector:@selector(titleLabel)] text];
					if (nil != titleLabelText) {
						[targetStrings setObject:subview forKey:titleLabelText];
					}
					ActionBlock block = ^id {
						[(UIControl*)subview sendActionsForControlEvents:UIControlEventTouchUpInside];
						return @"sendActionsForControlEvents:";
					};
					[targetBlocks setObject:Block_copy(block) forKey:titleLabelText];
				}
			}
		}
	}
	return PAIR(targetStrings, targetBlocks);
}

//-(NSString*) command_touch:(id)currentObject arg:(id)arg {
//	id changeObject = nil;
//	if ([arg isEmpty]) {
//		changeObject = currentObject;
//	} else {
//		NSArray* pair = [self changeCurrentObject:currentObject arg:arg];
//		changeObject = [pair objectAtSecond];
//	}	
//	
//	if ((nil != changeObject) && [changeObject respondsToSelector:@selector(touchUpInside)]) {
//		CONSOLEMAN.currentObject = changeObject;
//		[CONSOLEMAN.currentObject performSelectorOnMainThread:@selector(touchUpInside) withObject:nil waitUntilDone:NO];
//		CONSOLEMAN.currentObject = nil;
//		return NSLocalizedString(@"touchUpInside", nil);
//	} else {
//		return NSLocalizedString(@"Not Found", nil);
//	}
//}

+ (CommandManager*) sharedManager {
	static CommandManager*	manager = nil;
	if (!manager) {
		manager = [CommandManager new];
	}
	return manager;
}

- (id) init {
	self = [super init];
	if (self) {
		self.commandsMap = [NSMutableDictionary dictionaryWithDictionary:[self load_system_commands]];
	}
	return self;
}

- (void)dealloc {
	[commandsMap release];
	[super dealloc];
}

@end