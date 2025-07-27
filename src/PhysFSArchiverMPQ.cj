package Diablo

import cenum.*
@When[stormLib == "dynamic"]
import clibrary.*
import dgengine.*
import std.math.*

foreign {
    // PhysFS

    func PHYSFS_getAllocator(): CPointer<PhysFSAllocator>

    func PHYSFS_setErrorCode(code: PhysFSErrorCode): Unit

    func PHYSFS_registerArchiver(archiver: CPointer<Unit>): Int32
}

@When[stormLib == "static"]
foreign {
    // StormLib

    func SFileOpenArchive(name: CString, priority: UInt32, flags: UInt32, hMpq: CPointer<CPointer<Unit>>): Bool

    func SFileCloseArchive(hMpq: CPointer<Unit>): Bool

    func SFileOpenFileEx(hMpq: CPointer<Unit>, fileName: CString, searchScope: UInt32, hFile: CPointer<CPointer<Unit>>): Bool

    func SFileGetFileSize(hFile: CPointer<Unit>, fileSizeHigh: CPointer<UInt32>): UInt32

    func SFileSetFilePointer(hFile: CPointer<Unit>, filePos: Int32, filePosHigh: CPointer<Int32>, moveMethod: UInt32): UInt32

    func SFileReadFile(hFile: CPointer<Unit>, buffer: CPointer<Unit>, toRead: UInt32, read: CPointer<UInt32>,
        lpOverlapped: CPointer<Unit>): Bool

    func SFileCloseFile(hFile: CPointer<Unit>): Bool

    func SFileGetFileInfo(hMpqOrFile: CPointer<Unit>, InfoClass: SFileInfoClass, fileInfo: CPointer<Unit>,
        cbFileInfo: UInt32, lengthNeeded: CPointer<UInt32>): Bool
}

private type StormFileOpenArchive = CFunc<(CString, UInt32, UInt32, CPointer<CPointer<Unit>>) -> Bool>

private type StormFileCloseArchive = CFunc<(hMpq: CPointer<Unit>) -> Bool>

private type StormFileOpenFileEx = CFunc<(hMpq: CPointer<Unit>, fileName: CString, searchScope: UInt32, hFile: CPointer<CPointer<Unit>>) -> Bool>

private type StormFileGetFileSize = CFunc<(hFile: CPointer<Unit>, fileSizeHigh: CPointer<UInt32>) -> UInt32>

private type StormFileSetFilePointer = CFunc<(hFile: CPointer<Unit>, filePos: Int32, filePosHigh: CPointer<Int32>,
    moveMethod: UInt32) -> UInt32>

private type StormFileReadFile = CFunc<(hFile: CPointer<Unit>, buffer: CPointer<Unit>, toRead: UInt32, read: CPointer<UInt32>,
    lpOverlapped: CPointer<Unit>) -> Bool>

private type StormFileCloseFile = CFunc<(hFile: CPointer<Unit>) -> Bool>

private type StormFileGetFileInfo = CFunc<(hMpqOrFile: CPointer<Unit>, InfoClass: SFileInfoClass, fileInfo: CPointer<Unit>,
    cbFileInfo: UInt32, lengthNeeded: CPointer<UInt32>) -> Bool>

@When[stormLib == "static"]
private class StormLib {
    public static let openArchive: StormFileOpenArchive = SFileOpenArchive
    public static let closeArchive: StormFileCloseArchive = SFileCloseArchive
    public static let openFileEx: StormFileOpenFileEx = SFileOpenFileEx
    public static let getFileSize: StormFileGetFileSize = SFileGetFileSize
    public static let setFilePointer: StormFileSetFilePointer = SFileSetFilePointer
    public static let readFile: StormFileReadFile = SFileReadFile
    public static let closeFile: StormFileCloseFile = SFileCloseFile
    public static let getFileInfo: StormFileGetFileInfo = SFileGetFileInfo

    public static const isLoaded = true
}

@When[stormLib != "static"]
private class StormLib {
    private static let stormLib: ?CLibrary

