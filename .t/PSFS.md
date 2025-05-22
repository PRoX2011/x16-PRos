# PSFS

___

## About

* PSFS stands for **P**avahali'**s** **File** **S**ystem or **P**retty **S**hitty **F**ile **S**ystem
* It consists of superblock, file/folder entries (inodes, if you like), link group and data

___
## For future reading

There is a table that describes layout (in bytes). It looks like this:

|Start|End|Len|About|
|:-:|:-:|:-:|:--|
|Starting byte|Last byte|Lenth|Describtion|

Every example of that table below is for 512 byte sectors. Only thing sector size affect is the count of links in [entries](#Entry) and [link groups](#Link_group)

___

## Layout

### Superblock
Superblock contains basic information about filesystem

|Start|End|Len|About|
|:-:|:-:|:-:|:--|
|0|1|1|Magic number that identifies filesystem. This should be equal 0x69|
|1|2|1|Filesystem version. For now, it equals 0x1|
|2|3|1|This number describes size of disk sector (see [magic numbers](#Size_of_disk_sector))|
|3|4|1|Disk type (see [magic numbers](#Disk_type))|
|4|36|32|Disk name in ASCII (padded with space)|
|36|37|1|Lenth of pointers (see [magic numbers](#Lenth_pointers))|
|37|512|-|Unused space|

Here is an example c struct
```c
#include <stdint.h>

struct Superblock {
	uint8_t		magic_number;
	uint8_t		fs_version;
	uint8_t		disk_type;
	uint8_t[32]	disk_name;
	uint8_t		pointer_len;
}
```


<h3 id="Entry">Entry</h3>

Everything starts from here - second sector aka root directory aka just entry. File and directory entry look same.

You may ask "how can I check if entry is directory?". Here is the answer: [permissions](). In that byte directory flag is stored, so:

* If entry is a file (equals 0) - pointers are pointing (o_o) to file data

* If entry is a directory (equals 1) - pointers are pointing to other entries

Predicting your next question I will explain the way to deal with big files: [link group](). Basically, this is the link to other set of links


|Start|End|Len|About|
|:-:|:-:|:-:|:--|
|0|1|1|Permissions (see [magic numbers](#))|
|1|32|31|Entry name in ASCII padded with spaces|
|32|512|480|Field containing pointers to entry contents/next link group|

```c
#include <stdint.h>

struct Entry {
	uint8_t		permissions;
	uint8_t[31]	name;

	#if 		(Superblock.pointer_len == 0)
	uint8_t[59]	pointers;
	uint8_t		link_group;

	#elif	(Superblock.pointer_len == 1)
	uint16_[29]	pointers;
	uint16_t	link_group;

	#elif	(Superblock.pointer_len == 2)
	uint32_t[14]	pointers;
	uint32_t	link_group;

	#endif
}
```


<h3 id="Link_group">Link group</h3>
Some files are big. They may have so many pointers that entry can't store them. So, here comes the link group. It's the simpliest structure:

|Start|End|Len|About|
|:-:|:-:|:-:|:--|
|0|512|512|Field containing pointers to entry contents/next link group|

```c
#include <stdint.h>

struct LinkGroup {
	#if 		(Superblock.pointer_len == 0)
	uint8_t[63]	pointers;
	uint8_t		link_group;

	#elif	(Superblock.pointer_len == 1)
	uint16_[31]	pointers;
	uint16_t	link_group;

	#elif	(Superblock.pointer_len == 2)
	uint32_t[15]	pointers;
	uint32_t	link_group;

	#endif
}
```

**And yes, link group can have pointer to next link group**

___

## How to start (lets say, the task is to find file '/sys/kernel')

### I. Read superblock (second sector)
* If you not sure it's PSFS, check first byte (should be equal 0x69)
* Only important thing here is the [lenth of pointers](#Lenth_pointers)

### II. Read root directory (third sector)
Root direcory always located afrer superblock so you know where to start
* Get root directory pointers
* Iterate through them seeking locations they're pointing:
	* If pointer doesn't equal `0`, then it's pointing to something
	* If last pointer doesn't equal `0`, then it's pointing to link group you should go thru too
	* Same with link group's last pointer
* Do it until you find entry with name `sys` and [permissions](#Permissions) value bigger or equal `0x80`

### III. Hurray, you got to /sys dir
* Now you should iterate through this directory entry as earlier
* Find an entry with name `kernel` and [permissions](#Permissions) value smaller than `0x80`

### IV. End
* You have `/sys/kernel` entry. Now just glue it piece by piece, sector by sector iterating through pointers

___

## Appendix

### Magic numbers

<h4 id="Size_of_disk_sector">Size of disk sector </h4>

This value is computed by formula `2^(x+7)`, for example `2^(2+7) = 2^9 = 512`

|Value|Meaning|
|:-:|:--|
|0|128 bytes|
|1|256 bytes|
|2|512 bytes|
|3|1024 bytes|
|4|2048 bytes|
|5|4096 bytes|
|6|8192 bytes|

<h4 id="Disk_type">Disk type </h4>
I don't think I should say more

|Value|Meaning|
|:-:|:--|
|0|floppy|
|1|hard drive|
|2|cdrom|

<h4 id="Lenth_pointers">Lenth of pointers</h4>
Lenth of pointers affects filesystem limits. If 16byte pointers are used and sector size is 512 bytes, then maximum filesystem capacity is `2^16 * 512 = 33.554.432 bytes = 32 megabytes`

|Value|Meaning|
|:-:|:--|
|0|8 bytes|
|1|16 bytes|
|2|32 bytes|

<h4 id="Permissions">Permissions</h4>

There is 2 ways to understand that
1. Each byte represents a permission (first is read, second is write etc.)
2. Permissions value is counted by sum of these values:

|Value|Meaning|
|:-:|:--|
|0x01|Read|
|0x02|Write|
|0x04|Delete|
|0x08|-|
|0x10|-|
|0x20|-|
|0x40|-|
|0x80|Directory flag|
