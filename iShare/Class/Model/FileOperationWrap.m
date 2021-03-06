//
//  FileOperationWrap.m
//  iShare
//
//  Created by Jin Jin on 12-8-8.
//  Copyright (c) 2012年 Jin Jin. All rights reserved.
//

#import "FileOperationWrap.h"
#import "ZipFile.h"
#import "FileInZipInfo.h"
#import "ZipWriteStream.h"
#import "ZipReadStream.h"
#import "JJThumbnailCache.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation FileOperationWrap

+(void)removeFileItems:(NSArray*)fileItems withCompletionBlock:(FileOperationCompletionBlock)block{
    [fileItems enumerateObjectsUsingBlock:^(NSString* filePaths, NSUInteger idx, BOOL *stop){
        [[NSFileManager defaultManager] removeItemAtPath:filePaths error:NULL];
    }];
    
    if (block){
        block(YES);
    }
}

+(BOOL)createDirectoryWithName:(NSString*)name path:(NSString*)path{
    NSString* folderPath = [self validFilePathForFilename:name atPath:path];
    return [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:NO attributes:nil error:NULL];
}

+(BOOL)createFileWithName:(NSString*)name path:(NSString*)path{
    NSString* filePath = [path stringByAppendingPathComponent:name];
    NSString* fileContent = @"";
    return [[NSFileManager defaultManager] createFileAtPath:filePath contents:[fileContent dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
}

+(BOOL)saveFile:(NSData*)fileData withName:(NSString*)name path:(NSString*)path{
    
    NSString* filePath = [self validFilePathForFilename:name atPath:path];
    
    return [[NSFileManager defaultManager] createFileAtPath:filePath contents:fileData attributes:nil];
}

+(NSString*)zipFileAtFilePath:(NSString*)filePath toPath:(NSString*)path{
    
    NSString* filename = [[filePath lastPathComponent] stringByAppendingPathExtension:@"zip"];
    NSString* zipPath = [FileOperationWrap validFilePathForFilename:filename atPath:path];
    NSData* fileData = [NSData dataWithContentsOfFile:filePath];
    NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];
    
    ZipFile *zipFile= [[ZipFile alloc] initWithFileName:zipPath mode:ZipFileModeCreate];
    ZipWriteStream *stream1= [zipFile writeFileInZipWithName:[filePath lastPathComponent] fileDate:[attributes fileModificationDate] compressionLevel:ZipCompressionLevelBest];
    @try {
        [stream1 writeData:fileData];
        [stream1 finishedWriting];
        [zipFile close];
    }
    @catch (NSException *exception) {
        NSLog(@"zip failed: %@", exception.reason);
        zipPath = nil;
    }
    
    return zipPath;
}

+(BOOL)unzipFileAtFilePath:(NSString*)filePath toPath:(NSString*)path{
    
    BOOL result = YES;
    
    //create folder to zip file
    
    ZipFile *unzipFile= [[ZipFile alloc] initWithFileName:filePath mode:ZipFileModeUnzip];
    
    [unzipFile goToFirstFileInZip];
    BOOL keepReading = YES;
    
    @try {
        while(keepReading){
            FileInZipInfo *fInfo = [unzipFile getCurrentFileInZipInfo];
            //获得当前遍历文件的信息，包括大小、文件名、压缩级等等
            ZipReadStream *readStream = [unzipFile readCurrentFileInZip];
            //将当前文件读入readStream，如果当前文件有加密则使用readCurrentFileInZipWithPassword
//            ZipReadStream* readStream = [unzipFile readCurrentFileInZipWithPassword:password];
            NSMutableData *data = [[NSMutableData alloc] initWithLength:fInfo.length];
            //发现data的长度给的不对就要出问题，所以用文件大小初始化
            [readStream readDataWithBuffer:data];
            [readStream finishedReading];
            //写入到文件
            NSString* unzippedFilename = [self validFilePathForFilename:fInfo.name atPath:path];
            [data writeToFile:unzippedFilename atomically:YES];
            //读取下一个文件
            keepReading = [unzipFile goToNextFileInZip];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"unzip file %@ failed:%@", filePath, exception.reason);
        result = NO;
    }

    [unzipFile close];
    return result;
}

+(UIImage*)thumbnailForFile:(NSString*)filePath previewEnabled:(BOOL)previewEnabled{
    
    FileContentType type = [self fileTypeWithFilePath:filePath];
    UIImage* image = nil;
    if (type == FileContentTypeImage && previewEnabled){
        NSURL* url = [NSURL fileURLWithPath:filePath];
        CGFloat scale = [UIScreen mainScreen].scale;
        CGSize size = CGSizeMake(50*scale, 50*scale);
        image = [JJThumbnailCache thumbnailForURL:url andSize:size mode:UIViewContentModeScaleAspectFit];
        if (image == nil){
            image = [JJThumbnailCache storeThumbnail:[UIImage imageWithContentsOfFile:filePath] forURL:url size:size mode:UIViewContentModeScaleAspectFit];
        }
    }else{
        image = [UIImage imageNamed:[self thumbnailNameForFile:filePath]];
    }
    
    return image;
}

+(NSString*)thumbnailNameForFile:(NSString*)filePath{
    NSString* namePreview = @"fileicon_";
    NSString* thumbnail = nil;
    
    FileContentType type = [self fileTypeWithFilePath:filePath];
    NSString* ext = [[filePath pathExtension] lowercaseString];
    if (type == FileContentTypeDirectory){
        thumbnail = @"fileicon_folder";
    }else{
        thumbnail = [namePreview stringByAppendingString:ext];
        NSString* thumbpath = [[NSBundle mainBundle] pathForResource:thumbnail ofType:@"png"];
        if (thumbpath == nil){
            switch (type) {
                case FileContentTypeCompress:
                    thumbnail = @"fileicon_compressed";
                    break;
                case FileContentTypeImage:
                    thumbnail = @"fileicon_image";
                    break;
                case FileContentTypeMovie:
                    thumbnail = @"fileicon_movie";
                    break;
                case FileContentTypeMusic:
                    thumbnail = @"fileicon_music";
                    break;
                case FileContentTypeText:
                    thumbnail = @"fileicon_txt";
                    break;
                default:
                    thumbnail = @"fileicon_bg";
                    break;
            }
        }
    }
    
    return thumbnail;
}

+(NSString*)validFilePathForFilename:(NSString*)filename atPath:(NSString*)path{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* extension = [filename pathExtension];
    NSRange extensionRange = [filename rangeOfString:[NSString stringWithFormat:@".%@", extension] options:NSBackwardsSearch];
    
    NSString* realName = filename;
    if (extensionRange.location != NSNotFound){
        realName = [filename substringToIndex:extensionRange.location];
    }
    
    NSString* validPath = [path stringByAppendingPathComponent:filename];
    
    int index =  1;
    
    BOOL isDir = NO;
    while([fm fileExistsAtPath:validPath isDirectory:&isDir] == YES){
        NSString* tempname = [NSString stringWithFormat:@"%@ %d", realName, index++];
        tempname = (extension.length > 0)?[tempname stringByAppendingPathExtension:extension]:tempname;
        validPath = [path stringByAppendingPathComponent:tempname];
    }
    
    return validPath;

}

+(NSArray*)allImagePathsInFolder:(NSString*)folder{
    return [self allFilesWithFileContentType:FileContentTypeImage inFolder:folder];
}

+(NSArray*)allFilesWithFileContentType:(FileContentType)type inFolder:(NSString*)folder{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSArray* filenames = [fm contentsOfDirectoryAtPath:folder error:NULL];
    NSMutableArray* allFiles = [NSMutableArray array];
    [filenames enumerateObjectsUsingBlock:^(NSString* filename, NSUInteger idx, BOOL* stop){
        NSString* filePath = [folder stringByAppendingPathComponent:filename];
        if ([self fileTypeWithFilePath:filePath] == type){
            [allFiles addObject:filePath];
        }
    }];
    
    return allFiles;
}

+(FileContentType)fileTypeWithFilePath:(NSString*)filePath{
    NSDictionary* attribute = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];

    UIDocument* document = [[UIDocument alloc] initWithFileURL:[NSURL fileURLWithPath:filePath]];

    DebugLog(@"file type is %@", document.fileType);
    
    if ([[attribute fileType] isEqualToString:NSFileTypeDirectory]){
        //
        return FileContentTypeDirectory;
    }
    
    if (UTTypeConformsTo((__bridge CFStringRef)(document.fileType), (CFStringRef)kUTTypeImage)){
        return FileContentTypeImage;
    }
    
    if (UTTypeConformsTo((__bridge CFStringRef)(document.fileType), (CFStringRef)kUTTypePDF)){
        return FileContentTypePDF;
    }
    
    if (UTTypeConformsTo((__bridge CFStringRef)(document.fileType), (CFStringRef)kUTTypeQuickTimeMovie) || UTTypeConformsTo((__bridge CFStringRef)(document.fileType), (CFStringRef)kUTTypeMPEG) || UTTypeConformsTo((__bridge CFStringRef)(document.fileType), (CFStringRef)kUTTypeMPEG4)){
        return FileContentTypeMovie;
    }
    
    if (UTTypeConformsTo((__bridge CFStringRef)(document.fileType), (CFStringRef)kUTTypeAudio)){
        return FileContentTypeMusic;
    }
    
    if (UTTypeConformsTo((__bridge CFStringRef)(document.fileType), (CFStringRef)kUTTypePlainText)){
        return FileContentTypeText;
    }
    
    if (UTTypeConformsTo((__bridge CFStringRef)(document.fileType), (CFStringRef)kUTTypeInkText)){
        return FileContentTypeDocument;
    }
    
    if (UTTypeConformsTo((__bridge CFStringRef)(document.fileType), (CFStringRef)@"com.pkware.zip-archive")){
        return FileContentTypeCompress;
    }
    
    return FileContentTypeOther;
}