    public static let openArchive: StormFileOpenArchive
    public static let closeArchive: StormFileCloseArchive
    public static let openFileEx: StormFileOpenFileEx
    public static let getFileSize: StormFileGetFileSize
    public static let setFilePointer: StormFileSetFilePointer
    public static let readFile: StormFileReadFile
    public static let closeFile: StormFileCloseFile
    public static let getFileInfo: StormFileGetFileInfo

    public static let isLoaded: Bool

    static init() {
        @When[os == "Windows"]
        const libName = "StormLib.dll"

        @When[os != "Windows"]
        const libName = "./libstorm.so"

        logger.info("Loading external StormLib")

        if (let Some(clib) <- CLibrary.load(libName)) {
            stormLib = clib
            let openArchive = clib.get("SFileOpenArchive") ?? CPointer()
            let closeArchive = clib.get("SFileCloseArchive") ?? CPointer()
            let openFileEx = clib.get("SFileOpenFileEx") ?? CPointer()
            let getFileSize = clib.get("SFileGetFileSize") ?? CPointer()
            let setFilePointer = clib.get("SFileSetFilePointer") ?? CPointer()
            let readFile = clib.get("SFileReadFile") ?? CPointer()
            let closeFile = clib.get("SFileCloseFile") ?? CPointer()
            let getFileInfo = clib.get("SFileGetFileInfo") ?? CPointer()

            StormLib.openArchive = CFunc<(CString, UInt32, UInt32, CPointer<CPointer<Unit>>) -> Bool>(openArchive)
            StormLib.closeArchive = CFunc<(CPointer<Unit>) -> Bool>(closeArchive)
            StormLib.openFileEx = CFunc<(CPointer<Unit>, CString, UInt32, CPointer<CPointer<Unit>>) -> Bool>(openFileEx)
            StormLib.getFileSize = CFunc<(CPointer<Unit>, CPointer<UInt32>) -> UInt32>(getFileSize)
            StormLib.setFilePointer = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>, UInt32) -> UInt32>(setFilePointer)
            StormLib.readFile = CFunc<(CPointer<Unit>, CPointer<Unit>, UInt32, CPointer<UInt32>, CPointer<Unit>) -> Bool>(
                readFile)
            StormLib.closeFile = CFunc<(CPointer<Unit>) -> Bool>(closeFile)
            StormLib.getFileInfo = CFunc<(CPointer<Unit>, SFileInfoClass, CPointer<Unit>, UInt32, CPointer<UInt32>) -> Bool>(
                getFileInfo)

            if (openArchive.isNull() || closeArchive.isNull() || openFileEx.isNull() || getFileSize.isNull() ||
                setFilePointer.isNull() || readFile.isNull() || closeFile.isNull() || getFileInfo.isNull()) {
                clib.close()
                isLoaded = false
            } else {
                isLoaded = true
            }
        } else {
            stormLib = None
            openArchive = CFunc<(CString, UInt32, UInt32, CPointer<CPointer<Unit>>) -> Bool>(CPointer<Unit>())
            closeArchive = CFunc<(CPointer<Unit>) -> Bool>(CPointer<Unit>())
            openFileEx = CFunc<(CPointer<Unit>, CString, UInt32, CPointer<CPointer<Unit>>) -> Bool>(CPointer<Unit>())
            getFileSize = CFunc<(CPointer<Unit>, CPointer<UInt32>) -> UInt32>(CPointer<Unit>())
            setFilePointer = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>, UInt32) -> UInt32>(CPointer<Unit>())
            readFile = CFunc<(CPointer<Unit>, CPointer<Unit>, UInt32, CPointer<UInt32>, CPointer<Unit>) -> Bool>(
                CPointer<Unit>())
            closeFile = CFunc<(CPointer<Unit>) -> Bool>(CPointer<Unit>())
            getFileInfo = CFunc<(CPointer<Unit>, SFileInfoClass, CPointer<Unit>, UInt32, CPointer<UInt32>) -> Bool>(
                CPointer<Unit>())
            isLoaded = false
        }
        if (isLoaded) {
            logger.info("Using external StormLib")
        } else {
            logger.info("External StormLib not found")
        }
    }
}

