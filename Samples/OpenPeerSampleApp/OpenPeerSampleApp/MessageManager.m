/*
 
 Copyright (c) 2012, SMB Phone Inc.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 The views and conclusions contained in the software and documentation are those
 of the authors and should not be interpreted as representing official policies,
 either expressed or implied, of the FreeBSD Project.
 
 */

#import "MessageManager.h"
#import "SessionManager.h"
#import "ContactsManager.h"

#import "Constants.h"
#import "Session.h"
#import "Contact.h"
#import "Utility.h"

#import "XMLWriter.h"
#import "RXMLElement.h"

#import <OpenpeerSDK/HOPContact.h>
#import <OpenpeerSDK/HOPMessage.h>
#import <OpenpeerSDK/HOPConversationThread.h>

@implementation MessageManager

/**
 Retrieves singleton object of the Login Manager.
 @return Singleton object of the Login Manager.
 */
+ (id) sharedMessageManager
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (HOPMessage*) createSystemMessageWithType:(SystemMessageTypes) type andText:(NSString*) text andRecipient:(HOPContact*) contact
{
    HOPMessage* hopMessage = nil;
    XMLWriter *xmlWriter = [[XMLWriter alloc] init];
    
    //<Event>
    [xmlWriter writeStartElement:TagEvent];
    
    //<id>
    [xmlWriter writeStartElement:TagId];
    [xmlWriter writeCharacters:[NSString stringWithFormat:@"%d",type]];
    [xmlWriter writeEndElement];
    //</id>
    
    //<text>
    [xmlWriter writeStartElement:TagText];
    [xmlWriter writeCharacters:text];
    [xmlWriter writeEndElement];
    //</text>
    
    [xmlWriter writeEndElement];
    //</event>
    
    NSString* messageBody = [xmlWriter toString];
    
    if (messageBody)
    {
        hopMessage = [[HOPMessage alloc] initWithMessageId:[Utility getGUIDstring] andMessage:messageBody andContact:contact andMessageType:messageTypeSystem andMessageDate:[NSDate date]];
    }
    
    return hopMessage;
}

- (void) sendSystemMessageToInitSessionBetweenPeers:(NSArray*) peers forSession:(Session*) inSession
{
    NSString *messageText = @"";
    int counter = 0;
    for (HOPContact* contact in peers)
    {
        if (counter == 0 || counter == ([peers count] - 1) )
            messageText = [messageText stringByAppendingString:[contact getUserID]];
        else
            messageText = [messageText stringByAppendingFormat:@"%@,",[contact getUserID]];
        
    }
    
    HOPMessage* hopMessage = [self createSystemMessageWithType:SystemMessage_EstablishSessionBetweenTwoPeers andText:messageText andRecipient:[[[inSession participantsArray] objectAtIndex:0] hopContact]];
    [inSession.conversationThread sendMessage:hopMessage];
}

- (void) sendSystemMessageToCallAgainForSession:(Session*) inSession
{
    HOPMessage* hopMessage = [self createSystemMessageWithType:SystemMessage_CallAgain andText:systemMessageRequest andRecipient:[[[inSession participantsArray] objectAtIndex:0] hopContact]];
    [inSession.conversationThread sendMessage:hopMessage];
}

- (void) sendSystemMessageToCheckAvailabilityForSession:(Session*) inSession
{
    HOPMessage* hopMessage = [self createSystemMessageWithType:SystemMessage_IsContactAvailable andText:systemMessageRequest andRecipient:[[[inSession participantsArray] objectAtIndex:0] hopContact]];
    [inSession.conversationThread sendMessage:hopMessage];
}


- (void) sendSystemMessageToCheckAvailabilityResponseForSession:(Session*) inSession message:(NSString*) message
{
    HOPMessage* hopMessage = [self createSystemMessageWithType:SystemMessage_IsContactAvailable_Response andText:message andRecipient:[[[inSession participantsArray] objectAtIndex:0] hopContact]];
    [inSession.conversationThread sendMessage:hopMessage];
}

- (void) parseSystemMessage:(HOPMessage*) inMessage forSession:(Session*) inSession
{
    if ([inMessage.type isEqualToString:messageTypeSystem])
    {
        RXMLElement *eventElement = [RXMLElement elementFromXMLString:inMessage.text encoding:NSUTF8StringEncoding];
        if ([eventElement.tag isEqualToString:TagEvent])
        {
            SystemMessageTypes type = (SystemMessageTypes) [[eventElement child:TagId].text intValue];
            NSString* messageText =  [eventElement child:TagText].text;
            switch (type)
            {
                case SystemMessage_EstablishSessionBetweenTwoPeers:
                {
                    if ([messageText length] > 0)
                    [[SessionManager sharedSessionManager] createSessionInitiatedFromSession:inSession forContactUserIds:messageText];
                }
                break;
                    
                case SystemMessage_IsContactAvailable:
                {
                    [[SessionManager sharedSessionManager] onAvailabilityCheckReceivedForSession:inSession];
                }
                break;
                    
                case SystemMessage_IsContactAvailable_Response:
                {
                    [[ContactsManager sharedContactsManager] onCheckAvailabilityResponseReceivedForContact:[inSession.participantsArray objectAtIndex:0] withListOfUserIds:messageText];
                }
                    break;
                    
                case SystemMessage_CallAgain:
                {
                    [[SessionManager sharedSessionManager] redialCallForSession:inSession];
                }
                break;
                    
                default:
                    break;
            }
        }
    }
}
@end
