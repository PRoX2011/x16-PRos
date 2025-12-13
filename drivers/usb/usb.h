#ifndef USB_H
#define USB_H

#include <stdint.h>

#define USB_DIR_OUT             0x00
#define USB_DIR_IN              0x80
#define USB_TYPE_STANDARD       0x00
#define USB_TYPE_CLASS          0x20
#define USB_TYPE_VENDOR         0x40
#define USB_TYPE_RESERVED       0xC0
#define USB_RECIP_DEVICE        0x00
#define USB_RECIP_INTERFACE     0x01
#define USB_RECIP_ENDPOINT      0x02
#define USB_RECIP_OTHER         0x03

// Type of USB Descriptors
#define USB_DESC_TYPE_DEVICE           0x01
#define USB_DESC_TYPE_CONFIGURATION    0x02
#define USB_DESC_TYPE_STRING           0x03
#define USB_DESC_TYPE_INTERFACE        0x04
#define USB_DESC_TYPE_ENDPOINT         0x05

// Standard USB Requests
#define USB_REQ_GET_STATUS             0x00
#define USB_REQ_CLEAR_FEATURE          0x01
#define USB_REQ_SET_ADDRESS            0x05 // Host assigns address to device
#define USB_REQ_GET_DESCRIPTOR         0x06
#define USB_REQ_SET_CONFIGURATION      0x09 // Host activates the device

typedef struct __attribute__((packed)) 
{
    uint8_t  bLength;
    uint8_t  bDescriptorType;
    uint16_t bcdUSB;          // USB version
    uint8_t  bDeviceClass;
    uint8_t  bDeviceSubClass;
    uint8_t  bDeviceProtocol;
    uint8_t  bMaxPacketSize0; // Default is 64 bytes
    uint16_t idVendor;        // VID
    uint16_t idProduct;       // PID
    uint16_t bcdDevice;       // Your device version
    uint8_t  iManufacturer;   // Index of manufacturer string
    uint8_t  iProduct;        // Index of product string
    uint8_t  iSerialNumber;   // Index of serial number string
    uint8_t  bNumConfigurations; // Default is 1 
} usb_descriptor_t;
#endif