private const FILE_BEGIN: UInt32 = 0
private const FILE_CURRENT: UInt32 = 1
// private const FILE_END: UInt32 = 2

private const MPQ_OPEN_READ_ONLY: UInt32 = 0x00000100
private const SFILE_INVALID_SIZE: UInt32 = 0xFFFFFFFF

@CEnum[PhysFSErrorCode](
    OK // Success; no error.
    OTHER_ERROR // Error not otherwise covered here.
    OUT_OF_MEMORY // Memory allocation failed.
    NOT_INITIALIZED // PhysicsFS is not initialized.
    IS_INITIALIZED // PhysicsFS is already initialized.
    ARGV0_IS_NULL // Needed argv[0], but it is NULL.
    UNSUPPORTED // Operation or feature unsupported.
    PAST_EOF // Attempted to access past end of file.
    FILES_STILL_OPEN // Files still open.
    INVALID_ARGUMENT // Bad parameter passed to an function.
    NOT_MOUNTED // Requested archive/dir not mounted.
    NOT_FOUND // File (or whatever) not found.
    SYMLINK_FORBIDDEN // Symlink seen when not permitted.
    NO_WRITE_DIR // No write dir has been specified.
    OPEN_FOR_READING // Wrote to a file opened for reading.
    OPEN_FOR_WRITING // Read from a file opened for writing.
    NOT_A_FILE // Needed a file, got a directory (etc).
    READ_ONLY // Wrote to a read-only filesystem.
    CORRUPT // Corrupted data encountered.
    SYMLINK_LOOP // Infinite symbolic link loop.
    IO // i/o error (hardware failure, etc).
    PERMISSION // Permission denied.
    NO_SPACE // No space (disk full, over quota, etc)
    BAD_FILENAME // Filename is bogus/insecure.
    BUSY // Tried to modify a file the OS needs.
    DIR_NOT_EMPTY // Tried to delete dir with files in it.
    OS_ERROR // Unspecified OS-level error.
    DUPLICATE // Duplicate entry.
    BAD_PASSWORD // Bad password.
    APP_CALLBACK // Application callback reported error.
)

@CEnum[PhysFSEnumerateCallbackResult](
    ERROR = -1 // Stop enumerating, report error to app.
    STOP = 0 // Stop enumerating, report success to app.
    OK = 1 // Keep enumerating, no problems
)

