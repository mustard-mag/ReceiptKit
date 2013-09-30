//
//  RTKASN1Object.m
//  ReceiptKit
//
//  Created by Richard Stelling on 26/09/2013.
//  Copyright (c) 2013 Empirical Magic Ltd. All rights reserved.
//

#import "RTKASN1Object.h"
#import <openssl/pkcs7.h>

#import "RTKASN1Set.h"
#import "RTKASN1Sequence.h"
#import "RTKASN1OctetString.h"

/*
 ReceiptModule DEFINITIONS ::=
 BEGIN
 
 ReceiptAttribute ::= SEQUENCE {
 type    INTEGER,
 version INTEGER,
 value   OCTET STRING
 }
 
 Payload ::= SET OF ReceiptAttribute
 
 END
 */

@implementation RTKASN1Object

+ (id)decodeASN1Data:(NSData *)data
{
    const uint8_t *locationInData = data.bytes;
    const uint8_t *endOfData = (locationInData + data.length);
    const uint8_t *lengthToRead = (data.length + locationInData);
    
    //In the outer container there maybe mutiple objects. In this case
    //this method will return an array of these objects, if only one root
    //object is found that object is returned and this array removed.
    NSMutableArray *decodedObjects = [NSMutableArray arrayWithCapacity:1];
    
    int count = 0;              //count objects
    
    do
    {
        long length = 0;            //hold returnd length of read data
        int type = 0, xclass = 0;   //hold type of object
        
        //Subtract the locationInData from length to read because locationInData will
        //be incremented by ASN1_get_object and by adding the length
        int result = ASN1_get_object(&locationInData, &length, &type, &xclass, (lengthToRead - locationInData));
        
        //NSLog(@"[%d] Type: %d (length: %ld) result: %d", count, type, length, result);
        
        //Remember: locationInData has be incremented pased the tyoe and length,
        //so just reading the data is enough to get the value/data. When creating
        //an ASN.1 type object a copy of the locationInData pointer is taken
        //so we can just jump over the object by adding length to locationInData
        //once processed.
        
        NSData *asn1ObjectData = [NSData dataWithBytesNoCopy:(void *)locationInData length:length freeWhenDone:NO];
        
        if(result == V_ASN1_CONSTRUCTED)
        {
            //NSLog(@"Created an ASN.1 structure");
            [decodedObjects addObject:[self decodeConstructObject:type data:asn1ObjectData]];
        }
        else if(result == V_ASN1_UNIVERSAL)
        {
            //NSLog(@"Data is a specific type (int, bool et. al.)");
            [decodedObjects addObject:[self decodeUniversalObject:type data:asn1ObjectData]];
        }
        else if(result == V_ASN1_CONTEXT_SPECIFIC)
        {
            //NSLog(@"Context specific (just copy everything)");
            [decodedObjects addObject:[data copy]];
            
            break;
            
            //if(length == 0)
            //    length = data.length;
        }
        else
        {
            //Unsure what to do here
            //NSLog(@"This is odd... %d", result);
        }
        
        //Advance to next object, ASN1_get_object has already increased
        //locationInData by 2 bytes (type and length)
        locationInData += length;
        count++;
    } while(locationInData < endOfData);
    
    //Return an NSArray if we found more that one root object
    return [decodedObjects count]==1?decodedObjects[0]:[decodedObjects copy];
}

+ (id)decodeConstructObject:(int)objectType data:(NSData *)constructObjectData
{
    id returnObject = nil;
    
    switch(objectType)
    {
        case V_ASN1_SET:
            returnObject = [[RTKASN1Set alloc] initWithData:constructObjectData];
            break;
            
        case V_ASN1_SEQUENCE:
            returnObject = [[RTKASN1Sequence alloc] initWithData:constructObjectData];
            break;
            
        default:
            
            break;
    }
    
    return returnObject;
}

+ (id)decodeUniversalObject:(int)objectType data:(NSData *)universalObjectData
{
    id returnObject = nil;
    
    switch(objectType)
    {
        case V_ASN1_INTEGER:
            //This will only correctly decode integers of one byte
        {
            int length = universalObjectData.length;
            int integer = 0;
            int maxSiftValue = ({
                int shiftVal = (int)pow(2, (length + 1));
                shiftVal = (shiftVal==4?0:shiftVal);
                shiftVal; //return
            });
            
            for(int i = 0; i < universalObjectData.length; i++)
            {
                long long value = 0;
                [universalObjectData getBytes:&value range:NSMakeRange(i, 1)];
                integer += (value << maxSiftValue);
                maxSiftValue -= 8;
            }

            returnObject = @(integer);
        }
            break;
            
        case V_ASN1_OCTET_STRING:
        {
            returnObject = [[RTKASN1OctetString alloc] initWithData:universalObjectData];
        }
            break;
            
        case V_ASN1_UTF8STRING:
        {
            returnObject = [[NSString alloc] initWithData:universalObjectData
                                                 encoding:NSUTF8StringEncoding];
        }
            break;
        
        case V_ASN1_IA5STRING:
        {
            returnObject = [[NSString alloc] initWithData:universalObjectData
                                                 encoding:NSASCIIStringEncoding];
        }
            break;
            
        default:
            //Currently we dont support this type, so just copy the data
            //returnObject = [universalObjectData copy];
            break;
    }
    
    return returnObject;
}

@end
