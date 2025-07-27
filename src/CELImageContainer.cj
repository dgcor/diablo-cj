package Diablo

import cjsfml.graphics.*
import cjsfml.graphics.Image as SFMLImage
import dgengine.*
import endian.*
import std.collection.*
import std.io.{ByteBuffer, SeekPosition}

private enum CELType {
    | None
    | V1Regular
    | V1Compilation
    | V1Level
}

private enum CELFrameType {
    | Regular // == LEVEL_TYPE_1
    | LevelType0 // 0x400 full opaque
    | LevelType2 // 0x220 left transparency
    | LevelType3 // 0x220 right transparency
    | LevelType4 // 0x320 left transparency
    | LevelType5 // 0x320 right transparency
}

// CEL decoding code based on Diablo 1 Graphics Tool by savagesteel
// https://github.com/savagesteel/d1-graphics-tool
class CELImageContainer <: LazyImageContainer {
    private var m_celType: CELType = None
    private var m_directions: UInt32 = 0

    private static const celLevelFrameType2: VArray<UInt8, $512> = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,
        0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    private static const celLevelFrameType2ZeroedBytes: VArray<UInt16, $32> = [0, 1, 8, 9, 24, 25, 48, 49, 80, 81, 120,
        121, 168, 169, 224, 225, 288, 289, 348, 349, 400, 401, 444, 445, 480, 481, 508, 509, 528, 529, 540, 541]
    private static const celLevelFrameType3: VArray<UInt8, $512> = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    private static const celLevelFrameType3ZeroedBytes: VArray<UInt16, $32> = [2, 3, 14, 15, 34, 35, 62, 63, 98, 99, 142,
        143, 194, 195, 254, 255, 318, 319, 374, 375, 422, 423, 462, 463, 494, 495, 518, 519, 534, 535, 542, 543]
    private static const celLevelFrameType4: VArray<UInt8, $512> = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    private static const celLevelFrameType4ZeroedBytes: VArray<UInt16, $32> = [0, 1, 8, 9, 24, 25, 48, 49, 80, 81, 120,
        121, 168, 169, 224, 225, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    private static const celLevelFrameType5: VArray<UInt8, $512> = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    private static const celLevelFrameType5ZeroedBytes: VArray<UInt16, $32> = [2, 3, 14, 15, 34, 35, 62, 63, 98, 99, 142,
        143, 194, 195, 254, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    private static func getLevelFrame220Type(frameData: Array<Byte>): CELFrameType {
        var frameType = Regular
        for (i in 0..32) {
            if (frameData[Int64(celLevelFrameType2ZeroedBytes[i])] != 0) {
                break
            }
            if (i == 31) {
                frameType = LevelType2
            }
        }
        for (i in 0..32) {
            if (frameData[Int64(celLevelFrameType3ZeroedBytes[i])] != 0) {
                break
            }
            if (i == 31) {
                frameType = LevelType3
            }
        }
        return frameType
    }

    private static func getLevelFrame320Type(frameData: Array<Byte>): CELFrameType {
        var frameType = Regular
        for (i in 0..16) {
            if (frameData[Int64(celLevelFrameType4ZeroedBytes[i])] != 0) {
                break
            }
            if (i == 15) {
                frameType = LevelType4
            }
        }
        for (i in 0..16) {
            if (frameData[Int64(celLevelFrameType5ZeroedBytes[i])] != 0) {
                break
            }
            if (i == 15) {
                frameType = LevelType5
            }
        }
        return frameType
    }

    private static func getLevelFrame400Type(frameData: Array<Byte>): CELFrameType {
        var globalPixelCount = 0u32
        var pixelCount = 0u16

        // Going through the frame data to find pixel groups
        var i = 0
        while (i < frameData.size) {
            let readByte = frameData[i]

            if (readByte > 0x80) {
                // Transparent pixels group
                pixelCount += (256 - UInt16(readByte))
                globalPixelCount += UInt32(pixelCount)
                if (pixelCount > 32) {
                    return LevelType0
                }
                pixelCount = 0
            } else if (readByte == 0x80) {
                pixelCount += 0x80
                if (pixelCount > 32) {
                    return LevelType0
                }
            } else if (readByte == 0x7F) {
                // Palette indices pixel group
                pixelCount += 0x7F
                if (pixelCount > 32) {
                    return LevelType0
                }
                i += 0x7F
            } else {
                pixelCount += UInt16(readByte)
                globalPixelCount += UInt32(pixelCount)
                if (pixelCount > 32 || i + Int64(readByte) >= frameData.size) {
                    return LevelType0
                }
                pixelCount = 0
                i += Int64(readByte)
            }
            i++
        }
        if (globalPixelCount == 32 * 32) {
            return Regular
        }
        return LevelType0
    }

    private static func computeWidthFromHeader(frameData: Array<Byte>): UInt16 {
        var celFrameHeader = Array<UInt16>(5, repeat: 0)
        var celFrameWidth = Array<UInt16>(4, repeat: 0)

        // Read the {CEL FRAME HEADER}
        let fileStream = LittleEndianReader(ByteBuffer(frameData))

        for (index in 0..celFrameHeader.size) {
            celFrameHeader[index] = fileStream.read<UInt16>() ?? 0
        }

        // Read the five 32 pixel-lines block to calculate the image width
        var pixelCount = 0u16
        for (i in 0..4) {
            if (celFrameHeader[i + 1] == 0) {
                break
            }
            var j = celFrameHeader[i]
            while (j < celFrameHeader[i + 1]) {
                let readByte = UInt16(frameData[Int64(j)])
                if (readByte > 0x7F) {
                    pixelCount += (256 - readByte)
                } else {
                    pixelCount += readByte
                    j += readByte
                }
                j++
            }
            celFrameWidth[i] = pixelCount / 32
            pixelCount = 0
        }

        // The calculated width has to be the identical for each 32 pixel-line block
        // If it's not the case, 0 is returned
        for (i in 0..3) {
            if (celFrameWidth[i + 1] != 0 && celFrameWidth[i] != celFrameWidth[i + 1]) {
                return 0
            }
        }
        return celFrameWidth[0]
    }

    private static func computeWidthFromData(frameData: Array<Byte>): UInt16 {
        var frameDataStartOffset = 0i32
        var globalPixelCount = 0u32
        var biggestGroupPixelCount = 0u16
        var pixelCount = 0u16
        let pixelGroups = ArrayList<(pixelCount: UInt16, transparent: Bool)>()

        // Checking the presence of the {CEL FRAME HEADER}
        if (frameData[0] == 0x0A && frameData[1] == 0x00) {
            frameDataStartOffset = 0x0A
        }

        // Going through the frame data to find pixel groups
        var i = Int64(frameDataStartOffset)
        while (i < frameData.size) {
            let readByte = frameData[i]

            if (readByte > 0x80) {
                // Transparent pixels group
                pixelCount += (256 - UInt16(readByte))
                pixelGroups.add((pixelCount, true))
                globalPixelCount += UInt32(pixelCount)
                if (pixelCount > biggestGroupPixelCount) {
                    biggestGroupPixelCount = pixelCount
                }
                pixelCount = 0
            } else if (readByte == 0x80) {
                pixelCount += 0x80
            } else if (readByte == 0x7F) {
                // Palette indices pixel group
                pixelCount += 0x7F
                i += 0x7F
            } else {
                pixelCount += UInt16(readByte)
                pixelGroups.add((pixelCount, false))
                globalPixelCount += UInt32(pixelCount)
                if (pixelCount > biggestGroupPixelCount) {
                    biggestGroupPixelCount = pixelCount
                }
                pixelCount = 0
                i += Int64(readByte)
            }
            i++
        }

        // Going through pixel groups to find pixel-lines wraps
        var width = 0u16
        pixelCount = 0
        i = 1
        while (i < pixelGroups.size) {
            pixelCount += pixelGroups[i - 1][0]

            if (pixelGroups[i - 1][1] == pixelGroups[i][1]) {
                // If width == 0 then it's the first pixel-line wrap and width needs to be set
                // If pixelCount is less than width then the width has to be set to the new value
                if (width == 0 || pixelCount < width) {
                    width = pixelCount
                }
                // If the pixelCount of the last group is less than the current pixel group
                // then width is equal to this last pixel group's pixel count.
                // Mostly useful for small frames like the "J" frame in smaltext.cel
                if (i == pixelGroups.size - 1 && pixelGroups[i][0] < pixelCount) {
                    width = pixelGroups[i][0]
                }
                pixelCount = 0
            }
            // If last pixel group is being processed and width is still unknown
            // then set the width to the pixelCount of the last two pixel groups
            if (i == pixelGroups.size - 1 && width == 0) {
                width = pixelGroups[i - 1][0] + pixelGroups[i][0]
            }
            i++
        }
        if (width == 0) {
            // If width wasn't found return 0
            return 0
        }
        if (globalPixelCount % UInt32(width) == 0) {
            // If width is consistent
            return width
        } else {
            // If width is inconsistent
            // Try to find  relevant width by adding pixel groups' pixel counts iteratively
            pixelCount = 0
            for ((count, _) in pixelGroups) {
                pixelCount += count
                if (pixelCount > 1 && globalPixelCount % UInt32(pixelCount) == 0 && pixelCount >= biggestGroupPixelCount) {
                    return pixelCount
                }
            }
            // If still no width found return 0
            return 0
        }
        return 0
    }

    init(fileData: Array<Byte>) {
        super(fileData)

        m_celType = V1Regular

        let fileStream = LittleEndianReader(ByteBuffer(fileData))

        // CEL HEADER CHECKS

        // Read first DWORD
        let firstDword = Int64(fileStream.read<UInt32>() ?? 0)

        // Trying to find file size in CEL header
        if (fileStream.length < (firstDword * 4 + 4 + 4)) {
            return
        }

        fileStream.seek(Begin(firstDword * 4 + 4))
        let fileSizeDword = Int64(fileStream.read<UInt32>() ?? 0)

        // If the dword is not equal to the file size then
        // check if it's a CEL compilation
        if (fileStream.length != fileSizeDword) {
            // Read offset of the last CEL of the CEL compilation
            fileStream.seek(Begin(firstDword - 4))
            let lastCelOffset = Int64(fileStream.read<UInt32>() ?? 0)

            // Go to last CEL of the CEL compilation
            if (fileStream.length < (lastCelOffset + 8)) {
                return
            }

            fileStream.seek(Begin(lastCelOffset))

            // Read last CEL header
            let lastCelFrameCount = Int64(fileStream.read<UInt32>() ?? 0)

            // Read the last CEL size
            if (fileStream.length < (lastCelOffset + 4 + lastCelFrameCount * 4 + 4)) {
                return
            }

            fileStream.seek(Begin(lastCelOffset + 4 + lastCelFrameCount * 4))
            let lastCelSize = Int64(fileStream.read<UInt32>() ?? 0)

            // If the last CEL size plus the last CEL offset is equal to
            // the file size then it's a CEL compilation
            if (fileStream.length == (lastCelOffset + lastCelSize)) {
                m_celType = V1Compilation
                m_directions = UInt32(firstDword / 4)
            } else {
                return
            }
        } else {
            m_celType = V1Regular
            m_directions = 1
        }

        // CEL FRAMES OFFSETS CALCULATION

        match (m_celType) {
            // Going through all CELs
            case V1Compilation =>
                var i = 0
                while (i * 4 < firstDword) {
                    fileStream.seek(Begin(i * 4))
                    let celOffset = fileStream.read<UInt32>() ?? 0

                    fileStream.seek(Begin(Int64(celOffset)))
                    let celFrameCount = fileStream.read<UInt32>() ?? 0

                    // Going through all frames of the CEL
                    for (j in 1..=Int64(celFrameCount)) {
                        fileStream.seek(Begin(Int64(celOffset) + j * 4))
                        let celFrameStartOffset = fileStream.read<UInt32>() ?? 0
                        let celFrameEndOffset = fileStream.read<UInt32>() ?? 0

                        m_frameOffsets.add((celOffset + celFrameStartOffset, celOffset + celFrameEndOffset))
                    }
                    i++
                }
            // Going through all frames of the CEL
            case _ =>
                var level0x400FrameCount = 0
                var level0x320FrameCount = 0
                var level0x220FrameCount = 0
                for (i in 1..=firstDword) {
                    fileStream.seek(Begin(i * 4))
                    let celFrameStartOffset = fileStream.read<UInt32>() ?? 0
                    let celFrameEndOffset = fileStream.read<UInt32>() ?? 0

                    m_frameOffsets.add((celFrameStartOffset, celFrameEndOffset))

                    // Level CEL Check
                    let celFrameSize = celFrameEndOffset - celFrameStartOffset
                    match (celFrameSize) {
                        case 0x400 => level0x400FrameCount++
                        case 0x320 => level0x320FrameCount++
                        case 0x220 => level0x220FrameCount++
                        case _ => ()
                    }
                }
                // If there are more than 512 frames of 0x400, 0x320 and 0x220 size,
                // then it's a level frame.
                if (level0x400FrameCount + level0x320FrameCount + level0x220FrameCount > 512) {
                    m_celType = V1Level
                }
        }
    }

    private func decode(frameData: Array<Byte>, width_: UInt32, height: UInt32, frameType: CELFrameType,
        palette: ?PaletteArray): SFMLImage {
        var frameDataStartOffset = 0u32

        // If the frame size wasnt provided then it needs to be calculated
        var width = width_
        if (width == 0) {
            // Checking the presence of the {CEL FRAME HEADER}
            if (frameData[0] == 0x0A && frameData[1] == 0x00) {
                frameDataStartOffset += 0x0A
                // If header is present, try to compute frame width from frame header
                width = UInt32(computeWidthFromHeader(frameData))
            }
            // If width could not be calculated with frame header,
            // attempt to calculate it from the frame data (by identifying pixel groups line wraps)
            if (width == 0) {
                width = UInt32(computeWidthFromData(frameData))
            }
            // if CEL width was not found, return false
            if (width == 0) {
                return SFMLImage(0, 0)
            }
        }

        // READ {CEL FRAME DATA}
        match (frameType) {
            case Regular =>
                // if it's a regular CEL frame
                let pixels = ArrayList<Color>(Int64(width) * Int64(width))

                var currWidth = 0u32
                var i = Int64(frameDataStartOffset)
                while (i < frameData.size) {
                    let readByte = UInt32(frameData[i])

                    if (readByte > 0x7F) {
                        // Transparent pixels group
                        // A pixel line can't exceed the image width
                        if ((currWidth + (256 - readByte)) > width) {
                            return SFMLImage(0, 0)
                        }
                        let rangeEnd = (256 - readByte)
                        currWidth += rangeEnd
                        for (_ in 0..rangeEnd) {
                            pixels.add(Color.transparent)
                        }
                    } else {
                        // Palette indices group
                        // A pixel line can't exceed the image width
                        if ((currWidth + readByte) > width) {
                            return SFMLImage(0, 0)
                        }
                        currWidth += readByte
                        for (_ in 0..readByte) {
                            i++
                            pixels.add(ImageContainer.getColor(frameData[i], palette))
                        }
                    }
                    if (currWidth == width) {
                        currWidth = 0
                    }
                    i++
                }
                var height = height
                if (height == 0) {
                    height = UInt32(pixels.size) / width
                }
                unsafe {
                    let img = SFMLImage(width, height, pixels.getRawArray())
                    img.flipVertically()
                    return img
                }
            case _ =>
                // if it is a CEL level frame
                let img = SFMLImage(width, height, Color.transparent)

                match (frameType) {
                    // 0x400 frame
                    case LevelType0 => for (j in 0u32..32) {
                        for (i in 0u32..32) {
                            img.setPixel(
                                i,
                                31 - j,
                                ImageContainer.getColor(frameData[Int64(j) * 32 + Int64(i)], palette)
                            )
                        }
                    }
                    // 0x220 or 0x320 frame
                    case _ =>
                        let (dataPattern, dataPatternZeroedBytes) = match (frameType) {
                            case LevelType2 => (celLevelFrameType2, celLevelFrameType2ZeroedBytes)
                            case LevelType3 => (celLevelFrameType3, celLevelFrameType3ZeroedBytes)
                            case LevelType4 => (celLevelFrameType4, celLevelFrameType4ZeroedBytes)
                            case LevelType5 => (celLevelFrameType5, celLevelFrameType5ZeroedBytes)
                            case _ => return img
                        }

                        // Going through the data structure
                        var offset = 0
                        var zeroedBytesIndex = 0
                        var currWidth = 0u32
                        var currHeight = 31u32
                        for (i in 0..512) {
                            if (dataPattern[i] != 0) {
                                // if dataPattern[i] is true, then read and add 2 pixels to the line
                                var readByte = frameData[offset]
                                var secondReadByte = frameData[offset + 1]

                                if (readByte == 0x00 && secondReadByte == 0x00 && offset == Int64(dataPatternZeroedBytes[zeroedBytesIndex])) {
                                    // Skip the 0x00 0x00 bytes
                                    offset += 2
                                    // and read the next 2 bytes
                                    readByte = frameData[offset]
                                    secondReadByte = frameData[offset + 1]

                                    // move forward in the zeroed bytes structure
                                    zeroedBytesIndex += 2
                                }

                                img.setPixel(currWidth, currHeight, ImageContainer.getColor(readByte, palette))
                                currWidth++
                                img.setPixel(currWidth, currHeight, ImageContainer.getColor(secondReadByte, palette))
                                currWidth++

                                offset += 2
                            } else {
                                // else add 2 transparent pixels to the line (constructor default color is transparent)
                                // img.setPixel(currWidth++, currHeight, Color.Transparent)
                                // img.setPixel(currWidth++, currHeight, Color.Transparent)
                                currWidth += 2
                            }
                            // If it is the end of the pixel line, add the line to the frame
                            if (currWidth == 32) {
                                currHeight--
                                currWidth = 0
                            }
                        }
                }
                return img
        }
    }

    public func decode(frameData: Array<Byte>, palette: ?PaletteArray): SFMLImage {
        match (m_celType) {
            case V1Level =>
                // If it's a level CEL
                let frameType = match (frameData.size) {
                    case 0x400 => getLevelFrame400Type(frameData)
                    case 0x320 => getLevelFrame320Type(frameData)
                    case 0x220 => getLevelFrame220Type(frameData)
                    case _ => Regular
                }
                decode(frameData, 32, 32, frameType, palette)
            case _ =>
                // If it's not a level CEL
                decode(frameData, 0, 0, Regular, palette)
        }
    }

    public prop directions: UInt32 {
        get() {
            m_directions
        }
    }
}