@CEnum[SFileInfoClass](
    // Info classes for archives
    MpqFileName // Name of the archive file (TCHAR [])
    MpqStreamBitmap // Array of bits, each bit means availability of one block (BYTE [])
    MpqUserDataOffset // Offset of the user data header (ULONGLONG)
    MpqUserDataHeader // Raw (unfixed) user data header (TMPQUserData)
    MpqUserData // MPQ USer data, without the header (BYTE [])
    MpqHeaderOffset // Offset of the MPQ header (ULONGLONG)
    MpqHeaderSize // Fixed size of the MPQ header
    MpqHeader // Raw (unfixed) archive header (TMPQHeader)
    MpqHetTableOffset // Offset of the HET table, relative to MPQ header (ULONGLONG)
    MpqHetTableSize // Compressed size of the HET table (ULONGLONG)
    MpqHetHeader // HET table header (TMPQHetHeader)
    MpqHetTable // HET table as pointer. Must be freed using SFileFreeFileInfo
    MpqBetTableOffset // Offset of the BET table, relative to MPQ header (ULONGLONG)
    MpqBetTableSize // Compressed size of the BET table (ULONGLONG)
    MpqBetHeader // BET table header, followed by the flags (TMPQBetHeader + DWORD[])
    MpqBetTable // BET table as pointer. Must be freed using SFileFreeFileInfo
    MpqHashTableOffset // Hash table offset, relative to MPQ header (ULONGLONG)
    MpqHashTableSize64 // Compressed size of the hash table (ULONGLONG)
    MpqHashTableSize // Size of the hash table, in entries (DWORD)
    MpqHashTable // Raw (unfixed) hash table (TMPQBlock [])
    MpqBlockTableOffset // Block table offset, relative to MPQ header (ULONGLONG)
    MpqBlockTableSize64 // Compressed size of the block table (ULONGLONG)
    MpqBlockTableSize // Size of the block table, in entries (DWORD)
    MpqBlockTable // Raw (unfixed) block table (TMPQBlock [])
    MpqHiBlockTableOffset // Hi-block table offset, relative to MPQ header (ULONGLONG)
    MpqHiBlockTableSize64 // Compressed size of the hi-block table (ULONGLONG)
    MpqHiBlockTable // The hi-block table (USHORT [])
    MpqSignatures // Signatures present in the MPQ (DWORD)
    MpqStrongSignatureOffset // Byte offset of the strong signature, relative to begin of the file (ULONGLONG)
    MpqStrongSignatureSize // Size of the strong signature (DWORD)
    MpqStrongSignature // The strong signature (BYTE [])
    MpqArchiveSize64 // Archive size from the header (ULONGLONG)
    MpqArchiveSize // Archive size from the header (DWORD)
    MpqMaxFileCount // Max number of files in the archive (DWORD)
    MpqFileTableSize // Number of entries in the file table (DWORD)
    MpqSectorSize // Sector size (DWORD)
    MpqNumberOfFiles // Number of files (DWORD)
    MpqRawChunkSize // Size of the raw data chunk for MD5
    MpqStreamFlags // Stream flags (DWORD)
    MpqFlags // Nonzero if the MPQ is read only (DWORD)

    // Info classes for files
    InfoPatchChain // Chain of patches where the file is (TCHAR [])
    InfoFileEntry // The file entry for the file (TFileEntry)
    InfoHashEntry // Hash table entry for the file (TMPQHash)
    InfoHashIndex // Index of the hash table entry (DWORD)
    InfoNameHash1 // The first name hash in the hash table (DWORD)
    InfoNameHash2 // The second name hash in the hash table (DWORD)
    InfoNameHash3 // 64-bit file name hash for the HET/BET tables (ULONGLONG)
    InfoLocale // File locale (DWORD)
    InfoFileIndex // Block index (DWORD)
    InfoByteOffset // File position in the archive (ULONGLONG)
    InfoFileTime // File time (ULONGLONG)
    InfoFileSize // Size of the file (DWORD)
    InfoCompressedSize // Compressed file size (DWORD)
    InfoFlags // File flags from (DWORD)
    InfoEncryptionKey // File encryption key
    InfoEncryptionKeyRaw // Unfixed value of the file key
    InfoCRC32 // CRC32 of the file
)

@C
struct PhysFSAllocator {
    let initialize = CFunc<() -> Int32>(CPointer<Unit>()) // Initialize. Can be NULL. Zero on failure.
    let deinit = CFunc<() -> Unit>(CPointer<Unit>()) // Deinitialize your allocator. Can be NULL.
    let malloc = CFunc<(size: UInt64) -> CPointer<Unit>>(CPointer<Unit>()) // Allocate like malloc().
    let realloc = CFunc<(ptr: CPointer<Unit>, newSize: UInt64) -> CPointer<Unit>>(CPointer<Unit>()) // Reallocate like realloc().
    let free = CFunc<(ptr: CPointer<Unit>) -> Unit>(CPointer<Unit>()) // Free memory from Malloc or Realloc.
}

private var allocator = PhysFSAllocator()

@C
private struct MPQIo {
    let version: UInt32 = 0
    let mpq: CPointer<MPQFileHandle>
    let read = MPQ_read
    let write = MPQ_write
    let seek = MPQ_seek
    let tell = MPQ_tell
    let length = MPQ_length
    let duplicate = MPQ_duplicate
    let flush = MPQ_flush
    let destroy = MPQ_destroy