+(NSString*)homePath{
    NSString* defaultFilePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    DebugLog(@"%@", defaultFilePath);
    return defaultFilePath;
}

+(NSString*)tempFolder{
    NSString* tempFolder = NSTemporaryDirectory();
    DebugLog(@"%@", tempFolder);
    return tempFolder;
}

+(void)clearTempFolder{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* tempFolder = [self tempFolder];
    NSArray* items = [fm contentsOfDirectoryAtPath:tempFolder error:NULL];
    
    [items enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSString* filename, NSUInteger idx, BOOL* stop){
        [fm removeItemAtPath:[tempFolder stringByAppendingPathComponent:filename] error:NULL];
    }];
}

+(void)openFileItemAtPath:(NSString*)filePath withController:(UIViewController*)controller{
    NSDictionary* attribute = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];
    //for direcroty
    if ([[attribute fileType] isEqualToString:NSFileTypeDirectory]){
        
    }
}

+(NSString*)normalizedSize:(long long)size{
    
    if (size <= 999){
        return [NSString stringWithFormat:@"%.0f B", (double)size];
    }else if (size > 999 && size <= 999999){
        return [NSString stringWithFormat:@"%.1f KB", ((double)size)/1000];
    }else if (size > 999999 && size <= 999999999){
        return [NSString stringWithFormat:@"%.2f MB", ((double)size)/1000000];
    }else{
        return [NSString stringWithFormat:@"%.2f GB", ((double)size)/1000000000];
    }
}
@end
