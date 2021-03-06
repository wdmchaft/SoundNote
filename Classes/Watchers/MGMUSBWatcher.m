//
//  MGMUSBWatcher.m
//  SoundNote
//
//  Created by Mr. Gecko on 2/15/11.
//  Copyright (c) 2011 Mr. Gecko's Media (James Coleman). http://mrgeckosmedia.com/
//
//  Permission to use, copy, modify, and/or distribute this software for any purpose
//  with or without fee is hereby granted, provided that the above copyright notice
//  and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
//  REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT,
//  OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
//  DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
//  ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

#import "MGMUSBWatcher.h"
#import "MGMController.h"
#import <IOKit/IOKitLib.h>

char * const IOUSBDevice = "IOUSBDevice";

static void usbConnected(void *refCon, io_iterator_t iterator) {
	io_object_t	object;
	while ((object = IOIteratorNext(iterator))) {
		[(MGMUSBWatcher *)refCon usbDeviceConnected:object];
		IOObjectRelease(object);
	}
}
static void usbDisconnected(void *refCon, io_iterator_t iterator) {
	io_object_t	object;
	while ((object = IOIteratorNext(iterator))) {
		[(MGMUSBWatcher *)refCon usbDeviceDisconnected:object];
		IOObjectRelease(object);
	}
}

static NSString *nameForIOUSB(io_object_t object) {
	io_name_t ioDeviceName;
	NSString *deviceName = nil;
	kern_return_t result = IORegistryEntryGetName(object, ioDeviceName);
	if (result==noErr)
		deviceName = [(NSString *)CFStringCreateWithCString(kCFAllocatorDefault, ioDeviceName, kCFStringEncodingUTF8) autorelease];
	if (deviceName!=nil)
		return deviceName;
	
	return @"Unnamed Device";
}

@implementation MGMUSBWatcher
- (id)init {
	if ((self = [super init])) {
		notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
		runLoop = IONotificationPortGetRunLoopSource(notificationPort);
		CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopDefaultMode);
		
		USBDevices = [NSMutableArray new];
		
		CFDictionaryRef servicesMatch = IOServiceMatching(IOUSBDevice);
		io_iterator_t found;
		kern_return_t result = IOServiceAddMatchingNotification(notificationPort, kIOPublishNotification, servicesMatch, usbConnected, self, &found);
		if (result!=kIOReturnSuccess)
			NSLog(@"Unable to register for usb add %d", result);
		io_object_t	object;
		while ((object = IOIteratorNext(found))) {
			NSString *deviceName = nameForIOUSB(object);
			if (![USBDevices containsObject:deviceName])
				[USBDevices addObject:deviceName];
			IOObjectRelease(object);
		}
		
		servicesMatch = IOServiceMatching(IOUSBDevice);
		result = IOServiceAddMatchingNotification(notificationPort, kIOTerminatedNotification, servicesMatch, usbDisconnected, self, &found);
		if (result!=kIOReturnSuccess)
			NSLog(@"Unable to register for usb remove %d", result);
		else {
			while ((object = IOIteratorNext(found))) {
				NSString *deviceName = nameForIOUSB(object);
				if ([USBDevices containsObject:deviceName])
					[USBDevices removeObject:deviceName];
				IOObjectRelease(object);
			}
		}
	}
	return self;
}
- (void)dealloc {
	if (notificationPort) {
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopDefaultMode);
		IONotificationPortDestroy(notificationPort);
	}
	[USBDevices release];
	[super dealloc];
}

- (void)usbDeviceConnected:(io_object_t)theDevice {
	NSString *deviceName = nameForIOUSB(theDevice);
	if (![USBDevices containsObject:deviceName]) {
		[USBDevices addObject:deviceName];
		[[MGMController sharedController] startNotificationWithInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"usbconnected", MGMNName, @"USB Connected", MGMNTitle, deviceName, MGMNDescription, [NSImage imageNamed:@"USB"], MGMNIcon, nil]];
	}
}
- (void)usbDeviceDisconnected:(io_object_t)theDevice {
	NSString *deviceName = nameForIOUSB(theDevice);
	if ([USBDevices containsObject:deviceName]) {
		[USBDevices removeObject:deviceName];
		[[MGMController sharedController] startNotificationWithInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"usbdisconnected", MGMNName, @"USB Disconnected", MGMNTitle, deviceName, MGMNDescription, [NSImage imageNamed:@"USB"], MGMNIcon, nil]];
	}
}
@end