    init(mpq: CPointer<MPQFileHandle>) {
        this.mpq = mpq
    }
}

@C
private struct MPQArchiver {
    let version: UInt32 = 0
    let extension: CString
    let description: CString
    let author: CString
    let url: CString
    let supportsSymlinks: Int32
    let openArchive = MPQ_openArchive
    let enumerate = MPQ_enumerate
    let openRead = MPQ_openRead
    let openWrite = MPQ_openWrite
    let openAppend = MPQ_openAppend
    let remove = MPQ_remove
    let mkdir = MPQ_mkdir
    let stat = MPQ_stat
    let closeArchive = MPQ_closeArchive

    init(extension!: CString, description!: CString, author!: CString, url!: CString, supportsSymlinks!: Int32) {
        this.extension = extension
        this.description = description
        this.author = author
        this.url = url
        this.supportsSymlinks = supportsSymlinks
    }
}

private const MPQExtension = "MPQ"
private const MPQDescription = "Blizzard Entertainment format"

@C
private struct MPQHandle {
    public MPQHandle(
        let io!: CPointer<MPQIo>,
        let handle!: CPointer<Unit>
    ) {}
}

@C
private struct MPQFileHandle {
    public MPQFileHandle(
        let handle!: CPointer<Unit>,
        let size!: Int64
    ) {}
}

func registerMPQArchiver(): Unit {
    unsafe {
        if (StormLib.isLoaded == false) {
            logger.error("Failed to load StormLib")
            return
        }
        let extension = LibC.mallocCString(MPQExtension)
        let description = LibC.mallocCString(MPQDescription)
        let empty = LibC.mallocCString(String.empty)
        try {
            var archiver = MPQArchiver(
                extension: extension,
                description: description,
                author: empty,
                url: empty,
                supportsSymlinks: 1
            )
            if (PHYSFS_registerArchiver(CPointer(inout archiver)) == 0) {
                logger.error("Failed to register MPQ archiver")
            }
        } finally {
            LibC.free(empty)
            LibC.free(description)
            LibC.free(extension)
        }
    }
}

@C
private func MPQ_read(io: CPointer<MPQIo>, buffer: CPointer<Unit>, length: UInt64): Int64 {
    unsafe {
        if (io.isNotNull()) {
            let file = io.read()
            if (file.mpq.isNotNull()) {
                let mpq = file.mpq.read()
                if (mpq.handle.isNotNull()) {
                    var bytesRead: UInt32 = 0
                    let bytesToRead = UInt32(min(length, UInt64(mpq.size)))
                    StormLib.readFile(mpq.handle, buffer, bytesToRead, inout bytesRead, CPointer())
                    if (bytesRead != bytesToRead) {
                        PHYSFS_setErrorCode(PhysFSErrorCode.IO)
                        return -1
                    }
                    return Int64(bytesRead)
                }
            }
        }
        PHYSFS_setErrorCode(PhysFSErrorCode.OTHER_ERROR)
        return -1
    }
}

@C
private func MPQ_write(_: CPointer<MPQIo>, _: CPointer<Unit>, _: UInt64): Int64 {
    unsafe { PHYSFS_setErrorCode(PhysFSErrorCode.READ_ONLY) }
    return -1
}

@C
private func MPQ_tell(io: CPointer<MPQIo>): Int64 {
    unsafe {
        if (io.isNotNull()) {
            let file = io.read()
            if (file.mpq.isNotNull()) {
                let mpq = file.mpq.read()
                if (mpq.handle.isNotNull()) {
                    var filePosHi: Int32 = 0
                    let filePosLo = StormLib.setFilePointer(mpq.handle, 0, inout filePosHi, FILE_CURRENT)
                    return ((Int64(filePosHi) << 32) | Int64(filePosLo))
                }
            }
        }
        PHYSFS_setErrorCode(PhysFSErrorCode.OTHER_ERROR)
        return -1
    }
}

@C
private func MPQ_seek(io: CPointer<MPQIo>, offset: UInt64): Int32 {
    unsafe {
        if (io.isNotNull()) {
            let file = io.read()
            if (file.mpq.isNotNull()) {
                let mpq = file.mpq.read()
                if (mpq.handle.isNotNull()) {
                    var deltaPosHi = Int32(offset >> 32)
                    var deltaPosLo = Int32(offset)
                    StormLib.setFilePointer(mpq.handle, deltaPosLo, inout deltaPosHi, FILE_BEGIN)
                    return 1
                }
            }
        }
        PHYSFS_setErrorCode(PhysFSErrorCode.OTHER_ERROR)
        return 0
    }
}

@C
private func MPQ_length(io: CPointer<MPQIo>): Int64 {
    unsafe {
        if (io.isNotNull()) {
            let file = io.read()
            if (file.mpq.isNotNull()) {
                let mpq = file.mpq.read()
                if (mpq.handle.isNotNull()) {
                    return mpq.size
                }
            }
        }
        return -1
    }
}

@C
private func MPQ_duplicate(_: CPointer<MPQIo>): CPointer<MPQIo> {
    unsafe { PHYSFS_setErrorCode(PhysFSErrorCode.UNSUPPORTED) }
    return CPointer()
}

@C
private func MPQ_flush(_: CPointer<MPQIo>): Int32 {
    return 1 // no write support
}

@C
private func MPQ_destroy(io: CPointer<MPQIo>): Unit {
    unsafe {
        if (io.isNotNull()) {
            let file = io.read()
            if (file.mpq.isNotNull()) {
                let mpq = file.mpq.read()
                if (mpq.handle.isNotNull()) {
                    StormLib.closeFile(mpq.handle)
                }
                allocator.free(CPointer(file.mpq))
            }
            allocator.free(CPointer(io))
        }
    }
}

@C
private func MPQ_openArchive(io: CPointer<MPQIo>, fileName: CString, forWriting: Int32, claimed: CPointer<Int32>): CPointer<MPQHandle> {
    unsafe {
        if (io.isNotNull()) {
            if (forWriting != 0) {
                PHYSFS_setErrorCode(PhysFSErrorCode.READ_ONLY)
                return CPointer()
            }

            if (CPointer<Unit>(allocator.malloc).isNull()) {
                let allocPtr = PHYSFS_getAllocator()
                if (allocPtr.isNotNull()) {
                    allocator = allocPtr.read()
                }
                if (CPointer<Unit>(allocator.malloc).isNull()) {
                    PHYSFS_setErrorCode(PhysFSErrorCode.OTHER_ERROR)
                    return CPointer()
                }
            }

            var hMpq = CPointer<Unit>()
            if (StormLib.openArchive(fileName, 0, MPQ_OPEN_READ_ONLY, inout hMpq) == false) {
                return CPointer()
            }

            claimed.write(1)

            let handle = CPointer<MPQHandle>(allocator.malloc(UInt64(sizeOf<MPQHandle>())))
            if (handle.isNotNull()) {
                var mpqHandle = MPQHandle(
                    io: io,
                    handle: hMpq
                )
                handle.write(mpqHandle)
                return handle
            }

            StormLib.closeArchive(hMpq)
        }
    }
    return CPointer()
}

@C
private func MPQ_enumerate(_: CPointer<MPQHandle>, _: CString, _: CFunc<() -> Unit>, _: CString, _: CPointer<Unit>): PhysFSEnumerateCallbackResult {
    PhysFSEnumerateCallbackResult.ERROR
}

@C
private func MPQ_openRead(archive: CPointer<MPQHandle>, fileName: CString): CPointer<MPQIo> {
    unsafe {
        if (archive.isNotNull()) {
            let mpqArchive = archive.read()

            var hFile = CPointer<Unit>()

            let fileName = LibC.mallocCString(fileName.toString().replace('/', '\\'))
            try (fileNameRes = fileName.asResource()) {
                let success = StormLib.openFileEx(mpqArchive.handle, fileNameRes.value, 0, inout hFile)
                if (success == false) {
                    return CPointer()
                }
            }

            var fileSizeHi: UInt32 = 0xCCCCCCCC
            let fileSizeLo: UInt32 = StormLib.getFileSize(hFile, inout fileSizeHi)
            if (fileSizeLo != SFILE_INVALID_SIZE && fileSizeHi == 0) {
                var file = MPQFileHandle(
                    handle: hFile,
                    size: Int64(fileSizeLo)
                )

                let io = MPQIo(CPointer<MPQFileHandle>(allocator.malloc(UInt64(sizeOf<MPQFileHandle>()))))
                if (io.mpq.isNotNull()) {
                    io.mpq.write(file)
                    let ioPtr = CPointer<MPQIo>(allocator.malloc(UInt64(sizeOf<MPQIo>())))
                    if (ioPtr.isNotNull()) {
                        ioPtr.write(io)
                        return ioPtr
                    }
                    allocator.free(CPointer(io.mpq))
                }
            }

            StormLib.closeFile(hFile)
        }
    }
    return CPointer()
}

@C
private func MPQ_openWrite(_: CPointer<MPQHandle>, _: CString): CPointer<MPQIo> {
    unsafe { PHYSFS_setErrorCode(PhysFSErrorCode.READ_ONLY) }
    return CPointer()
}

@C
private func MPQ_openAppend(_: CPointer<MPQHandle>, _: CString): CPointer<MPQIo> {
    unsafe { PHYSFS_setErrorCode(PhysFSErrorCode.READ_ONLY) }
    return CPointer()
}

@C
private func MPQ_remove(_: CPointer<MPQHandle>, _: CString): Int32 {
    unsafe { PHYSFS_setErrorCode(PhysFSErrorCode.READ_ONLY) }
    return 0
}

@C
private func MPQ_mkdir(_: CPointer<MPQHandle>, _: CString): Int32 {
    unsafe { PHYSFS_setErrorCode(PhysFSErrorCode.READ_ONLY) }
    return 0
}

@C
private func MPQ_stat(archive: CPointer<MPQHandle>, fileName: CString, stat: CPointer<PhysFSStat>): Int32 {
    unsafe {
        if (archive.isNotNull()) {
            let mpqArchive = archive.read()

            var hFile = CPointer<Unit>()

            let fileName = LibC.mallocCString(fileName.toString().replace('/', '\\'))
            try (fileNameRes = fileName.asResource()) {
                let success = StormLib.openFileEx(mpqArchive.handle, fileNameRes.value, 0, inout hFile)
                if (success == false) {
                    return 0
                }
            }

            var fileSize: UInt32 = 0
            StormLib.getFileInfo(hFile, SFileInfoClass.InfoFileSize, CPointer(inout fileSize), UInt32(sizeOf<UInt32>()),
                CPointer())

            var modTime: Int64 = 0
            StormLib.getFileInfo(hFile, SFileInfoClass.InfoFileTime, CPointer(inout modTime), UInt32(sizeOf<Int64>()),
                CPointer())

            StormLib.closeFile(hFile)

            if (stat.isNotNull()) {
                var mpqStat = PhysFSStat(
                    filesize: Int64(fileSize),
                    modtime: modTime,
                    createtime: modTime,
                    readonly: 1,
                )
                stat.write(mpqStat)
                return 1
            }
        }
    }
    return 0
}

@C
private func MPQ_closeArchive(archive: CPointer<MPQHandle>): Unit {
    unsafe {
        if (archive.isNotNull()) {
            let mpqArchive = archive.read()
            StormLib.closeArchive(mpqArchive.handle)

            if (mpqArchive.io.isNotNull()) {
                let io = mpqArchive.io.read()
                io.destroy(mpqArchive.io)
                allocator.free(CPointer(mpqArchive.io))
            }
            allocator.free(CPointer(archive))
        }
    }
}
